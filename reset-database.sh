#!/bin/bash

set -eo pipefail

DBNAME=${DBNAME:-experiments}

psql -d ${DBNAME} -c '\i database-migrations/reset.sql'
psql -d ${DBNAME} -c '\i database-migrations/reset.sql'
psql -d ${DBNAME} -c '\i database-migrations/version0.sql'

