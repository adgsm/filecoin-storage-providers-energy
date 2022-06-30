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
-- Process scraped data manually
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
--					RAISE NOTICE '% % % % % % % % %', sp_id, sp_name, api_id, api_name, rec.api, json_ip, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION;
					INSERT INTO filecoin_storage_providers_energy_api.power ("api_id", "hardware_id", "time", "power")
						VALUES (api_id, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION);
				END LOOP;
			ELSIF (rec.api = 'DCENT_ENERGY_CONSUMPTION_HEERHUGOWAARD_SMAINVERTER') THEN
				SELECT "id" INTO hardware_id FROM filecoin_storage_providers_energy_api.hardware WHERE "storage_provider_id" = sp_id AND "name" = 'Solar pannels';
				FOR jsonRec IN SELECT * FROM jsonb_array_elements(rec.body)
				LOOP
--					RAISE NOTICE '% % % % % % % %', sp_id, sp_name, api_id, api_name, rec.api, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION;
					INSERT INTO filecoin_storage_providers_energy_api.power ("api_id", "hardware_id", "time", "power")
						VALUES (api_id, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION);
				END LOOP;
			ELSIF (rec.api = 'DCENT_POWER_GRID') THEN
				SELECT "id" INTO hardware_id FROM filecoin_storage_providers_energy_api.hardware WHERE "storage_provider_id" = sp_id AND "name" = 'Power grid plug';
				FOR rec_sub IN SELECT * FROM jsonb_each(rec.body)
				LOOP
					FOR jsonRecVal IN SELECT * FROM jsonb_array_elements(rec_sub.value)
					LOOP
						IF (rec_sub.key = '16080') THEN
--							RAISE NOTICE '% % % % % % % %', sp_id, sp_name, api_id, api_name, rec.api, rec_sub.key, (jsonRecVal->>'value')::DOUBLE PRECISION * 1000, to_timestamp((jsonRecVal->>'timestamp')::INTEGER)::timestamptz;
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

--
-- Process scraped record following insert trigger
--
--DROP FUNCTION IF EXISTS filecoin_storage_providers_energy_api.process_scraped_record();
CREATE OR REPLACE FUNCTION filecoin_storage_providers_energy_api.process_scraped_record() RETURNS TRIGGER AS $process_scraped_record$
	DECLARE
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
		SELECT "id", "name", "storage_provider_id" INTO api_id, api_name, sp_id FROM filecoin_storage_providers_energy_api.storage_provider_apis WHERE "api" = NEW.api;
		SELECT "storage_provider" INTO sp_name FROM filecoin_storage_providers_energy_api.storage_providers WHERE "id" = sp_id;
		IF (NEW.api = 'DCENT_ENERGY_CONSUMPTION_HEERHUGOWAARD_PC1WORKER' OR
			NEW.api = 'DCENT_ENERGY_CONSUMPTION_HEERHUGOWAARD_PC2WORKER') THEN
			FOR jsonRec IN SELECT * FROM jsonb_array_elements(NEW.body)
			LOOP
				json_ip = jsonRec->>'Ip';
				SELECT "id" INTO hardware_id FROM filecoin_storage_providers_energy_api.hardware WHERE "ip" = json_ip;
--					RAISE NOTICE '% % % % % % % % %', sp_id, sp_name, api_id, api_name, NEW.api, json_ip, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION;
				INSERT INTO filecoin_storage_providers_energy_api.power ("api_id", "hardware_id", "time", "power")
					VALUES (api_id, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION);
			END LOOP;
		ELSIF (NEW.api = 'DCENT_ENERGY_CONSUMPTION_HEERHUGOWAARD_SMAINVERTER') THEN
			SELECT "id" INTO hardware_id FROM filecoin_storage_providers_energy_api.hardware WHERE "storage_provider_id" = sp_id AND "name" = 'Solar pannels';
			FOR jsonRec IN SELECT * FROM jsonb_array_elements(NEW.body)
			LOOP
