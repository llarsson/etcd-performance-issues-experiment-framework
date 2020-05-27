#!/bin/bash

set -euo pipefail
set -x

EXPERIMENT_ID=${1}
DBNAME=${DBNAME:-experiments}

SERVICES="backend"
PSQL="psql -d ${DBNAME} -A -t"

floating_ip=a.b.c.d-changeme
istio_node=changeme

# Function definitions below this point

run_experiment () {
	service_mesh="$(get_service_mesh)"
	if [ "${service_mesh}" == "istio" ]; then
		export SERVER="backend.${floating_ip}.xip.io"
		export PORT="31380"
		export PATH_PREFIX="backend/"
		export REQUEST_PATH="${PATH_PREFIX}tokyo.png"
	else 
		export SERVER="backend.${floating_ip}.xip.io"
		export PORT="31000"
		export PATH_PREFIX=""
		export REQUEST_PATH="tokyo.png"
	fi
	export BACKEND="http://${SERVER}:${PORT}/${PATH_PREFIX}"

	check_preconditions

	ensure_node_readiness

	ensure_jmeter_worker_readiness

	ensure_prometheus_accessible

	clear_database

	store_experiment_metadata

	# better safe than sorry with this
	remove_application
	sleep 5 

	deploy 

	wait_for_ready_pods

	sanity_check

	echo "Waiting a bit, just to be pseudo-safe..."
	sleep 60

	start_time="$(get_current_time)"
	store_start_time

	export RESULTS_CSV="/mnt/ramdisk/${EXPERIMENT_ID}.csv"

	run_load_test
	
	end_time="$(get_current_time)"
	store_end_time

	store_timeseries_data

	store_etcd_journal_entries

	remove_application

	mark_as_finished

	echo "Experiment ${EXPERIMENT_ID} successfully completed and recorded!"
}

check_preconditions () {
	if [ "x${EXPERIMENT_ID}" == "x" ]; then
		echo "FATAL: Must supply the EXPERIMENT_ID"
		exit 1
	fi

	if ! git diff-index --quiet HEAD --; then
		echo "FATAL: Uncommitted changes in this git repo"
		exit 1
	fi

	pushd application
	if ! git diff-index --quiet HEAD --; then
		echo "FATAL: Uncommitted changes in application git repo"
		exit 1
	fi
	popd

	if ! mount | grep /mnt/ramdisk; then
		echo "FATAL: RAMDISK not mounted!"
		exit 1
	fi

	for garbage in $(ls *.hprof); do
		echo "Removing garbage file ${garbage}"
		rm ${garbage}
	done
}

ensure_node_readiness() {
	until [ "$(kubectl get nodes | grep NotReady | wc -l)" -eq "0" ]; do
		for node in $(kubectl get nodes | grep NotReady | cut -d ' ' -f 1); do
			openstack server reboot ${node}
		done
		sleep 300 # FIXME Better to determine if the node is still rebooting or w/e
	done
}

ensure_jmeter_worker_readiness() {
	jmeter_workers=$(grep '^remote_hosts' jmeter/bin/jmeter.properties | cut -d '=' -f 2 | tr ',' '\n')
	for worker in $jmeter_workers; do
		ssh ubuntu@${worker} sudo systemctl restart jmeter-server.service
	done
}

ensure_prometheus_accessible() {
	until curl http://localhost:9090/; do
		echo "Prometheus not accessible, will kill the port forwarder..."
		kill $(ps aux | grep 'kubectl port-forward' | grep 'kube-system' | awk '{print $2}')
		sleep 2
	done
}

