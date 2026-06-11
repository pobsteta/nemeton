# Apply pending SQL migrations

Reads \`\*.sql\` files in \`migrations_dir\` (sorted lexicographically),
compares against the \`schema_migration\` table, and executes the files
that have not yet been applied. The first run also creates
\`schema_migration\` itself (handled by \`0001_init.sql\`).

## Usage

``` r
db_migrate(con, migrations_dir = NULL)
```

## Arguments

- con:

  A \`DBIConnection\` returned by \[db_connect()\].

- migrations_dir:

  Character or \`NULL\`. Path to the migrations directory. Defaults to
  the bundled \`inst/db/migrations/\<driver\>/\`.

## Value

A character vector of versions applied during this call (empty if
everything was up to date).

## Details

When \`migrations_dir\` is left \`NULL\`, the directory is picked
automatically based on the connection's driver — \`pg/\` for Postgres,
\`sqlite/\` for SQLite.

Migrations are executed in a single transaction per file and the
filename (basename without extension) is recorded as the version
identifier.
