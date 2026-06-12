# Fetch (and cache) the RECONFORT deciduous (OSO) binary mask

Ensures a local copy of the default OSO 2021 deciduous mask used to
restrict RECONFORT scoring to broadleaf pixels, and returns its path.
Resolution order mirrors
[`ensure_reconfort_model`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_model.md):

1.  if \`local_path\` is given, that file is used directly (verified
    unless \`verify = FALSE\`);

2.  else, a verified cached copy is returned without download;

3.  else the mask is downloaded, verified and cached.

## Usage

``` r
ensure_reconfort_oso_mask(
  cache_dir = NULL,
  local_path = NULL,
  url = NULL,
  force = FALSE,
  verify = TRUE,
  quiet = FALSE
)
```

## Arguments

- cache_dir:

  Cache directory. Default a per-user nemeton cache.

- local_path:

  Optional path to a mask already on disk (e.g. a custom broadleaf mask,
  or \`\<reconfort_clone\>/masks/...\`). When set, no download happens
  and (for a custom mask) verification is skipped if \`verify = FALSE\`.

- url:

  Optional explicit download URL overriding the registry default (from
  \`options(nemeton.reconfort_mask_base_url)\`).

- force:

  Re-download even if a valid cached copy exists.

- verify:

  Verify size + MD5 against
  [`RECONFORT_OSO_MASK`](https://pobsteta.github.io/nemeton/reference/RECONFORT_OSO_MASK.md).
  Default \`TRUE\`. Pass \`FALSE\` when supplying a custom
  \`local_path\`.

- quiet:

  Suppress progress messages. Default \`FALSE\`.

## Value

The path to the local mask file.

## Details

The mask is ~54 MB; the first fetch is slow. The cache lives under
\`cache_dir\` (default \`file.path(get_global_cache_dir(),
"reconfort_masks")\`).
