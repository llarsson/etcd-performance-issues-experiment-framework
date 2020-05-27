#!/bin/bash

set -euo pipefail

scenario_selector=$1

DBNAME=${DBNAME:-experiments}
PSQL="psql -d ${DBNAME} -A -t"

if [ -z "$scenario_selector" ]; then
	echo "You must supply a scenario selector!"
	exit 1
fi

all_done=false

if [ "$($PSQL -c "SELECT COUNT (*) FROM experiments WHERE scenario_id LIKE '${scenario_selector}' AND finished = FALSE")" -eq 0 ]; then
	all_done=true
fi

while ! ${all_done}; do
	export EXPERIMENT_ID="$(${PSQL} -c "SELECT experiment_id FROM experiments JOIN (SELECT scenario_id, count(experiment_id) - COALESCE(completed,0) AS remaining FROM scenarios LEFT JOIN (select scenario_id, COALESCE(count(experiment_id),0) as completed FROM experiments where finished = true GROUP BY scenario_id) AS count_completed USING (scenario_id) LEFT JOIN experiments USING (scenario_id) WHERE scenario_id LIKE '${scenario_selector}' GROUP BY (scenario_id, completed) order by remaining desc limit 1) as scenario_finder USING (scenario_id) WHERE finished = false limit 1")"

	echo "Will run experiment ${EXPERIMENT_ID} ($(${PSQL} -c "SELECT scenario_id FROM experiments WHERE experiment_id = '${EXPERIMENT_ID}'"))"

	if ! timeout 60m ./run-experiment.sh ${EXPERIMENT_ID}; then
		echo "ERROR while running ${EXPERIMENT_ID}, will sleep and go again..."
		sleep 10
	fi
	
	if [ "$($PSQL -c "SELECT COUNT (*) FROM experiments WHERE scenario_id LIKE '${scenario_selector}' AND finished = FALSE")" -eq 0 ]; then
		all_done=true
	fi
done
