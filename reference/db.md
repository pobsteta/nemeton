# Database Connection and Migration Helpers (E6 monitoring)

Thin wrappers around DBI to connect to the monitoring database and apply
the SQL migrations bundled in \`inst/db/migrations/\`.

Two backends are supported transparently:

\* \*\*PostgreSQL + TimescaleDB + PostGIS\*\* — production / shared
deployment. URL form \`postgresql://user:pass@host:port/dbname\`. Uses
\[RPostgres::Postgres()\]. Migrations from \`inst/db/migrations/pg/\`
are applied. Since 1.0.0 TimescaleDB is \*\*optional\*\*: the extension
is enabled only when the server offers it, and no table depends on it
(PostGIS remains required). \* \*\*SQLite (WAL)\*\* — single-user /
local mode for \`nemetonshiny\` users who do not run Postgres. URL form
\`sqlite:///path/to/file.sqlite\` (three slashes for an absolute path).
Uses \[RSQLite::SQLite()\] in WAL mode (one writer + many concurrent
readers across processes). Migrations from
\`inst/db/migrations/sqlite/\` are applied — same schema, minus the
\`CREATE EXTENSION\` statements.

Selection is driven entirely by the URL scheme, so callers (notably
\`nemetonshiny::get_monitoring_db_url()\`) pick the backend by emitting
the right URL — \`db_connect()\` does the rest.

These helpers are only used by the optional monitoring subsystem (spec
007). All DB-dependent code paths gracefully degrade when the required
driver package is not installed.
