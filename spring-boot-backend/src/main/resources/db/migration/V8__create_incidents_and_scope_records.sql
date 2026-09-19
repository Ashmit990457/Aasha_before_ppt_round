CREATE TABLE IF NOT EXISTS incidents (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    searchable BOOLEAN NOT NULL DEFAULT TRUE,
    district VARCHAR(255),
    state VARCHAR(255),
    latitude DOUBLE,
    longitude DOUBLE,
    radius_km DOUBLE,
    created_by VARCHAR(128),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_incidents_active_searchable (active, searchable),
    INDEX idx_incidents_created_at (created_at)
);

ALTER TABLE alerts ADD COLUMN incident_id VARCHAR(64) NULL;
ALTER TABLE normal_records ADD COLUMN incident_id VARCHAR(64) NULL;
ALTER TABLE critical_records ADD COLUMN incident_id VARCHAR(64) NULL;

ALTER TABLE alerts ADD INDEX idx_alerts_incident_id (incident_id);
ALTER TABLE normal_records ADD INDEX idx_normal_incident_id (incident_id);
ALTER TABLE critical_records ADD INDEX idx_critical_incident_id (incident_id);

ALTER TABLE alerts ADD CONSTRAINT fk_alerts_incident
    FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE SET NULL;
ALTER TABLE normal_records ADD CONSTRAINT fk_normal_records_incident
    FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE SET NULL;
ALTER TABLE critical_records ADD CONSTRAINT fk_critical_records_incident
    FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE SET NULL;
