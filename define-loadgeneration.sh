#!/bin/bash

set -euo pipefail

duration_seconds=900
repetitions=5

ramdisk=enabled
service_mesh=none
pods=20
think_time_milliseconds=20

echo "Defining scenarios to investigate load generation..."
for clients in $(seq 1 20); do
	scenario_id="loadgeneration-reduced-workers-ramdisk-${ramdisk}-${pods}-pods-${clients}-clients-${service_mesh}-mesh-${think_time_milliseconds}-thinktime-${duration_seconds}-duration"
	description="Investigate load generation using ${ramdisk} ramdisk, ${pods} pods, and ${clients} clients with ${service_mesh} service mesh for ${duration_seconds} seconds duration and think time set to ${think_time_milliseconds} milliseconds"

	psql -d experiments -c "INSERT INTO scenarios (scenario_id, description, min_replicas, max_replicas, clients, duration_seconds, think_time_milliseconds, service_mesh, service_mesh_version) VALUES ('${scenario_id}','${description}','${pods}','${pods}','${clients}','${duration_seconds}','${think_time_milliseconds}','${service_mesh}','1.1.5');"

	echo "Defining ${repetitions} experiments of ${scenario_id} to run..."
	for rep in $(seq ${repetitions}); do
		./define-experiment.sh "${scenario_id}"
	done
done