--					RAISE NOTICE '% % % % % % % %', sp_id, sp_name, api_id, api_name, NEW.api, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION;
				INSERT INTO filecoin_storage_providers_energy_api.power ("api_id", "hardware_id", "time", "power")
					VALUES (api_id, hardware_id, (jsonRec->>'Time')::TIMESTAMPTZ, (jsonRec->>'Power')::DOUBLE PRECISION);
			END LOOP;
		ELSIF (NEW.api = 'DCENT_POWER_GRID') THEN
			SELECT "id" INTO hardware_id FROM filecoin_storage_providers_energy_api.hardware WHERE "storage_provider_id" = sp_id AND "name" = 'Power grid plug';
			FOR rec_sub IN SELECT * FROM jsonb_each(NEW.body)
			LOOP
				FOR jsonRecVal IN SELECT * FROM jsonb_array_elements(rec_sub.value)
				LOOP
					IF (rec_sub.key = '16080') THEN
--							RAISE NOTICE '% % % % % % % %', sp_id, sp_name, api_id, api_name, NEW.api, rec_sub.key, (jsonRecVal->>'value')::DOUBLE PRECISION * 1000, to_timestamp((jsonRecVal->>'timestamp')::INTEGER)::timestamptz;
						INSERT INTO filecoin_storage_providers_energy_api.energy ("api_id", "hardware_id", "time", "energy")
							VALUES (api_id, hardware_id, to_timestamp((jsonRecVal->>'timestamp')::INTEGER)::timestamptz, (jsonRecVal->>'value')::DOUBLE PRECISION * 1000);
					END IF;
				END LOOP;
			END LOOP;
		END IF;
		UPDATE filecoin_storage_providers_energy_scraper.payloads SET processed = TRUE WHERE "id" = NEW.id;
		RETURN NULL; -- result will be ignored since this is AFTER trigger function
	END;
$process_scraped_record$ LANGUAGE plpgsql;

--
-- Scraper payload insert trigger
--
DROP TRIGGER IF EXISTS new_payload_trgger ON filecoin_storage_providers_energy_scraper.payloads;
CREATE TRIGGER new_payload_trgger AFTER INSERT OR UPDATE ON filecoin_storage_providers_energy_scraper.payloads
	FOR EACH ROW
	WHEN (pg_trigger_depth() = 0)
	EXECUTE PROCEDURE filecoin_storage_providers_energy_api.process_scraped_record();

--
-- Search / filter storage provider's hardware
--
DROP TYPE response_search_hardware CASCADE;
CREATE TYPE response_search_hardware AS (hardware_id INTEGER, storage_provider_id INTEGER, hardware_name VARCHAR(255),
	hardware_functions VARCHAR(255)[], rack VARCHAR(255), miner_id VARCHAR(255), ip VARCHAR(255), location VARCHAR(255), description TEXT);

