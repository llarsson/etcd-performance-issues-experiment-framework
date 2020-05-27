\copy (SELECT experiment_id FROM experiments WHERE scenario_id LIKE 'demand%' AND finished = true) TO '/tmp/all-demand.txt';
