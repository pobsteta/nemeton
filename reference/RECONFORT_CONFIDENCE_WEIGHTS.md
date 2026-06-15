# Provisional RECONFORT confidence weights (garde-fou G1)

Per-class trustworthiness coefficients used to weight the R5
dépérissement indicator (spec 021 §5/G1), the RECONFORT analogue of
[`FORDEAD_CONFIDENCE_WEIGHTS`](https://pobsteta.github.io/nemeton/reference/FORDEAD_CONFIDENCE_WEIGHTS.md).
The healthy class (\`1-sain\`) raises no alert; the dieback classes are
the ones that propagate.

**PROVISIONAL — NOT YET CALIBRATED.** spec 021 §5/G1 prescribes that
these weights be documented from the RECONFORT confusion matrix (Mouret
et al. 2023, IEEE J-STARS). That matrix is not transcribed here yet: the
values are conservative placeholders and must be replaced by the
upstream-validated figures before the R5 indicator (L4) relies on them
quantitatively.

## Usage

``` r
RECONFORT_CONFIDENCE_WEIGHTS
```
