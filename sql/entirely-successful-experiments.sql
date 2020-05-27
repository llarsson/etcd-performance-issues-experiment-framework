SELECT scenario_id, experiment_id FROM (select scenario_id, experiment_id, successes, total_timestamps from experiments JOIN (SELECT experiment_id, count(experiment_id) as successes FROM timeseries where COALESCE(success_rps,0) > COALESCE(failure_rps,0) group by experiment_id) AS foo USING (experiment_id) JOIN (SELECT experiment_id, count(timestamp) AS total_timestamps FROM timeseries group by experiment_id) AS bar USING (experiment_id)) AS baz WHERE successes / total_timestamps >= 0.90 AND scenario_id LIKE 'demand%';