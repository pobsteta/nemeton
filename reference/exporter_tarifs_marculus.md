# Export the Schaeffer tariff tables for Marculus

Copies the three tables Marculus embeds (`tarifs-ifn/` of its assets)
and writes a `LISEZMOI.txt` with the IFN vintage, the date, the IGN
citation (Licence Ouverte Etalab 2.0) and the method credit:

- `ifn_tarif_schaeffer_ser.csv`
  (`niveau;code;espar;essence_libelle;type;numero;n_arbres;cv;millesime`);

- `communes_ser.csv` (`insee;nom;departement;ser;part;greco`);

- `ser.csv` (`code;nom;greco`).

UTF-8 without BOM, `;` separator, empty field for a missing value. The
same tables feed
[`ifn_tarif_schaeffer_reference`](https://pobsteta.github.io/nemeton/reference/ifn_tarif_schaeffer_reference.md):
one chain, one vintage.

## Usage

``` r
exporter_tarifs_marculus(dossier)
```

## Arguments

- dossier:

  Destination directory (created).

## Value

The paths of the written files (invisibly).

## Lifecycle

Experimental (spec 062).
