# Spec 063 — Contexte climatique estival sur un cercle autour du projet (E-OBS, CHELSA, SAFRAN, nuages annuels)

> Brief `nemetonshiny` du 2026-10-18 (`briefs/vers-nemeton/2026-10-18-contexte-climatique-cercle-projet.md`),
> sur demande de Pascal. Source : scripts de Pascal `carte_bivariee_tmax_precip.zip`
> (`carte_bivariee_tmax_precip_safran.R`, `figure1_IF49.R`, `nuages_bfc_chelsa_safran.R`).
> Décisions validées par Pascal le 2026-10-18 : § *Décisions*.

## Pourquoi

La carte « Contexte régional (E-OBS) » de l'onglet reGénération (chaîne
`load_eobs_source()` → `eobs_downscale(engine = "ked", statistic = "trend")` →
`eobs_downscale_bivariate()`) est fausse pour cinq raisons (brief § 1) :
période de 12 ans, downscaling KED des précipitations sur le relief, unité
« par décennie » aux bornes arbitraires, saison juin-août, palette 5 × 5.
On change de méthode : celle des scripts, appliquée à un **cercle de
`rayon_km` autour du centroïde du projet**.

## Méthode (reprise des scripts)

1. Mensualisation : Tmax = moyenne mensuelle, précipitations = cumul,
   `na.rm = FALSE`.
2. Saison `mois` (défaut `5:9`) : Tmax = moyenne des mois, précipitations =
   cumul ; seules les années dont tous les mois sont présents.
3. Tendance par pixel = pente MCO × (an_max − an_min) : **variation totale**
   (°C, mm). NA si moins de 80 % d'années valides.
4. Périodes : `"complete"`, `"if49"` (2006-2020), `c(debut, fin)`.
5. Classification bivariée : chaque axe écrêté aux bornes puis découpé en `n`
   classes ; palette 10 × 10 relevée sur la Figure 1 (défaut) ou interpolation
   des 4 coins (`n` libre).
6. Rendu à la **résolution native** (E-OBS 0,1°, CHELSA 30″, SAFRAN 8 km),
   mailles touchant le cercle gardées entières (`touches = TRUE`), aucun
   rééchantillonnage.

## API livrée (`R/climat_cercle.R`, toutes `experimental`)

| Fonction | Rôle |
|---|---|
| `climat_ete_series(aoi, source, rayon_km = 25, mois = 5:9, annees, cache_dir, eobs_cache_dir, version = "33.0e", progress_callback)` | séries estivales par année sur le cercle → `list(tx, rr, cercle, meta)` |
| `climat_tendance_bivariee(series, periode, bornes, palette, n = 10, cache_path)` | carte bivariée → `list(raster, tendances, meta)` |
| `climat_nuages_annuels(series, mode, reference = 1981:2010, recul_min = 10, n_points = 4000, seed = 1)` | nuages annuels → `list(points, moyennes, limites, meta)` |

`meta$status` ∈ `ok`, `hors_couverture`, `indisponible`,
`donnees_insuffisantes` (+ `reason`, `message`) : aucune erreur réseau ne
remonte. Étapes de progression : `climat:cache_hit`, `climat:telechargement`,
`climat:mensualisation`, `climat:annee` (`annee`, `i`, `n`), `climat:complete`,
`climat:indisponible`.

Convention de classe identique à `eobs_downscale_bivariate()` :
`(ct - 1) * n + cp`, `ct` = 1 (moindre hausse de Tmax) … `n`, `cp` = 1 (plus
sec) … `n` ; « chaud et sec » = `(n - 1) * n + 1` ;
`meta$palette$colors[classe]`, `meta$palette$ncol = n`,
`meta$palette$zero` pour les pointillés 0/0.

Caches :

- E-OBS : **cache machine** `get_global_cache_dir()/eobs/` (le même que le
  cache CDS de `load_eobs_source()` ; `NEMETON_CACHE_DIR` le déplace) : fichiers
  KNMI `{tx,rr}_ens_mean_0.1deg_reg_v33.0e.nc` (5,0 et 3,2 Go, vérifié le
  2026-10-18), agrégés **une fois**, année par année, en
  `eobs_{tx,rr}_mensuel_france_v33.0e.tif` ; repli CDS si KNMI échoue.
- CHELSA / SAFRAN : `cache_dir/climat/<source>/<clé>/` (mois / étés bruts).
- Séries : `cache_dir/climat/<clé>_{tx,rr}.tif` + `<clé>.meta.json` ; carte :
  `cache_path` + `_tendances.tif` + `.meta.json`. La clé encode source, rayon,
  mois et centre du cercle.

## Écarts aux scripts et au brief

