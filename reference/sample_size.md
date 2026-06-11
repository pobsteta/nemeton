# Sample Size from Target Relative Error and CV

Classic Cochran formula for the number of plots needed to estimate a
mean with a target relative error \\E\\: \$\$n \ge
\left(\frac{t\_{1-\alpha/2, n-1} \cdot CV}{E}\right)^2\$\$

The Student quantile depends on \\n-1\\ degrees of freedom, so the
formula is solved iteratively: start from the normal approximation
(\\z\_{1-\alpha/2}\\), plug back \\t\\ with the updated \\df\\, until
\\n\\ converges (usually 2-4 iterations).

An optional finite-population correction (FPC) is applied when the
population size \\N\\ is provided: \$\$n\_{corr} = \frac{n}{1 + n /
N}\$\$

The target variable is the basal area \\G\\/ha by convention (IFN /
PPtools, Bruciamacchie 2014, GPL-2). Formulas are standard sampling
theory and are not copyrightable; we re-implement them from scratch
without reusing any PPtools source.
