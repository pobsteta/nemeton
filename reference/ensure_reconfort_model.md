# Fetch (and cache) a RECONFORT Random-Forest model

Ensures a local copy of the requested RECONFORT model is available and
returns its path. Resolution order:

1.  if \`local_path\` is given, that file is used directly (and verified
    unless \`verify = FALSE\`) — handy when the user already cloned the
    upstream repository;

2.  else, if a verified copy already sits in the cache, it is returned
    without downloading;

3.  else the model is downloaded from the upstream URL (or \`url\`),
    verified, and stored in the cache.

## Usage

``` r
ensure_reconfort_model(
  version = "v3",
  cache_dir = NULL,
  local_path = NULL,
  url = NULL,
  force = FALSE,
  verify = TRUE,
  quiet = FALSE
)
```

## Arguments

- version:

  Model version (see
  [`RECONFORT_MODELS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_MODELS.md)).
  Default \`"v3"\`.

- cache_dir:

  Cache directory. Default a per-user nemeton cache.

- local_path:

  Optional path to a model file already on disk (e.g.
  \`\<reconfort_clone\>/models/v3/model_1_seed_0.txt\`). When set, no
  download happens.

- url:

  Optional explicit download URL, overriding the registry default (built
  from \`options(nemeton.reconfort_model_base_url)\`).

- force:

  Re-download even if a valid cached copy exists.

- verify:

  Verify size + MD5 against the registry. Default \`TRUE\`.

- quiet:

  Suppress progress messages. Default \`FALSE\`.

## Value

The path to the local model file (invisibly usable by the L2b pipeline).

## Details

Models are large (5.7-197 MB); the first fetch is slow. The cache lives
under \`cache_dir\` (default \`file.path(get_global_cache_dir(),
"reconfort_models")\`).
