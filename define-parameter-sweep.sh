#!/bin/bash

# FIXME longer duration obviously
duration_seconds=1200

export THINK_TIME=100
export PROCESSING_TIME=120

echo "Defining the baseline experiment..."
for service_mesh in istio none; do
	for pods in 1 2 4 8 16 20; do
		for load_factor in 0.5 1.0 3.0 6.0 8.0; do
			clients=$(./clients_per_pod.py ${pods} ${load_factor})

			scenario_id="baseline-${pods}-pods-${load_factor}-loadfactor-${service_mesh}-mesh-${THINK_TIME}-thinktime-${PROCESSING_TIME}-processingtime-${duration_seconds}-duration"
			description="Baseline with ${pods} and ${clients} clients on ${service_mesh} service mesh at load factor ${load_factor} with think time ${THINK_TIME} and ${PROCESSING_TIME} processing time for ${duration_seconds} seconds"

			psql -d experiments -c "INSERT INTO scenarios (scenario_id, description, min_replicas, max_replicas, clients, duration_seconds, think_time_milliseconds, service_mesh, service_mesh_version) VALUES ('${scenario_id}','${description}','${pods}','${pods}','${clients}','${duration_seconds}','${THINK_TIME}','${service_mesh}','1.1.5');"
		done
	done
done

echo "Defining the autoscaling experiment..."
for service_mesh in istio none; do
	for pods in 1 2 4 8 16 20; do
		for clients in 8 16 32 64 128 256 300; do
			scenario_id="autoscaling-${pods}-pods-${clients}-clients-${service_mesh}-mesh-${THINK_TIME}-thinktime-${PROCESSING_TIME}-processingtime-${duration_seconds}-duration"
			description="Autoscaling with ${pods} minimum pods and ${clients} clients on ${service_mesh} service mesh with think time ${THINK_TIME} and ${PROCESSING_TIME} processing time for ${duration_seconds} seconds"

			psql -d experiments -c "INSERT INTO scenarios (scenario_id, description, min_replicas, max_replicas, clients, duration_seconds, think_time_milliseconds, service_mesh, service_mesh_version) VALUES ('${scenario_id}','${description}','${pods}','20','${clients}','${duration_seconds}','${THINK_TIME}','${service_mesh}','1.1.5');"
		done
	done
done
