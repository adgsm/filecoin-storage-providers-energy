-- login as postgres
CREATE ROLE filecoin_storage_providers_energy WITH LOGIN PASSWORD '****secret****';
CREATE DATABASE filecoin_storage_providers_energy;
\c filecoin_storage_providers_energy
CREATE SCHEMA IF NOT EXISTS filecoin_storage_providers_energy_api AUTHORIZATION filecoin_storage_providers_energy;
CREATE SCHEMA IF NOT EXISTS filecoin_storage_providers_energy_scraper AUTHORIZATION filecoin_storage_providers_energy;
