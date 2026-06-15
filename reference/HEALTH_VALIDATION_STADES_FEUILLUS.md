# DSF DEPERIS broadleaf dieback stages (RECONFORT, spec 021 G4)

Terrain-validation vocabulary for the RECONFORT method (oak / chestnut /
Scots pine), the broadleaf counterpart of
[`HEALTH_VALIDATION_STADES`](https://pobsteta.github.io/nemeton/reference/HEALTH_VALIDATION_STADES.md).
Graded on the DSF **DEPERIS** protocol (Nageleisen / Département de la
Santé des Forêts), whose two permanent symptomatological criteria on
broadleaves are **mortalité de branches (MB)** and **manque de
ramification (MR)**, combined into an overall crown-damage percentage.
Severity bands map onto the DEPERIS A–F notation, the **\> 50 % crown
damage** threshold (DEPERIS D/E/F) separating "marqué"/"grave" from
"faible":

- \`sain\` — DEPERIS A (no significant damage).

- \`deperissement_faible\` — DEPERIS B–C (crown damage ≤ 50 %).

- \`deperissement_marque\` — DEPERIS D (crown damage \> 50 %).

- \`deperissement_grave\` — DEPERIS E–F (severe, crown dieback).

- \`mort\` — dead tree.

- \`coupe_rase\` — clearcut (not progressive dieback).

The exact A–F percentage cut-offs follow the DSF DEPERIS field guide.

## Usage

``` r
HEALTH_VALIDATION_STADES_FEUILLUS
```
