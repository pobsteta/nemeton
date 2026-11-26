# Default weights of the ICD formula

The starting weights of the composite discoloration indicator (ICD, spec
071), set by expert judgement in the method note (section 7) and meant
to be recalibrated on field observations. One row per species group, one
column per index, plus the sensitive months. CRre is nil for conifers.

## Usage

``` r
icd_poids_defaut()
```

## Value

A \`data.frame\` with columns \`essence\` (\`chene\`, \`hetre\`,
\`sapin_epicea\`, \`douglas\`), \`GRVI\`, \`CIre\`, \`CRSWIR\`,
\`CRre\`, \`NDVI\`, \`mois_debut\` and \`mois_fin\`. Each row sums to 1.

## Details

Only the weights are adjustable (\[run_icd_decoloration()\] argument
\`poids\`); the months and the thresholds stay those of the note.

## See also

\[icd_poids_valider()\], \[run_icd_decoloration()\].

## Examples

``` r
icd_poids_defaut()
#>        essence GRVI CIre CRSWIR CRre NDVI mois_debut mois_fin
#> 1        chene 0.15 0.25   0.15 0.20 0.25          6        8
#> 2        hetre 0.30 0.25   0.15 0.15 0.15          7        8
#> 3 sapin_epicea 0.35 0.15   0.35 0.00 0.15          6       10
#> 4      douglas 0.45 0.15   0.25 0.00 0.15          4        9
```