- **Bornes « france » calculées sur E-OBS pour toutes les sources.** Le brief
  demande des bornes France « pour la source et la période ». Pour CHELSA et
  SAFRAN, cela imposerait de télécharger la France entière (≈ 430 COG
  mondiaux, ≈ 335 requêtes SAFRAN France) au premier usage. Les bornes sont
  donc les quantiles 1/99 % (étendus à 0) des variations E-OBS sur la France
  métropolitaine, **pour les mêmes années et les mêmes mois** que la série.
  Bénéfice : mêmes couleurs entre sources. Les valeurs extrêmes de CHELSA
  1 km sont écrêtées. Le contour France est l'union des SER INRAE (WFS
  `inrae:ser_l93`, mise en cache dans le cache E-OBS) ; à défaut, l'emprise
  de l'agrégat (`meta$bornes$reference = "eobs_emprise_france"`).
  `climat_tendance_bivariee()` ne télécharge rien : sans agrégat E-OBS en
  cache, repli sur `"emprise"` avec `meta$bornes$reason =
  "france_eobs_cache_missing"`. **Validé par Pascal le 2026-10-18.**
- Moyenne annuelle des nuages calculée sur **toutes** les mailles du cercle
  (le script la calcule sur l'échantillon) — identique dès que le cercle
  compte moins de `n_points` mailles (cas E-OBS et SAFRAN).
- E-OBS : le centre du cercle doit tomber dans l'emprise de l'agrégat France
  (−5,5° à 10° E, 41° à 51,5° N), sinon `hors_couverture`.

## Validation

- Tests synthétiques sans réseau (`tests/testthat/test-climat-cercle.R`,
  82 assertions) : variation totale d'une pente connue, été incomplet écarté,
  mois NA, règle des 80 %, coins des deux palettes, bornes `if49` / `emprise`
  / `france` / explicites, cache disque, nuages (référence manquante, recul,
  graine), SAFRAN et CHELSA mockés, mensualisation E-OBS d'un quotidien daté.
- Smoke réel (2026-10-18, cercle de 25 km près de Dijon) : SAFRAN 2021-2022 =
  7 × 7 mailles EPSG:2154 en 16 s (Tmax mai-sept. 20,8 / 24,2 °C ; cumul
  431 / 308 mm) ; CHELSA 2019-2020 = 55 × 80 px EPSG:4326 en 11 s (Tmax
  23,8 / 23,5 °C) ; HEAD KNMI v33.0e = 200 pour `tx` et `rr`.
- **Chaîne E-OBS réelle** (2026-10-18, même cercle, sur accord de Pascal,
  scope plafonné à 12 Go) : 29,5 min au total — téléchargement KNMI tx
  (5,0 Go) 14 min et rr (3,2 Go) 10 min, mensualisation France ≈ 2,5 min par
  variable (76 années), puis 19 s pour la première carte (bornes France
  calculées et mises en cache) et 0,2 s pour la suivante. Cache machine :
  `eobs_{tx,rr}_mensuel_france_v33.0e.tif` = 43 + 27 Mo,
  `france_metropole_ser.gpkg`, JSON des bornes. Cercle : 5 × 8 mailles 0,1°,
  34 valides, 1950-2025 (76 étés).
  - Période complète 1950-2025 : ΔT°max mai-sept. = +2,7 °C (2,3 à 3,2),
    ΔP = −15 mm (−48 à −4) ; bornes France ΔT [0 ; 5,06] °C, ΔP [−111 ;
    134] mm (bornes du cercle seul : [0 ; 3,17] et [−45 ; 0]).
  - 2006-2020 (L'IF n° 49) : ΔT = +2,4 °C, ΔP = −176 mm, classes 53 à 74
    (orangés à rouges : réchauffement fort et assèchement, comme la Bourgogne
    sur la Figure 1).
  - Nuages : anomalie 2022 = +3,2 °C / −71 mm ; tendance cumulée 1959-2025.

## Hors périmètre

- `analyse_bdiff.R` (exports BDIFF manuels), `incendies_2026_effis_format_bdiff.R`
  (EFFIS, plutôt R1) : brief séparé si Pascal le veut.
- Dépréciation de `eobs_downscale*()` et `tendances_estivales_eobs()` pour la
  carte de contexte : **à proposer à Pascal**, rien n'est retiré.

## Décisions (Pascal, 2026-10-18)

1. Saison par défaut `mois = 5:9`.
2. Bornes de la période complète et des périodes libres : France
   métropolitaine (`"france"`), `"emprise"` en option.
3. E-OBS : cache machine partagé alimenté par KNMI v33.0e, CDS en repli.
4. Centre du cercle : centroïde du projet.
5. Bornes « france » tirées d'E-OBS France pour toutes les sources (mêmes
   années et mois) — validé après coup, 2026-10-18.