store_experiment_metadata () {
	# metadata
	git_hash_experiments_repo="$(git_hash .)"
	git_hash_demo_repo="$(git_hash application)"
	kubectl_get_all_pods="$(/usr/bin/time -f '%e' kubectl get pods --all-namespaces 2>&1 > /dev/null)"
	cluster_info="$(kubectl cluster-info | tr '\n' ' ' | tr '"' ' ' | tr "'" " ")"
	istio_version="$(cat istio/istio.VERSION | grep TAG | cut -d ' ' -f 2 | tr '\n' ' ')"
	kubectl_context="$(kubectl config current-context)"
	hostname="$(hostname)"

	${PSQL} > /dev/null <<EOF
UPDATE experiments SET 
	git_hash_experiments_repo = '${git_hash_experiments_repo}',
	git_hash_demo_repo = '${git_hash_demo_repo}',
	kubectl_get_all_pods = '${kubectl_get_all_pods}',
	cluster_info = '${cluster_info}',
	service_mesh_details = '${istio_version}',
	kubectl_context = '${kubectl_context}',
	hostname = '${hostname}'
WHERE experiment_id = '${EXPERIMENT_ID}';
EOF
}

store_timeseries_data () {
	./jmeter-parser.py ${RESULTS_CSV}
	rm ${RESULTS_CSV}

	pushd prometheus-parser/ > /dev/null
	export EXPERIMENT_ID
	./prom_curler.py --start_time="${start_time}" --end_time="${end_time}" --targets_file=targets.json
	popd > /dev/null
}

store_etcd_journal_entries () {
	pushd ../etcd-journal-entries/
	etcd_entries_file=${EXPERIMENT_ID}-etcd-entries.txt
	start_time_seconds=$(echo ${start_time} | cut -d '.' -f 1)
	end_time_seconds=$(echo ${end_time} | cut -d '.' -f 1)

	ssh master journalctl --unit etcd.service --since=\"${start_time_seconds}\" --until=\"${end_time_seconds}\" > ${etcd_entries_file}

	git add ${etcd_entries_file}
	git commit -m "Added entries for experiment ${EXPERIMENT_ID}"
	git push origin master

	popd
}

store_start_time () {
	${PSQL} > /dev/null <<EOF
UPDATE experiments SET start_time = '${start_time}' WHERE experiment_id = '${EXPERIMENT_ID}';
EOF
}

store_end_time () {
	${PSQL} > /dev/null <<EOF
UPDATE experiments SET end_time = '${end_time}' WHERE experiment_id = '${EXPERIMENT_ID}';
EOF
}

mark_as_finished () {
	${PSQL} > /dev/null <<EOF
UPDATE experiments SET finished = TRUE WHERE experiment_id = '${EXPERIMENT_ID}';
EOF
}

deploy_istio () {
	echo "Ensuring that Istio is deployed..."

	ensure_node_label_exists
	ensure_istio_ns_exists
	ensure_istio_initialized
	ensure_application_istio_configured
}

ensure_node_label_exists() {
	kubectl label node ${istio_node} istio=runshere --overwrite 
}

ensure_istio_ns_exists() {
	if ! kubectl get namespace istio-system; then
		kubectl create namespace istio-system
	fi
}

ensure_istio_initialized() {
	kubectl apply -f application/istio/istio-init.yaml
	until [ $(kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l) -eq $(grep 'CustomResourceDefinition' application/istio/istio-init.yaml | wc -l) ]; do
		echo "Waiting for Istio CRDs to be applied..."
		sleep 5
	done

	kubectl apply -f application/istio/istio.yaml
	
	until [ "$(kubectl get pods -n istio-system --no-headers | wc -l)" -gt 0 ]; do
		echo "Waiting for some Istio Pod or Job to come up at all..."
		sleep 2
	done

	while [ "$(kubectl get pods -n istio-system --no-headers | grep -v 'Running\|Completed' | wc -l)" -gt 0 ]; do
		echo "Not everything in Istio is Running or Completed yet..."
		sleep 5

		while [ "$(kubectl get pods -n istio-system | grep OutOfcpu | wc -l)" -gt 0 ]; do
			for pod in $(kubectl get pods -n istio-system | grep OutOfcpu | awk -p '{print $1}'); do
				echo "Deleting OutOfcpu Pod $pod in istio-system..."
				kubectl delete pod $pod -n istio-system
			done
		done
	done
}

