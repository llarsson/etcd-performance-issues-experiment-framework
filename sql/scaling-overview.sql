COPY (
SELECT 	experiment_id, 
	service_mesh, 
	min_replicas, 
	clients, 
	max_replicas_desired, 
	max_replicas_available, 
	success_percentile_95, 
	total_percentile_95, 
	success_avg, 
	total_avg, 
	success_reqs, 
	failure_reqs, 
	total_reqs, 
	backend_avg_cpu_usage, 
	backend_max_cpu_usage, 
	backend_avg_memory_usage, 
	backend_max_memory_usage 
FROM experiments NATURAL JOIN scenarios 
LEFT JOIN
(SELECT experiment_id,
	percentile_disc(0.95) WITHIN GROUP (ORDER BY success_median) AS success_percentile_95, 
	avg(success_median) AS success_avg,
	percentile_disc(0.95) WITHIN GROUP (ORDER BY total_median) AS total_percentile_95, 
	avg(total_median) AS total_avg,
	COALESCE(sum(success_rps), 0) AS success_reqs,
	sum(total_rps) AS total_reqs,
	COALESCE(sum(failure_rps), 0) as failure_reqs
	FROM timeseries
	WHERE timestamp BETWEEN 840000 AND 1140000 GROUP BY experiment_id) AS requests
USING (experiment_id)
LEFT JOIN
(SELECT experiment_id, max(value) as max_replicas_desired
	FROM replicas_desired
	WHERE timestamp BETWEEN 840000 AND 1140000 GROUP BY experiment_id) AS desired_replica_counts 
USING (experiment_id)
LEFT JOIN
(SELECT experiment_id, max(value) as max_replicas_available
	FROM replicas_available
	WHERE timestamp BETWEEN 840000 AND 1140000 GROUP BY experiment_id) AS available_replica_counts 
USING (experiment_id)
LEFT JOIN
(SELECT experiment_id,
	avg(value) AS backend_avg_memory_usage
	FROM container_memory_usage_avg
	WHERE container_name = 'backend' AND timestamp BETWEEN 840000 AND 1140000 GROUP BY experiment_id) AS resource_memory_avg
USING (experiment_id)
LEFT JOIN
(SELECT experiment_id,
	avg(value) AS backend_max_memory_usage
	FROM container_memory_usage_max
	WHERE container_name = 'backend' AND timestamp BETWEEN 840000 AND 1140000 GROUP BY experiment_id) AS resource_memory_max
USING (experiment_id)
LEFT JOIN
(SELECT experiment_id,
	avg(value) AS backend_avg_cpu_usage
	FROM container_cpu_usage_avg
	WHERE container_name = 'backend' AND timestamp BETWEEN 840000 AND 1140000 GROUP BY experiment_id) AS resource_cpu_avg
USING (experiment_id)
LEFT JOIN
(SELECT experiment_id,
	avg(value) AS backend_max_cpu_usage
	FROM container_cpu_usage_max
	WHERE container_name = 'backend' AND timestamp BETWEEN 840000 AND 1140000 GROUP BY experiment_id) AS resource_cpu_max
USING (experiment_id)
WHERE finished = true AND scenario_id LIKE 'scaling%'
) TO '/tmp/scaling-overview.csv' WITH CSV HEADER;
