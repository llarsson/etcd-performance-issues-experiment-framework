#!/bin/bash

set -euo pipefail
DBNAME=${DBNAME:-experiments}
scenario_id=$1

experiment_id=$(uuid)
psql -d ${DBNAME} -c "INSERT INTO experiments (experiment_id, scenario_id, finished) VALUES ('${experiment_id}', '${scenario_id}', false);"

echo "${experiment_id}"
