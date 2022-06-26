--
-- Create filecoin_storage_providers_energy_api schema
--

CREATE SCHEMA IF NOT EXISTS filecoin_storage_providers_energy_api AUTHORIZATION filecoin_storage_providers_energy;

--DROP TABLE IF EXISTS filecoin_storage_providers_energy_api.storage_providers;
CREATE TABLE IF NOT EXISTS filecoin_storage_providers_energy_api.storage_providers (
	"id" SERIAL PRIMARY KEY,
	"storage_provider" VARCHAR(255) NOT NULL,
	"description" TEXT DEFAULT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS storage_providers_id_idx ON filecoin_storage_providers_energy_api.storage_providers ("id");
CREATE INDEX IF NOT EXISTS storage_providers_storage_provider_idx ON filecoin_storage_providers_energy_api.storage_providers ("storage_provider");

--DROP TABLE IF EXISTS filecoin_storage_providers_energy_api.storage_provider_apis;
CREATE TABLE IF NOT EXISTS filecoin_storage_providers_energy_api.storage_provider_apis (
	"id" SERIAL PRIMARY KEY,
	"storage_provider_id" INTEGER REFERENCES filecoin_storage_providers_energy_api.storage_providers(id) ON DELETE CASCADE,
	"api" VARCHAR(255) NOT NULL,
	"name" VARCHAR(255) NOT NULL,
	"description" TEXT DEFAULT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS storage_provider_apis_id_idx ON filecoin_storage_providers_energy_api.storage_provider_apis ("id");
CREATE INDEX IF NOT EXISTS storage_provider_apis_api_idx ON filecoin_storage_providers_energy_api.storage_provider_apis ("api");
CREATE INDEX IF NOT EXISTS storage_provider_apis_name_idx ON filecoin_storage_providers_energy_api.storage_provider_apis ("name");

--DROP TABLE IF EXISTS filecoin_storage_providers_energy_api.hardware;
CREATE TABLE IF NOT EXISTS filecoin_storage_providers_energy_api.hardware (
	"id" SERIAL PRIMARY KEY,
	"storage_provider_id" INTEGER REFERENCES filecoin_storage_providers_energy_api.storage_providers(id) ON DELETE CASCADE,
	"name" VARCHAR(255) NOT NULL,
	"functions" VARCHAR(255)[] NOT NULL,
	"rack" VARCHAR(255) NOT NULL,
	"miner" VARCHAR(255) NOT NULL,
	"ip" VARCHAR(255) NOT NULL,
	"location" VARCHAR(255) NOT NULL,
	"description" TEXT DEFAULT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS hardware_id_idx ON filecoin_storage_providers_energy_api.hardware ("id");
CREATE INDEX IF NOT EXISTS hardware_name_idx ON filecoin_storage_providers_energy_api.hardware ("name");
CREATE INDEX IF NOT EXISTS hardware_miner_idx ON filecoin_storage_providers_energy_api.hardware ("miner");
CREATE INDEX IF NOT EXISTS hardware_ip_idx ON filecoin_storage_providers_energy_api.hardware ("ip");
CREATE INDEX IF NOT EXISTS hardware_location_idx ON filecoin_storage_providers_energy_api.hardware ("location");

--DROP TABLE IF EXISTS filecoin_storage_providers_energy_api.power;
CREATE TABLE IF NOT EXISTS filecoin_storage_providers_energy_api.power (
	"id" SERIAL PRIMARY KEY,
	"api_id" INTEGER REFERENCES filecoin_storage_providers_energy_api.storage_provider_apis(id) ON DELETE CASCADE,
	"hardware_id" INTEGER REFERENCES filecoin_storage_providers_energy_api.hardware(id) ON DELETE CASCADE,
	"time" TIMESTAMPTZ NOT NULL,
	"power" DOUBLE PRECISION NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS power_id_idx ON filecoin_storage_providers_energy_api.power ("id");

--DROP TABLE IF EXISTS filecoin_storage_providers_energy_api.energy;
CREATE TABLE IF NOT EXISTS filecoin_storage_providers_energy_api.energy (
	"id" SERIAL PRIMARY KEY,
	"api_id" INTEGER REFERENCES filecoin_storage_providers_energy_api.storage_provider_apis(id) ON DELETE CASCADE,
	"hardware_id" INTEGER REFERENCES filecoin_storage_providers_energy_api.hardware(id) ON DELETE CASCADE,
	"time" TIMESTAMPTZ NOT NULL,
	"energy" DOUBLE PRECISION NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS energy_id_idx ON filecoin_storage_providers_energy_api.energy ("id");

--
-- Process scraped data
--
--DROP FUNCTION IF EXISTS filecoin_storage_providers_energy_api.process_scraped_data();
CREATE OR REPLACE FUNCTION filecoin_storage_providers_energy_api.process_scraped_data() RETURNS void AS $process_scraped_data$
	DECLARE
		rec RECORD;
		rec_sub RECORD;
		api_id INTEGER;
		api_name VARCHAR(255);
		sp_id INTEGER;
		sp_name VARCHAR(255);
		jsonRec JSONB;
		jsonRecVal JSONB;
		json_ip VARCHAR(255);
		hardware_id INTEGER;
	BEGIN
		FOR rec IN SELECT * FROM filecoin_storage_providers_energy_scraper.payloads WHERE processed IS NULL OR processed = FALSE
		LOOP
			SELECT "id", "name", "storage_provider_id" INTO api_id, api_name, sp_id FROM filecoin_storage_providers_energy_api.storage_provider_apis WHERE "api" = rec.api;
			SELECT "storage_provider" INTO sp_name FROM filecoin_storage_providers_energy_api.storage_providers WHERE "id" = sp_id;
			IF (rec.api = 'DCENT_ENERGY_CONSUMPTION_HEERHUGOWAARD_PC1WORKER' OR
				rec.api = 'DCENT_ENERGY_CONSUMPTION_HEERHUGOWAARD_PC2WORKER') THEN
				FOR jsonRec IN SELECT * FROM jsonb_array_elements(rec.body)
				LOOP
					json_ip = jsonRec->>'Ip';
					SELECT "id" INTO hardware_id FROM filecoin_storage_providers_energy_api.hardware WHERE "ip" = json_ip;
					RAISE NOTICE '% % % % % % % % %', sp_id, sp_name, api_id, api_name, rec.api, json_ip, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION;
					INSERT INTO filecoin_storage_providers_energy_api.power ("api_id", "hardware_id", "time", "power")
						VALUES (api_id, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION);
				END LOOP;
			ELSIF (rec.api = 'DCENT_ENERGY_CONSUMPTION_HEERHUGOWAARD_SMAINVERTER') THEN
				FOR jsonRec IN SELECT * FROM jsonb_array_elements(rec.body)
				LOOP
					SELECT "id" INTO hardware_id FROM filecoin_storage_providers_energy_api.hardware WHERE "storage_provider_id" = sp_id AND "name" = 'Solar pannels';
					RAISE NOTICE '% % % % % % % %', sp_id, sp_name, api_id, api_name, rec.api, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION;
					INSERT INTO filecoin_storage_providers_energy_api.power ("api_id", "hardware_id", "time", "power")
						VALUES (api_id, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION);
				END LOOP;
			ELSIF (rec.api = 'DCENT_POWER_GRID') THEN
				FOR rec_sub IN SELECT * FROM jsonb_each(rec.body)
				LOOP
					FOR jsonRecVal IN SELECT * FROM jsonb_array_elements(rec_sub.value)
					LOOP
						IF (rec_sub.key = '16080') THEN
							RAISE NOTICE '% % % % % % % %', sp_id, sp_name, api_id, api_name, rec.api, rec_sub.key, (jsonRecVal->>'value')::DOUBLE PRECISION * 1000, to_timestamp((jsonRecVal->>'timestamp')::INTEGER)::timestamptz;
							INSERT INTO filecoin_storage_providers_energy_api.energy ("api_id", "hardware_id", "time", "energy")
								VALUES (api_id, hardware_id, to_timestamp((jsonRecVal->>'timestamp')::INTEGER)::timestamptz, (jsonRecVal->>'value')::DOUBLE PRECISION * 1000);
						END IF;
					END LOOP;
				END LOOP;
			END IF;
			UPDATE filecoin_storage_providers_energy_scraper.payloads SET processed = TRUE WHERE "id" = rec.id;
		END LOOP;
	END;
$process_scraped_data$ LANGUAGE plpgsql;
