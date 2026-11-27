# Sentinel-2 source of a health-monitoring method

Resolves which Sentinel-2 reflectance source a method uses, and whether
that source is the one the method was calibrated on. Each method keeps
its own default (\`NULL\`): RECONFORT is calibrated on MAJA reflectances
(\`"theia"\`), FAST, FORDEAD and the ICD on Sen2Cor (\`"sen2cor"\`)
(studies 092 and 093 of the platform). A project-wide choice
(\`"theia"\` or \`"sen2cor"\`) applies to the four methods.

## Usage

``` r
s2_source_resoudre(
  methode = c("reconfort", "fast", "fordead", "icd"),
  source_s2 = NULL
)
```

## Arguments

- methode:

  One of \`"reconfort"\`, \`"fast"\`, \`"fordead"\`, \`"icd"\`.

- source_s2:

  \`NULL\` (the method's default), \`"theia"\` (MAJA, THEIA STAC
  catalogue) or \`"sen2cor"\` (Planetary Computer).

## Value

A list: \`source_s2\` (the source to use), \`defaut\` (the method's
default source), \`calee_sur\` (the source the method is calibrated on),
\`mention\` (a short note when the method runs off its calibration
source, \`NA\` otherwise). Comparing \`calee_sur\` with \`source_s2\`
tells whether the run is indicative.

## Examples

``` r
s2_source_resoudre("fast")
#> $source_s2
#> [1] "sen2cor"
#> 
#> $defaut
#> [1] "sen2cor"
#> 
#> $calee_sur
#> [1] "sen2cor"
#> 
#> $mention
#> [1] NA
#> 
s2_source_resoudre("fast", "theia")$mention
#> [1] "FAST is calibrated on sen2cor but ran on theia: thresholds to be revisited (platform studies 092 and 093), indicative only"
```
