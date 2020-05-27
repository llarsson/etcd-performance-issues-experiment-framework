#!/bin/bash

set -euo pipefail

duration_seconds=1200
repetitions=15


echo "Defining scenarios to investigate etcd with and without ramdisk..."
for ramdisk in enabled disabled; do
	for service_mesh in istio none; do
		for clients in 10 15 20; do
			think_time_milliseconds=20
			pods=10
			scenario_id="investigate-etcd-ramdisk-${ramdisk}-${pods}-pods-${clients}-clients-${service_mesh}-mesh-${think_time_milliseconds}-thinktime-${duration_seconds}-duration"

			echo "Defining ${repetitions} experiments of ${scenario_id} to run..."
			for rep in $(seq ${repetitions}); do
				./define-experiment.sh "${scenario_id}"
			done
		done
	done
done
