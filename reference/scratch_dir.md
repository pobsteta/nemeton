# Scratch directory for a run's bulky intermediates

Long pipelines stream their intermediates to disk rather than holding
them in RAM (see
[`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)).
The volume is not negligible — the RECONFORT feature stacks measured
~800 MB for a 0.89 Mpx AOI over 115 dates, and that scales with pixels x
dates: a department-wide run lands in the tens of GB. \`tempdir()\`
often sits on a small root partition or on tmpfs (i.e. in RAM, which
would defeat the purpose entirely), so the location is configurable.

## Usage

``` r
scratch_dir(subdir = NULL)
```

## Arguments

- subdir:

  Optional sub-directory to create under the scratch root.

## Value

The path, created if needed (character scalar).

## Details

Resolution order:

1.  \`options(nemeton.scratch_dir = "/data/scratch")\`

2.  the \`NEMETON_SCRATCH_DIR\` environment variable

3.  \`tempdir()\` (the default)

Intermediates are removed by the pipeline as soon as they are consumed;
the directory itself is left in place.

## Examples

``` r
if (FALSE) { # \dontrun{
options(nemeton.scratch_dir = "/mnt/big/scratch")
scratch_dir()
} # }
```
