#!/bin/bash

set -euo pipefail

duration_seconds=1200
repetitions=5


echo "Defining the additional scaling scenarios..."
for service_mesh in istio none; do
	for min_replicas in 2 3 4; do
		for clients in $(seq 1 20); do
			think_time_milliseconds=20

			scenario_id="scaling-${min_replicas}-pods-${clients}-clients-${service_mesh}-mesh-${think_time_milliseconds}-thinktime-${duration_seconds}-duration"
			description="Scaling starting at ${min_replicas} pods using ${service_mesh} service mesh for ${duration_seconds} seconds duration and think time set to ${think_time_milliseconds} milliseconds"

			psql -d experiments -c "INSERT INTO scenarios (scenario_id, description, min_replicas, max_replicas, clients, duration_seconds, think_time_milliseconds, service_mesh, service_mesh_version) VALUES ('${scenario_id}','${description}','${min_replicas}','20','${clients}','${duration_seconds}','${think_time_milliseconds}','${service_mesh}','1.1.5');"

			echo "Defining ${repetitions} experiments of ${scenario_id} to run..."
			for rep in $(seq ${repetitions}); do
				./define-experiment.sh "${scenario_id}"
			done
		done
	done
done


