# Download the raw French NFI export

Fetches the IGN annual export archive and caches it in `dest_dir`. An
archive already present is reused, never re-downloaded silently and
never by asking the user a question — see the note below.

## Usage

``` r
ifn_telecharger(dest_dir, campagne = NULL, force = FALSE)
```

## Arguments

- dest_dir:

  Directory holding the cached archive. Created if needed.

- campagne:

  Campaign year to fetch. `NULL` (default) resolves the most recent one
  via
  [`ifn_campagne_disponible`](https://pobsteta.github.io/nemeton/reference/ifn_campagne_disponible.md).

- force:

  Re-download even when the archive is already cached.

## Value

The path to the cached `.zip`, invisibly, with attributes `campagne` and
`millesime`.

## Non-interactive by design

`FrenchNFIfindeR::get_NFI()` calls
[`readline()`](https://rdrr.io/r/base/readline.html) when raw data is
already on disk, asking whether to reuse or re-download. That blocks in
any non-interactive context — a `future` worker, a CI job, a scheduled
build — which is exactly where a download step belongs. Here the choice
is an argument: `force = FALSE` reuses, `force = TRUE` re-downloads.

## Examples

``` r
if (FALSE) { # \dontrun{
zip <- ifn_telecharger(tempdir())
} # }
```
