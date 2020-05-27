#!/bin/bash

set -euo pipefail

duration_seconds=1200
repetitions=10


echo "Defining scenarios to investigate etcd with and without ramdisk..."
for ramdisk in enabled disabled; do
	for service_mesh in istio none; do
		for clients in 15 20; do
			think_time_milliseconds=20
			pods=20

			scenario_id="investigate-etcd-ramdisk-${ramdisk}-${pods}-pods-${clients}-clients-${service_mesh}-mesh-${think_time_milliseconds}-thinktime-${duration_seconds}-duration"
			description="Investigate etcd effects using ${ramdisk} ramdisk, ${pods} pods, and ${clients} clients with ${service_mesh} service mesh for ${duration_seconds} seconds duration and think time set to ${think_time_milliseconds} milliseconds"

			psql -d experiments -c "INSERT INTO scenarios (scenario_id, description, min_replicas, max_replicas, clients, duration_seconds, think_time_milliseconds, service_mesh, service_mesh_version) VALUES ('${scenario_id}','${description}','${pods}','${pods}','${clients}','${duration_seconds}','${think_time_milliseconds}','${service_mesh}','1.1.5');"

			echo "Defining ${repetitions} experiments of ${scenario_id} to run..."
			for rep in $(seq ${repetitions}); do
				./define-experiment.sh "${scenario_id}"
			done
		done
	done
done