ensure_application_istio_configured() {
	kubectl label namespace default istio-injection=enabled --overwrite
	kubectl apply -f application/k8s/gateway.yaml
}


remove_istio () {
	echo "Ensuring Istio is removed..."

	ensure_application_istio_configuration_removed
	ensure_istio_removed
	ensure_istio_ns_removed
}

ensure_istio_ns_removed() {
	if kubectl get namespace istio-system; then
		kubectl delete namespace istio-system
	fi
}

ensure_application_istio_configuration_removed() {
	if kubectl get -f application/k8s/gateway.yaml; then
		kubectl delete -f application/k8s/gateway.yaml
	fi
	kubectl label namespace default istio-injection=disabled --overwrite

	if kubectl get -f application/istio/istio.yaml; then
		kubectl delete -f application/istio/istio.yaml
	fi
}

ensure_istio_removed() {
	if kubectl get -f application/istio/istio.yaml; then
		kubectl delete -f application/istio/istio.yaml
	fi

	# This command tries to delete too much (Certificate Manager) stuff,
	# so we must ignore its true exit code
	kubectl delete -f istio/install/kubernetes/helm/istio-init/files || true

	until [ $(kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l) -eq 0 ]; do
		echo "Waiting for Istio CRDs to be deleted..."
		sleep 5
	done
}

remove_application () {
	# Removes "too much" but who cares, it should be gone, anyway...
	for service in "${SERVICES}"; do
		kubectl delete -R -f application/${service}/k8s || true
		sleep 2
		if kubectl get replicasets ${service}; then
			for rs in $(kubectl get replicasets --no-headers | awk -p '{print $1}'); do
				kubectl delete replicaset ${rs} || true
			done
		fi
	done

	until [ $(kubectl get pods | grep ${service} | wc -l) -eq 0 ]; do
		echo "Waiting for all ${service} Pods to shut down..."
		sleep 5
		for pod in $(kubectl get pods --no-headers | grep ${service} | awk -p '{print $1}'); do
			kubectl delete pod ${pod} || true
		done
	done
}

deploy () {
	service_mesh="$(get_service_mesh)"
	service_mesh_version="$(get_service_mesh_version)"
	min_replicas="$(get_min_replicas)"
	max_replicas="$(get_max_replicas)"

	echo "Should deploy ${service_mesh} (version ${service_mesh_version}) with replicas between ${min_replicas} and ${max_replicas}"

	if [ "${service_mesh}" == "istio" ]; then
		deploy_istio
		kubectl apply -f application/k8s/gateway.yaml
	else
		remove_istio
	fi

	for service in "${SERVICES}"; do
		echo "Deploying service ${service}..."
		# TODO Modify Deploment to deploy min_replicas of the service
		kubectl apply -f application/${service}/k8s/${service_mesh}

		#if [ ${min_replicas} != ${max_replicas} ]; then
			sed -e "s/minReplicas: .*/minReplicas: ${min_replicas}/g" \
				-e "s/maxReplicas: .*/maxReplicas: ${max_replicas}/g" \
				application/${service}/k8s/hpa.yaml | kubectl apply -f -
		#fi
	done
}

wait_for_ready_pods () {
	min_replicas="$(get_min_replicas)"
	echo "Should wait for ${min_replicas} pods before the load test..."

	if [ "${service_mesh}" == "istio" ]; then
		containers=2
	else
		containers=1
	fi



	until [ $(kubectl get pods -n default --no-headers | grep backend | grep "Running" | grep "${containers}/${containers}" | wc -l ) -eq ${min_replicas} ]; do
		echo "Waiting for ${min_replicas} ready Pods ($(kubectl get pods -n default --no-headers | grep backend | grep "Running" | grep "${containers}/${containers}" | wc -l ) now)..."
		sleep 5
	done
}

