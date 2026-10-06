# Ticket amont microclimf — brouillon (NON publié)

> Texte prêt à déposer sur <https://github.com/ilyamaclean/microclimf/issues>
> (le champ `BugReports` du paquet, `http://github.com/microclimf/issues`,
> est lui-même faux — signalé en fin de ticket). Rédigé le 2026-10-06 pour la
> 1.0.0 de nemeton ; **pas publié** : à relire et déposer par Pascal.
>
> Côté nemeton, le contournement reste en place :
> `R/regen_engines.R`, `.rsen_ensure_soildata()` charge `soilparameters` et
> `soilparamsp` dans `globalenv()` le temps du run (retrait en `on.exit`).
> Il pourra être retiré quand une version corrigée de microclimf sera publiée
> (garder alors un plancher de version dans `Suggests`).

---

## Title

`runpointmodel()` fails with "object 'soilparameters' not found" unless microclimf is attached

## Description

Several internal functions refer to the package datasets `soilparameters`
and `soilparamsp` by their bare name:

- `runpointmodel()` (`soilparamsp$rmu[ii]`, `soilparamsp$mult[ii]`, ...)
- `.soilinit()` (`soilparameters$Number`)
- `.sortsoilc()` (`soilparamsp$alpha[sn]`, ...)
- `.togp()` (`soilparameters$Soil.type[sn]`, `soilparameters$rho[sn]`, ...)

These datasets are lazy-loaded data (`LazyData: true`). Lazy data live in the
package's lazydata environment, which is **not** on the lookup path of the
package namespace (namespace -> imports -> base -> global environment ->
search path). They are therefore found only when the package is attached with
`library(microclimf)`, which puts them on the search path. When microclimf is
called with `::` from another package (the normal way: `Imports:` or
`Suggests:` + `requireNamespace()`), or from a script that does not attach it,
the lookup fails.

## Minimal reproducible example

```r
# Fresh R session, microclimf NOT attached
r <- microclimf::runpointmodel(microclimf::climdata, reqhgt = 0.05,
                               microclimf::dtmcaerth, microclimf::vegp,
                               microclimf::soilc)
#> Error: object 'soilparameters' not found

# Same call after attaching: works (about 3 s)
library(microclimf)
r <- runpointmodel(climdata, reqhgt = 0.05, dtmcaerth, vegp, soilc)
```

Environment: microclimf 2.0.0 (GitHub, commit
`d362ad9c4be43ab3241da5e325d1642e214f5cef`), R 4.6.1, Linux x86_64.

## Expected behaviour

Calling the exported functions through `microclimf::` works without attaching
the package, as for any package used from another package's code.

## Suggested fix

Any of the usual ways to reach package data from package code:

1. Qualify the references: `microclimf::soilparameters`,
   `microclimf::soilparamsp` (works with lazy data, even from inside the
   package). This is the smallest change.
2. Or move these two tables to `R/sysdata.rda` (internal data, visible from
   the namespace), keeping the exported copies for users.
3. Or load them locally at the top of the affected functions:
   `utils::data("soilparameters", package = "microclimf", envir = environment())`.

## Current workaround (downstream)

Before calling `runpointmodel()`, copy the two datasets into an environment on
the lookup path, then remove them:

```r
for (ds in c("soilparameters", "soilparamsp")) {
  if (!exists(ds, envir = globalenv(), inherits = FALSE))
    utils::data(list = ds, package = "microclimf", envir = globalenv())
}
# ... microclimf::runpointmodel(...) ...
rm(soilparameters, soilparamsp, envir = globalenv())
```

This works but writes into the user's global environment, which packages
should avoid (CRAN policy), and is fragile if the user has objects with the
same names.

## Side note

The `BugReports` field in `DESCRIPTION` reads `http://github.com/microclimf/issues`,
which does not resolve; it should probably be
`https://github.com/ilyamaclean/microclimf/issues`.
