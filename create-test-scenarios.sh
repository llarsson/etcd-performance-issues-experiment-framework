#!/bin/bash

set -euo pipefail

psql -d ${DBNAME} -c "insert into scenarios (scenario_id, description, min_replicas, max_replicas, clients, duration_seconds, think_time_milliseconds, service_mesh, service_mesh_version) values ('istio-test', 'test', 5, 5, 20, 100, 150, 'istio', '1.1.5');"
psql -d ${DBNAME} -c "insert into scenarios (scenario_id, description, min_replicas, max_replicas, clients, duration_seconds, think_time_milliseconds, service_mesh, service_mesh_version) values ('none-test', 'test', 5, 5, 20, 100, 150, 'none', '1.1.5');"
