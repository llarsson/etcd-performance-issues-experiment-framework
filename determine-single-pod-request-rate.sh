#!/bin/bash 

set -euo pipefail

source time_it.sh

floating_ip=a.b.c.d
istio_node=changeme

DELAY=${1}
COUNT=${2}

SERVICES=backend

deploy_istio () {
	if kubectl get namespace istio-system; then
		echo "Istio already deployed..."
		return
	fi

	echo "Deploying Istio..."

	kubectl label node ${istio_node} istio=runshere --overwrite 

	kubectl create namespace istio-system

	kubectl apply -f application/istio/istio-init.yaml
	until [ $(kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l) -eq $(grep 'CustomResourceDefinition' application/istio/istio-init.yml | wc -l) ]; do
		echo "Waiting for Istio CRDs to be applied..."
		sleep 5
	done

	kubectl apply -f application/istio/istio.yaml

	until [ $(kubectl get pods -n istio-system --no-headers | grep -v 'Running\|Completed' | wc -l) -eq 1 ]; do
		echo "Waiting for Istio deploy to be fully completed and running..."
		sleep 5
	done

	kubectl label namespace default istio-injection=enabled --overwrite

	kubectl apply -f application/k8s/gateway.yaml
}

remove_istio () {
	if ! kubectl get namespace istio-system; then
		echo "Istio not deployed..."
		return
	fi

	echo "Removing Istio..."
	# Delete in the reverse order that resources were created

	kubectl delete -f application/k8s/gateway.yaml
	
	kubectl label namespace default istio-injection=disabled --overwrite

	kubectl delete -f application/istio/istio.yaml

	# This command tries to delete too much (Certificate Manager) stuff,
	# so we must ignore its true exit code
	kubectl delete -f istio/install/kubernetes/helm/istio-init/files || true
	until [ $(kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l) -eq 0 ]; do
		echo "Waiting for Istio CRDs to be deleted..."
		sleep 5
	done

	kubectl delete namespace istio-system
}

remove_application () {
	# Removes "too much" but who cares, it should be gone, anyway...
	for service in "${SERVICES}"; do
		kubectl delete -R -f application/${service}/k8s || true
	done

	until [ $(kubectl get pods | grep ${service} | wc -l) -eq 0 ]; do
		echo "Waiting for all ${service} Pods to shut down..."
		sleep 5
	done
}

deploy () {
	service_mesh=$1
	min_replicas=1
	max_replicas=1

	echo "Should deploy ${service_mesh} with replicas exactly ${max_replicas}" 

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

for service_mesh in istio none; do
	remove_application

	if [ "${service_mesh}" == "istio" ]; then
		backend='http://backend.${floating_ip}.xip.io:31380/backend'
	else
		backend='http://backend.${floating_ip}.xip.io:31000'
	fi

	deploy ${service_mesh}

	count=0
	while [ ${count} -le ${COUNT} ]; do
		echo $(date +%s | tr '\n' ','; time_it curl -s "${backend}/tokyo.png?top=0&left=0&bottom=30&right=30") >> single-pod-request-rate-${service_mesh}.csv
		sleep ${DELAY}
		count=$(($count + 1))
		echo "${service_mesh}: ${count}/${COUNT}"
	done
done