sanity_check () {
	URL="${BACKEND}images"

	until curl --fail --insecure ${URL}; do
		echo "Sanity checking application via URL ${URL}"
		sleep 5
	done
}

run_load_test () {
	clients="$(get_clients)"
	duration_seconds="$(get_duration_in_seconds)"

	echo "Will run load test for ${clients} clients (${EXPERIMENT_ID})..."

	# Note: also includes SERVER, PORT, and REQUEST_PATH
	export CLIENTS="$(get_clients)"
	export DURATION="$(get_duration_in_seconds)"
	export THINK_TIME="$(get_think_time)"

	export HEAP='-Xms4096m -Xmx4096m' # Plenty HEAP space for Java
	jmeter/bin/jmeter -n \
		-Gclients=${CLIENTS} \
		-Gduration_seconds=${DURATION} \
		-Ghostname=${SERVER} \
		-Gport=${PORT} \
		-Grequest_path=${REQUEST_PATH} \
		-Gconnection_timeout_milliseconds=2000 \
		-Gthink_time_milliseconds=${THINK_TIME} \
		-t fetch-rectangle.jmx \
		-r \
		-l ${RESULTS_CSV} | tee /tmp/${EXPERIMENT_ID}-jmeter.log 

	if grep 'Engine is busy' /tmp/${EXPERIMENT_ID}-jmeter.log; then
		echo "FATAL: A remote server was busy, failing this run..."
		exit 1
	fi
}

git_hash () {
		pushd $1 > /dev/null
		git rev-parse HEAD
		popd > /dev/null
}

clear_database () {
	${PSQL} > /dev/null <<EOF
DELETE FROM timeseries WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM statistics WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM cluster_cpu_utilisation WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM cluster_memory_utilisation WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM replicas_desired WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM replicas_unavailable WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM replicas_available WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM container_memory_usage_min WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM container_memory_usage_avg WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM container_memory_usage_max WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM container_cpu_usage_min WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM container_cpu_usage_avg WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM container_cpu_usage_max WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM container_restarts WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM memory_usage_per_namespace WHERE experiment_id = '${EXPERIMENT_ID}';
DELETE FROM cpu_usage_per_namespace WHERE experiment_id = '${EXPERIMENT_ID}';
EOF
}

get_current_time () {
	${PSQL} -c 'select now();'
}

get_think_time () {
	${PSQL} -c "select think_time_milliseconds from scenarios where scenario_id = (SELECT scenario_id FROM experiments where experiment_id = '${EXPERIMENT_ID}');"
}

get_clients () {
	${PSQL} -c "select clients from scenarios where scenario_id = (SELECT scenario_id FROM experiments where experiment_id = '${EXPERIMENT_ID}');"
}

get_min_replicas () {
	${PSQL} -c "select min_replicas from scenarios where scenario_id = (SELECT scenario_id FROM experiments where experiment_id = '${EXPERIMENT_ID}');"
}

get_max_replicas () {
	${PSQL} -c "select max_replicas from scenarios where scenario_id = (SELECT scenario_id FROM experiments where experiment_id = '${EXPERIMENT_ID}');"
}

get_duration_in_seconds () {
	${PSQL} -c "select duration_seconds from scenarios where scenario_id = (SELECT scenario_id FROM experiments where experiment_id = '${EXPERIMENT_ID}');"
}

get_service_mesh () {
	${PSQL} -c "select service_mesh from scenarios where scenario_id = (SELECT scenario_id FROM experiments where experiment_id = '${EXPERIMENT_ID}');"
}

get_service_mesh_version () {
	${PSQL} -c "select service_mesh_version from scenarios where scenario_id = (SELECT scenario_id FROM experiments where experiment_id = '${EXPERIMENT_ID}');"
}
run_experiment
