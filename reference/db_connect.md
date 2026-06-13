# Connect to the monitoring database

Reads the connection URL from \`NEMETON_DB_URL\` (or the \`url\`
argument), inspects its scheme, and opens the matching connection. Use
\[db_disconnect()\] to close it.

## Usage

``` r
db_connect(
  url = Sys.getenv("NEMETON_DB_URL"),
  read_only = FALSE,
  connect_timeout = 10L
)
```

## Arguments

- url:

  Character. Connection URL. Two schemes are supported: \*
  \`postgresql://user:password@host:port/dbname\` — opens a
  \[RPostgres::Postgres()\] connection. \*
  \`sqlite:///absolute/path/to/file.sqlite\` — opens a
  \[RSQLite::SQLite()\] connection on the given file in WAL mode (the
  local backend). The file is created if it does not exist. A bare path
  ending in \`.sqlite\` or \`.db\` is also accepted for convenience.
  Defaults to \`Sys.getenv("NEMETON_DB_URL")\`.

  The DuckDB backend was removed in 0.51.0; a \`duckdb:///\` URL now
  raises an error pointing at \`sqlite:///\`.

- read_only:

  Logical. Open the connection in read-only mode. Defaults to \`FALSE\`.
  Relevant only for the SQLite file backend; the file must already exist
  and its parent directory is \*not\* created. For \*\*PostgreSQL\*\*
  the flag is a no-op (it manages concurrent readers and writers
  natively).

- connect_timeout:

  Positive number of seconds bounding the connection attempt. Passed to
  libpq as the \`connect_timeout\` parameter for the \*\*PostgreSQL\*\*
  backend (caps the hang on an unreachable host); \*\*ignored\*\* for
  the SQLite file backend. Defaults to \`10L\`.

## Value

A \`DBIConnection\`.

## Details

\*\*SQLite is the local backend.\*\* Opened in WAL (write-ahead logging)
mode, a file-backed SQLite database supports a single writer plus
several concurrent readers \*across processes\* — so a Shiny session and
a \`future\` ingestion worker can use the same file at once.
\`busy_timeout\` is set so a momentarily locked write waits instead of
erroring, and \`foreign_keys\` is enabled.

## Examples

``` r
if (FALSE) { # \dontrun{
# Postgres (production)
Sys.setenv(NEMETON_DB_URL = "postgresql://nemeton:secret@127.0.0.1:5432/nemeton")
con <- db_connect()
db_disconnect(con)

# SQLite (recommended local mode, WAL)
Sys.setenv(NEMETON_DB_URL = "sqlite:///tmp/my_project/monitoring.sqlite")
con <- db_connect()
db_disconnect(con)

# SQLite read-only reader, safe to open while a worker writes
ro <- db_connect("sqlite:///tmp/my_project/monitoring.sqlite",
                 read_only = TRUE)
db_disconnect(ro)
} # }
```
