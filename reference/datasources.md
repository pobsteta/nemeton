# Data Source Configuration by Country

Abstraction layer for geographic data sources (ADR-002). Data source
URLs and service endpoints are never hardcoded in the code. They are
declared in JSON configuration files per country
(`inst/datasources/FR.json`, `inst/datasources/DE.json`, etc.).

Adding a new country requires only a JSON configuration file, not code
modifications.
