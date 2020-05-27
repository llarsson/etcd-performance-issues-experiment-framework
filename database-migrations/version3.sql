CREATE TABLE IF NOT EXISTS istio_requests_total_backend (
	experiment_id UUID REFERENCES experiments (experiment_id),
	timestamp INTEGER,
	value REAL
);
