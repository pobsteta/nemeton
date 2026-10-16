# Schaeffer tariff number of a tree, and volume of a tariff

One-entry Schaeffer tariffs (fast `SCHR`, intermediate `SCHI`, slow
`SCHL`, very slow `SCHTL`), with the conventions of
`PPtools::TarifFindSch()` and of Marculus (`M = 0.8 + 0.1 N`):

- `SCHR`: \\V = (N + 8) (D - 5)(D - 10) / 14000\\;

- `SCHI`: \\V = (N + 8) (D - 2.5)(D - 7.5) / 16000\\;

- `SCHL`: \\V = (N + 8) D (D - 5) / 18000\\;

- `SCHTL`: \\V = (N + 8) D^2 / 20250\\.

`numero_tarif_schaeffer()` inverts them: the number that gives a tree of
diameter `D` its volume `V`.

## Usage

``` r
numero_tarif_schaeffer(volume_m3, diametre_cm, type)

volume_tarif_schaeffer(numero, diametre_cm, type)
```

## Arguments

- volume_m3:

  Numeric. Merchantable stem volume (m3, IFN `V`).

- diametre_cm:

  Numeric. Diameter at 1.30 m (cm).

- type:

  Character, one of `"SCHR"`, `"SCHI"`, `"SCHL"`, `"SCHTL"` (recycled).

- numero:

  Numeric. Tariff number.

## Value

Numeric vector: the number (`numero_tarif_schaeffer`) or the volume in
m3 (`volume_tarif_schaeffer`), `NA` where the formula is undefined.

## Lifecycle

Experimental (spec 062).

## Examples

``` r
numero_tarif_schaeffer(1.2, 40, "SCHL")
#> [1] 7.428571
volume_tarif_schaeffer(10, 40, "SCHL")
#> [1] 1.4
```
