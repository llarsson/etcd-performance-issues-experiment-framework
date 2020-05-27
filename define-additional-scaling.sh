#!/bin/bash

set -euo pipefail

repetitions=10

echo "Defining additional scaling scenarios to compensate..."
for scenario_id in $(cat /tmp/too-few-experiments.txt); do
	for rep in $(seq ${repetitions}); do
		./define-experiment.sh "${scenario_id}"
	done
done
