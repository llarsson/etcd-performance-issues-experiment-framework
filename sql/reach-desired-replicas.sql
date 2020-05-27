COPY (
SELECT experiment_id, service_mesh, min_replicas, clients, max_desired_replicas, convergence_timestamp
FROM scenarios NATURAL JOIN experiments NATURAL JOIN
(SELECT experiment_id, max(max_desired_replicas) as max_desired_replicas, min(timestamp) AS convergence_timestamp FROM replicas_desired NATURAL JOIN (SELECT experiment_id, max(value) AS max_desired_replicas FROM replicas_desired GROUP BY experiment_id) AS determine_max_desired_replicas WHERE value = max_desired_replicas GROUP BY experiment_id) AS find_convergence
WHERE max_desired_replicas < 20 AND min_replicas < max_desired_replicas
) TO '/tmp/reach-desired-replicas.csv' WITH CSV HEADER;
