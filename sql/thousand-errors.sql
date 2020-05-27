SELECT experiment_id, service_mesh, min_replicas, clients, time_1000_errors, time_10000_errors
FROM scenarios NATURAL JOIN experiments NATURAL JOIN
(SELECT experiment_id, timestamp, sum(failure_rps) OVER (PARTITION BY experiment_id ORDER BY timestamp) as cumsum_failures FROM timeseries) AS 
