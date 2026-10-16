# Reconcile provisional and definitive trees of one plot

Matches the provisional trees (phone, layer `arbres`) with the
definitive detections of the Groma server, for \*\*one\*\* plot, by an
optimal assignment (Hungarian method) on the horizontal position. Pairs
farther than `tolerance_m` are forbidden; the cost is the distance plus
`poids_dbh_m_par_cm` per cm of diameter difference, which breaks ties
between close candidates (a greedy match would lose trees).

## Usage

``` r
rapprocher_arbres(
  provisoires,
  definitifs,
  centre,
  convergence_deg = 0,
  tolerance_m = 0.5,
  rayon_m = 20,
  seuil_diam_cm = 7.5,
  unite_azimut = c("deg", "gr"),
  tolerance_deg = 1,
  poids_dbh_m_par_cm = 0.01,
  ecart_dbh_alerte_cm = 10,
  ecart_dbh_alerte_rel = 0.5,
  generer_uuid = .uuid_v4
)
```

## Arguments

- provisoires:

  sf POINT, or data.frame with `x`, `y` (Lambert-93): rows of the
  `arbres` layer of the plot (`uuid`, `dbh_cm`, `tree_id` and field
  attributes).

- definitifs:

  sf POINT, or data.frame with `x`, `y`: definitive detections
  (`dbh_cm`, optional `h_m`, `h_source`, `houppier_id`, `methode`).

- centre:

  Numeric `c(x, y)`: measured plot centre (Lambert-93). Or the
  `centres_mesures` rows of the plot (sf POINT, or data.frame with `x`,
  `y`): Groma adds a row at each measurement and never rewrites one, so
  the most recent (largest `fid`, else last row) is used.

- convergence_deg:

  Meridian convergence at the plot (degrees).

- tolerance_m:

  Maximal matching distance (m). Default 0.5.

- rayon_m, seuil_diam_cm, unite_azimut, tolerance_deg:

  Numbering parameters, see
  [`numeroter_arbres`](https://pobsteta.github.io/nemeton/reference/numeroter_arbres.md).

- poids_dbh_m_par_cm:

  Cost of 1 cm of diameter gap, in metres. Default 0.01.

- ecart_dbh_alerte_cm, ecart_dbh_alerte_rel:

  Diameter gap alert thresholds. Defaults 10 cm and 0.5.

- generer_uuid:

  Function returning a new uuid (for the new trees).

## Value

A list with `arbres` (same class as `provisoires`), `apparies`
(data.frame `uuid`, `definitif` = row of `definitifs`, `distance_m`),
`nouveaux` and `non_retrouves` (uuids), `numeros_modifies` (data.frame
`uuid`, `ancien`, `nouveau`) and `alertes` (data.frame `uuid`, `motif`,
`dbh_provisoire`, `dbh_definitif`).

## Details

- Matched: field attributes kept (`essence_arbre`, `espece`, `statut`,
  `qualite`, `notes`, `photos`, measured `h_m`); position, `dbh_cm`,
  `methode` and CHM height updated; `definitif` if `essence_arbre` is
  filled in, else `a_completer`. A `faux_positif` stays so (alert
  `faux_positif_retrouve`). Alert `ecart_dbh` when the diameter gap
  exceeds `ecart_dbh_alerte_cm` *and* `ecart_dbh_alerte_rel` of the
  smaller diameter.

- New (definitive without provisional): new `uuid`, `statut = "vivant"`,
  `a_completer`.

- Provisional not found: `a_verifier`, attributes and position kept.

- Numbering recomputed with
  [`numeroter_arbres`](https://pobsteta.github.io/nemeton/reference/numeroter_arbres.md)
  on the trees that are neither `a_verifier` nor `faux_positif`; the
  former number goes to `num_provisoire`. `a_verifier` trees get
  `V1, V2...`, `faux_positif` trees `F1, F2...` (by azimuth), so
  `tree_id` stays unique and non-empty.

- A tree that leaves the inventory once measured (outside the radius or
  under the threshold) is kept as `a_verifier` when it carries field
  attributes or was provisional, and dropped otherwise.

No field attribute is ever lost.

## Lifecycle

Experimental (spec 061).

## Examples

``` r
prov <- data.frame(uuid = c("u1", "u2"), plot_id = "P1", tree_id = c("1", "2"),
                   dbh_cm = c(30, 25), essence_arbre = c("hetre", NA),
                   etat_detection = "provisoire",
                   x = c(1000, 1003), y = c(2005, 2004))
def <- data.frame(x = c(1000.2, 1003.1), y = c(2005, 2004), dbh_cm = c(31, 24),
                  methode = "classique")
rapprocher_arbres(prov, def, centre = c(1000, 2000))$arbres
#>   uuid plot_id tree_id dbh_cm essence_arbre etat_detection      x    y
#> 1   u1      P1       1     31         hetre      definitif 1000.2 2005
#> 2   u2      P1       2     24          <NA>    a_completer 1003.1 2004
#>   num_provisoire   methode h_m h_source houppier_id statut distance_m  azimut
#> 1              1 classique  NA     <NA>          NA   <NA>      5.004  2.2906
#> 2              2 classique  NA     <NA>          NA   <NA>      5.061 37.7757
```
