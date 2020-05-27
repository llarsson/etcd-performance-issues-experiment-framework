CREATE TABLE IF NOT EXISTS scenarios (
	scenario_id TEXT PRIMARY KEY,
	description TEXT,
	min_replicas INTEGER,
	max_replicas INTEGER,
	clients INTEGER,
	duration_seconds INTEGER,
	think_time_milliseconds INTEGER,
	service_mesh TEXT,
	service_mesh_version TEXT
);

CREATE TABLE IF NOT EXISTS experiments (
	experiment_id UUID PRIMARY KEY,
	scenario_id TEXT REFERENCES scenarios (scenario_id),
	git_hash_experiments_repo VARCHAR(50),
	git_hash_demo_repo VARCHAR(50),
	start_time TIMESTAMP WITH TIME ZONE,
	end_time TIMESTAMP WITH TIME ZONE,
	kubectl_get_all_pods REAL,
	cluster_info TEXT,
	kubectl_context TEXT,
	service_mesh_details TEXT,
	hostname TEXT,
	finished BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS timeseries (
	experiment_id UUID REFERENCES experiments (experiment_id),
  	timestamp INTEGER,
  	success_rps REAL,
  	success_avg REAL,
  	success_median REAL,
  	success_min REAL,
  	success_max REAL,
  	failure_rps REAL,
  	failure_avg REAL,
  	failure_median REAL,
  	failure_min REAL,
  	failure_max REAL,
  	total_rps REAL,
  	total_avg REAL,
  	total_median REAL,
  	total_min REAL,
  	total_max REAL,
  	connect_time_avg REAL,
  	connect_time_median REAL,
  	connect_time_min REAL,
  	connect_time_max REAL,
  	threadcount INTEGER
);

CREATE TABLE IF NOT EXISTS statistics (
	experiment_id UUID REFERENCES experiments (experiment_id),
  	success_reqs INTEGER,
  	success_min REAL,
  	success_avg REAL,
  	success_median REAL,
  	success_max REAL,
  	success_percentile_50 REAL,
  	success_percentile_75 REAL,
  	success_percentile_90 REAL,
  	success_percentile_95 REAL,
  	success_percentile_99 REAL,
  	failure_reqs INTEGER,
  	failure_min REAL,
  	failure_avg REAL,
  	failure_median REAL,
  	failure_max REAL,
  	failure_percentile_50 REAL,
  	failure_percentile_75 REAL,
  	failure_percentile_90 REAL,
  	failure_percentile_95 REAL,
  	failure_percentile_99 REAL,
  	total_reqs INTEGER,
  	total_min REAL,
  	total_avg REAL,
  	total_median REAL,
  	total_max REAL,
  	total_percentile_50 REAL,
  	total_percentile_75 REAL,
  	total_percentile_90 REAL,
  	total_percentile_95 REAL,
  	total_percentile_99 REAL,
  	connect_time_min REAL,
  	connect_time_avg REAL,
  	connect_time_median REAL,
  	connect_time_max REAL,
  	connect_time_percentile_50 REAL,
  	connect_time_percentile_75 REAL,
  	connect_time_percentile_90 REAL,
  	connect_time_percentile_95 REAL,
  	connect_time_percentile_99 REAL
);

CREATE TABLE IF NOT EXISTS cluster_cpu_utilisation (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS cluster_memory_utilisation (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS replicas_desired (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS replicas_unavailable (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS replicas_available (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS container_memory_usage_min (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	container_name TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS container_memory_usage_avg (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	container_name TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS container_memory_usage_max (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	container_name TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS container_cpu_usage_min (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	container_name TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS container_cpu_usage_avg (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	container_name TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS container_cpu_usage_max (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	container_name TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS container_restarts (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS memory_usage_per_namespace (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	namespace TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS cpu_usage_per_namespace (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	namespace TEXT,
	value REAL
);