--DROP FUNCTION IF EXISTS filecoin_storage_providers_energy_api.search_hardware(IN in_storage_provider_id INTEGER, IN in_names VARCHAR(255)[], IN in_miners VARCHAR(255)[], IN in_functions VARCHAR(255)[], IN in_racks VARCHAR(255)[], IN in_locations VARCHAR(255)[]);
CREATE OR REPLACE FUNCTION filecoin_storage_providers_energy_api.search_hardware(IN in_storage_provider_id INTEGER, IN in_names VARCHAR(255)[], IN in_miners VARCHAR(255)[], IN in_functions VARCHAR(255)[], IN in_racks VARCHAR(255)[], IN in_locations VARCHAR(255)[]) RETURNS SETOF response_search_hardware AS $search_hardware$
	DECLARE
		names_length SMALLINT = array_length(in_names, 1);
		names VARCHAR = '';
		counter_names SMALLINT = 1;
		miners_length SMALLINT = array_length(in_miners, 1);
		miners VARCHAR = '';
		counter_miners SMALLINT = 1;
		racks_length SMALLINT = array_length(in_racks, 1);
		racks VARCHAR = '';
		counter_racks SMALLINT = 1;
		locations_length SMALLINT = array_length(in_locations, 1);
		locations VARCHAR = '';
		counter_locations SMALLINT = 1;
		functions_length SMALLINT = array_length(in_functions, 1);
		functions VARCHAR = '';
		rcrd response_search_hardware;
	BEGIN
		-- constructing search sub-query per provided names
		IF (names_length > 0) THEN
			names = concat(names, 'AND (');
			WHILE counter_names <= names_length LOOP
				IF (counter_names > 1) THEN
					names = concat(names, ' OR ');
				END IF;
				names = concat(names, format('lower("name") LIKE lower(%L)', concat('%', translate(in_names[counter_names], '''', ''), '%')));
				counter_names = counter_names + 1;
			END LOOP;
			names = concat(names, ')');
		END IF;

		-- constructing search sub-query per provided miners
		IF (miners_length > 0) THEN
			miners = concat(miners, 'AND (');
			WHILE counter_miners <= miners_length LOOP
				IF (counter_miners > 1) THEN
					miners = concat(miners, ' OR ');
				END IF;
				miners = concat(miners, format('lower("miner") LIKE lower(%L)', concat('%', translate(in_miners[counter_miners], '''', ''), '%')));
				counter_miners = counter_miners + 1;
			END LOOP;
			miners = concat(miners, ')');
		END IF;

		-- constructing search sub-query per provided racks
		IF (racks_length > 0) THEN
			racks = concat(racks, 'AND (');
			WHILE counter_racks <= racks_length LOOP
				IF (counter_racks > 1) THEN
					racks = concat(racks, ' OR ');
				END IF;
				racks = concat(racks, format('lower("rack") LIKE lower(%L)', concat('%', translate(in_racks[counter_racks], '''', ''), '%')));
				counter_racks = counter_racks + 1;
			END LOOP;
			racks = concat(racks, ')');
		END IF;

		-- constructing search sub-query per provided locations
		IF (locations_length > 0) THEN
			locations = concat(locations, 'AND (');
			WHILE counter_locations <= locations_length LOOP
				IF (counter_locations > 1) THEN
					locations = concat(locations, ' OR ');
				END IF;
				locations = concat(locations, format('lower("location") LIKE lower(%L)', concat('%', translate(in_locations[counter_locations], '''', ''), '%')));
				counter_locations = counter_locations + 1;
			END LOOP;
			locations = concat(locations, ')');
		END IF;

		-- constructing search sub-query per provided functions
		IF (functions_length > 0) THEN
			locations = concat(locations, format(' AND (lower(%L::text))::text[] && (lower("functions"::text))::text[]', in_functions));
		END IF;

		-- resultset
		FOR rcrd IN
		EXECUTE format('
			SELECT "id", "storage_provider_id", "name", "functions", "rack", "miner", "ip", "location", "description"
			FROM filecoin_storage_providers_energy_api.hardware
			WHERE "storage_provider_id" = %L
			%s
			%s
			%s
			%s
			%s
			ORDER BY "id" ASC;',
			in_storage_provider_id,
			names,
			miners,
			racks,
			locations,
			functions
		)
		LOOP
			RETURN NEXT rcrd;
		END LOOP;
	END;
$search_hardware$ LANGUAGE plpgsql;

--
-- Search / filter storage provider's data related to power consumption
--
DROP TYPE response_search_power CASCADE;
CREATE TYPE response_search_power AS (hardware_id INTEGER, storage_provider_id INTEGER, hardware_name VARCHAR(255),
	hardware_functions VARCHAR(255)[], rack VARCHAR(255), miner_id VARCHAR(255), ip VARCHAR(255), location VARCHAR(255),
	description TEXT, power DOUBLE PRECISION, time TIMESTAMPTZ);

--DROP FUNCTION IF EXISTS filecoin_storage_providers_energy_api.search_power(IN in_storage_provider_id INTEGER, IN in_names VARCHAR(255)[], IN in_miners VARCHAR(255)[], IN in_functions VARCHAR(255)[], IN in_racks VARCHAR(255)[], IN in_locations VARCHAR(255)[], IN in_from TIMESTAMPTZ, IN in_to TIMESTAMPTZ, IN in_offset INTEGER, IN in_limit INTEGER);
CREATE OR REPLACE FUNCTION filecoin_storage_providers_energy_api.search_power(IN in_storage_provider_id INTEGER, IN in_names VARCHAR(255)[], IN in_miners VARCHAR(255)[], IN in_functions VARCHAR(255)[], IN in_racks VARCHAR(255)[], IN in_locations VARCHAR(255)[], IN in_from TIMESTAMPTZ, IN in_to TIMESTAMPTZ, IN in_offset INTEGER, IN in_limit INTEGER) RETURNS SETOF response_search_power AS $search_power$
	DECLARE
		names_length SMALLINT = array_length(in_names, 1);
		names VARCHAR = '';
		counter_names SMALLINT = 1;
		miners_length SMALLINT = array_length(in_miners, 1);
		miners VARCHAR = '';
		counter_miners SMALLINT = 1;
		racks_length SMALLINT = array_length(in_racks, 1);
		racks VARCHAR = '';
		counter_racks SMALLINT = 1;
		locations_length SMALLINT = array_length(in_locations, 1);
		locations VARCHAR = '';
		counter_locations SMALLINT = 1;
		functions_length SMALLINT = array_length(in_functions, 1);
		functions VARCHAR = '';
		rcrd response_search_power;
	BEGIN
		-- return empty set if dates are not provided
		IF (in_from IS NULL OR in_to IS NULL) THEN
		RETURN;
		END IF;
		IF (in_to < in_from) THEN
		RETURN;
		END IF;

		-- pagining
		IF (in_offset IS NULL) THEN
			in_offset = 0;
		END IF;
		IF (in_limit IS NULL OR in_limit > 1000000) THEN
			in_limit = 1000000;
		END IF;

		-- constructing search sub-query per provided names
		IF (names_length > 0) THEN
			names = concat(names, 'AND (');
			WHILE counter_names <= names_length LOOP
				IF (counter_names > 1) THEN
					names = concat(names, ' OR ');
				END IF;
				names = concat(names, format('lower("name") LIKE lower(%L)', concat('%', translate(in_names[counter_names], '''', ''), '%')));
				counter_names = counter_names + 1;
			END LOOP;
			names = concat(names, ')');
		END IF;

		-- constructing search sub-query per provided miners
		IF (miners_length > 0) THEN
			miners = concat(miners, 'AND (');
			WHILE counter_miners <= miners_length LOOP
				IF (counter_miners > 1) THEN
					miners = concat(miners, ' OR ');
				END IF;
				miners = concat(miners, format('lower(h."miner") LIKE lower(%L)', concat('%', translate(in_miners[counter_miners], '''', ''), '%')));
				counter_miners = counter_miners + 1;
			END LOOP;
			miners = concat(miners, ')');
		END IF;

		-- constructing search sub-query per provided racks
		IF (racks_length > 0) THEN
			racks = concat(racks, 'AND (');
			WHILE counter_racks <= racks_length LOOP
				IF (counter_racks > 1) THEN
					racks = concat(racks, ' OR ');
				END IF;
				racks = concat(racks, format('lower(h."rack") LIKE lower(%L)', concat('%', translate(in_racks[counter_racks], '''', ''), '%')));
				counter_racks = counter_racks + 1;
			END LOOP;
			racks = concat(racks, ')');
		END IF;

		-- constructing search sub-query per provided locations
		IF (locations_length > 0) THEN
			locations = concat(locations, 'AND (');
			WHILE counter_locations <= locations_length LOOP
				IF (counter_locations > 1) THEN
					locations = concat(locations, ' OR ');
				END IF;
				locations = concat(locations, format('lower(h."location") LIKE lower(%L)', concat('%', translate(in_locations[counter_locations], '''', ''), '%')));
				counter_locations = counter_locations + 1;
			END LOOP;
			locations = concat(locations, ')');
		END IF;

		-- constructing search sub-query per provided functions
		IF (functions_length > 0) THEN
			locations = concat(locations, format(' AND (lower(%L::text))::text[] && (lower(h."functions"::text))::text[]', in_functions));
		END IF;

		-- resultset
		FOR rcrd IN
		EXECUTE format('
			SELECT h."id" AS "hardware_id", h."storage_provider_id", h."name", h."functions", h."rack", h."miner", h."ip",
				h."location", h."description", p."power", p."time"
			FROM filecoin_storage_providers_energy_api.hardware h
			INNER JOIN filecoin_storage_providers_energy_api.power p
			ON h.id = p.hardware_id
			WHERE h."storage_provider_id" = %L
			AND p."time" >= %L AND p."time" <= %L
			%s
			%s
			%s
			%s
			%s
			ORDER BY p."time" ASC OFFSET %s LIMIT %s;',
			in_storage_provider_id,
			in_from, in_to,
			names,
			miners,
			racks,
			locations,
			functions,
			in_offset, in_limit
		)
		LOOP
			RETURN NEXT rcrd;
		END LOOP;
	END;
$search_power$ LANGUAGE plpgsql;

--
-- Search / filter storage provider's data related to energy consumption
--
DROP TYPE response_search_energy CASCADE;
CREATE TYPE response_search_energy AS (hardware_id INTEGER, storage_provider_id INTEGER, hardware_name VARCHAR(255),
	hardware_functions VARCHAR(255)[], rack VARCHAR(255), miner_id VARCHAR(255), ip VARCHAR(255), location VARCHAR(255),
	description TEXT, energy DOUBLE PRECISION, time TIMESTAMPTZ);

--DROP FUNCTION IF EXISTS filecoin_storage_providers_energy_api.search_energy(IN in_storage_provider_id INTEGER, IN in_names VARCHAR(255)[], IN in_miners VARCHAR(255)[], IN in_functions VARCHAR(255)[], IN in_racks VARCHAR(255)[], IN in_locations VARCHAR(255)[], IN in_from TIMESTAMPTZ, IN in_to TIMESTAMPTZ, IN in_offset INTEGER, IN in_limit INTEGER);
CREATE OR REPLACE FUNCTION filecoin_storage_providers_energy_api.search_energy(IN in_storage_provider_id INTEGER, IN in_names VARCHAR(255)[], IN in_miners VARCHAR(255)[], IN in_functions VARCHAR(255)[], IN in_racks VARCHAR(255)[], IN in_locations VARCHAR(255)[], IN in_from TIMESTAMPTZ, IN in_to TIMESTAMPTZ, IN in_offset INTEGER, IN in_limit INTEGER) RETURNS SETOF response_search_energy AS $search_energy$
	DECLARE
		names_length SMALLINT = array_length(in_names, 1);
		names VARCHAR = '';
		counter_names SMALLINT = 1;
		miners_length SMALLINT = array_length(in_miners, 1);
		miners VARCHAR = '';
		counter_miners SMALLINT = 1;
		racks_length SMALLINT = array_length(in_racks, 1);
		racks VARCHAR = '';
		counter_racks SMALLINT = 1;
		locations_length SMALLINT = array_length(in_locations, 1);
		locations VARCHAR = '';
		counter_locations SMALLINT = 1;
		functions_length SMALLINT = array_length(in_functions, 1);
		functions VARCHAR = '';
		rcrd response_search_energy;
	BEGIN
		-- return empty set if dates are not provided
		IF (in_from IS NULL OR in_to IS NULL) THEN
		RETURN;
		END IF;
		IF (in_to < in_from) THEN
		RETURN;
		END IF;

		-- pagining
		IF (in_offset IS NULL) THEN
			in_offset = 0;
		END IF;
		IF (in_limit IS NULL OR in_limit > 1000000) THEN
			in_limit = 1000000;
		END IF;

		-- constructing search sub-query per provided names
		IF (names_length > 0) THEN
			names = concat(names, 'AND (');
			WHILE counter_names <= names_length LOOP
				IF (counter_names > 1) THEN
					names = concat(names, ' OR ');
				END IF;
				names = concat(names, format('lower("name") LIKE lower(%L)', concat('%', translate(in_names[counter_names], '''', ''), '%')));
				counter_names = counter_names + 1;
			END LOOP;
			names = concat(names, ')');
		END IF;

		-- constructing search sub-query per provided miners
		IF (miners_length > 0) THEN
			miners = concat(miners, 'AND (');
			WHILE counter_miners <= miners_length LOOP
				IF (counter_miners > 1) THEN
					miners = concat(miners, ' OR ');
				END IF;
				miners = concat(miners, format('lower(h."miner") LIKE lower(%L)', concat('%', translate(in_miners[counter_miners], '''', ''), '%')));
				counter_miners = counter_miners + 1;
			END LOOP;
			miners = concat(miners, ')');
		END IF;

		-- constructing search sub-query per provided racks
		IF (racks_length > 0) THEN
			racks = concat(racks, 'AND (');
			WHILE counter_racks <= racks_length LOOP
				IF (counter_racks > 1) THEN
					racks = concat(racks, ' OR ');
				END IF;
				racks = concat(racks, format('lower(h."rack") LIKE lower(%L)', concat('%', translate(in_racks[counter_racks], '''', ''), '%')));
				counter_racks = counter_racks + 1;
			END LOOP;
			racks = concat(racks, ')');
		END IF;

		-- constructing search sub-query per provided locations
		IF (locations_length > 0) THEN
			locations = concat(locations, 'AND (');
			WHILE counter_locations <= locations_length LOOP
				IF (counter_locations > 1) THEN
					locations = concat(locations, ' OR ');
				END IF;
				locations = concat(locations, format('lower(h."location") LIKE lower(%L)', concat('%', translate(in_locations[counter_locations], '''', ''), '%')));
				counter_locations = counter_locations + 1;
			END LOOP;
			locations = concat(locations, ')');
		END IF;

		-- constructing search sub-query per provided functions
		IF (functions_length > 0) THEN
			locations = concat(locations, format(' AND (lower(%L::text))::text[] && (lower(h."functions"::text))::text[]', in_functions));
		END IF;

		-- resultset
		FOR rcrd IN
		EXECUTE format('
			SELECT h."id" AS "hardware_id", h."storage_provider_id", h."name", h."functions", h."rack", h."miner", h."ip",
				h."location", h."description", p."energy", p."time"
			FROM filecoin_storage_providers_energy_api.hardware h
			INNER JOIN filecoin_storage_providers_energy_api.energy p
			ON h.id = p.hardware_id
			WHERE h."storage_provider_id" = %L
			AND p."time" >= %L AND p."time" <= %L
			%s
			%s
			%s
			%s
			%s
			ORDER BY p."time" ASC OFFSET %s LIMIT %s;',
			in_storage_provider_id,
			in_from, in_to,
			names,
			miners,
			racks,
			locations,
			functions,
			in_offset, in_limit
		)
		LOOP
			RETURN NEXT rcrd;
		END LOOP;
	END;
$search_energy$ LANGUAGE plpgsql;

--
-- List all racks / spaces for selecte dstorage provider
--
DROP TYPE response_list_spaces CASCADE;
CREATE TYPE response_list_spaces AS ("space" VARCHAR(255), "order" INTEGER);

--DROP FUNCTION IF EXISTS filecoin_storage_providers_energy_api.list_spaces(IN in_storage_provider_id INTEGER);
CREATE OR REPLACE FUNCTION filecoin_storage_providers_energy_api.list_spaces(IN in_storage_provider_id INTEGER) RETURNS SETOF response_list_spaces AS $list_spaces$
	DECLARE
		rcrd response_list_spaces;
	BEGIN
		-- resultset
		FOR rcrd IN
			SELECT DISTINCT "rack", NULLIF(regexp_replace("rack", '\D', '', 'g'), '')::INTEGER AS "order"
				FROM filecoin_storage_providers_energy_api.hardware
				WHERE storage_provider_id = storage_provider_id
				ORDER BY NULLIF(regexp_replace("rack", '\D', '', 'g'), '')::INTEGER ASC
		LOOP
			RETURN NEXT rcrd;
		END LOOP;
	END;
$list_spaces$ LANGUAGE plpgsql;
