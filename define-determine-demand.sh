#!/bin/bash

set -euo pipefail

duration_seconds=600
repetitions=5


echo "Defining scenarios to determine demand (d_t)..."
for service_mesh in istio none; do
	for pods in 1 2 3 4 5 10 15 20; do
		for clients in $(seq 1 20); do
			think_time_milliseconds=20

			scenario_id="demand-${pods}-pods-${clients}-clients-${service_mesh}-mesh-${think_time_milliseconds}-thinktime-${duration_seconds}-duration"
			description="Determine required capacity at ${pods} pods using ${service_mesh} service mesh for ${duration_seconds} seconds duration and think time set to ${think_time_milliseconds} milliseconds"

			psql -d experiments -c "INSERT INTO scenarios (scenario_id, description, min_replicas, max_replicas, clients, duration_seconds, think_time_milliseconds, service_mesh, service_mesh_version) VALUES ('${scenario_id}','${description}','${pods}','${pods}','${clients}','${duration_seconds}','${think_time_milliseconds}','${service_mesh}','1.1.5');"

			echo "Defining ${repetitions} experiments of ${scenario_id} to run..."
			for rep in $(seq ${repetitions}); do
				./define-experiment.sh "${scenario_id}"
			done
		done
	done
done



