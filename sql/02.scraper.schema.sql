--
-- Create filecoin_storage_providers_energy_scraper schema
--

CREATE SCHEMA IF NOT EXISTS filecoin_storage_providers_energy_scraper AUTHORIZATION filecoin_storage_providers_energy;

--DROP TABLE IF EXISTS filecoin_storage_providers_energy_scraper.payloads;
CREATE TABLE IF NOT EXISTS filecoin_storage_providers_energy_scraper.payloads (
	"id" SERIAL PRIMARY KEY,
	"api" VARCHAR(255) NOT NULL,
	"from" TIMESTAMPTZ NOT NULL,
	"to" TIMESTAMPTZ NOT NULL,
	"offset" INTEGER DEFAULT 0,
	"limit" INTEGER DEFAULT 10000,
	"body" JSONB DEFAULT NULL,
	"processed" BOOLEAN DEFAULT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS payloads_id_idx ON filecoin_storage_providers_energy_scraper.payloads ("id");
CREATE INDEX IF NOT EXISTS payloads_api_idx ON filecoin_storage_providers_energy_scraper.payloads ("api");
CREATE INDEX IF NOT EXISTS payloads_from_idx ON filecoin_storage_providers_energy_scraper.payloads ("from");
CREATE INDEX IF NOT EXISTS payloads_to_idx ON filecoin_storage_providers_energy_scraper.payloads ("to");
