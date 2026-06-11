# Reconstruct the FORDEAD harmonic prediction for a pixel

Computes \`crswir_pred\` for every observation date from the five
per-pixel harmonic coefficients. Per ADR-013 amendment A3 decision D3,
the harmonic basis itself is \*\*not\*\* re-implemented in R: the 5-term
basis comes from \`fordead.modeling.compute_HarmonicTerms\` via
reticulate, guaranteeing parity with the run. Only \`dates_to_days\` (a
plain subtraction from \`REF_DAY = 2015-01-01\`) is done R-side.

## Usage

``` r
.fordead_harmonic_predict(coeff, obs_date, env_name = .fordead_default_env())
```

## Arguments

- coeff:

  Numeric(5). Per-pixel harmonic coefficients.

- obs_date:

  A \`Date\` vector. Observation dates to predict.

- env_name:

  Character. FORDEAD virtualenv name.

## Value

Numeric vector of predictions (length \`length(obs_date)\`), or \`NULL\`
when the Python side is unavailable.

## Details

Returns \`NULL\` (with a warning) when the FORDEAD virtualenv or the
\`fordead\` Python package is unavailable - the caller then degrades
gracefully (the residual risk accepted in ADR-013 A3).
