CREATE TABLE IF NOT EXISTS flannel_container_restarts (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS flannel_instance_count (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS scheduler_container_restarts (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS scheduler_instance_count (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS controller_manager_container_restarts (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS controller_manager_instance_count (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS apiserver_container_restarts (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS apiserver_instance_count (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS cluster_disk_bytes_written (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS cluster_disk_bytes_read (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS cluster_network_bytes_written (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

CREATE TABLE IF NOT EXISTS cluster_network_bytes_read (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);

