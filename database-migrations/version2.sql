CREATE TABLE IF NOT EXISTS backend_container_memory_usage_per_pod (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	pod_name TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS backend_container_cpu_usage_per_pod (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	pod_name TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS istio_container_memory_usage_per_pod (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	pod_name TEXT,
	value REAL
);

CREATE TABLE IF NOT EXISTS istio_container_cpu_usage_per_pod (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	pod_name TEXT,
	value REAL
);
