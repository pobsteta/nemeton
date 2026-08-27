# Note de cadrage — package amont `biophysnemeton`

> Deliverable C de `specs/brief-instance-nemeton.md`. Cadrage de périmètre, pas
> d'implémentation. Nom provisoire `biophysnemeton` ; patron `opencanopy`
> (ADR-009).

## 1. Raison d'être

SL2P (Weiss & Baret) transforme des réflectances Sentinel-2 L2A en quatre
rasters biophysiques (LAI, fAPAR, FCOVER, CCC). Ce traitement — acquisition S2,
application du perceptron par plateforme, assainissement, composite temporel —
est **de la production de donnée amont**, pas du calcul d'indicateur. L'ADR-009
impose : les dépendances vont **vers** le cœur `nemeton`, jamais l'inverse. Donc
un package séparé, comme `opencanopy` produit les CHM que nemeton consomme
via `chm=`.

## 2. Frontière exacte avec `nemeton`

| | `biophysnemeton` (amont) | `nemeton` (cœur) |
|---|---|---|
| Acquisition S2 L2A | **oui** | non |
| Perceptron SL2P (poids par plateforme) | **oui** | non |
| Assainissement (masques nuage/ombre, hors-domaine) | **oui** | non |
| Composite temporel juin-août, médiane | **oui** (produit le raster) | non |
| Correction de biais forêt (table LAI) | **à trancher — cf. §5** | ou ici |
| Gating (`n_obs`, masquage, flags, surface) | fournit les **métriques** | **décide** (pose `augmented`) |
| Consommation par les indicateurs | non | **oui** (args `lai=`, `fapar=`, `fcover=`, `ccc=`) |
| Anomalie CCC / r3 (ligne de base ≥ 5 ans) | fournit la **série** | **calcule** l'anomalie |

**Règle de partage** : `biophysnemeton` produit des **rasters + métriques de
qualité** ; `nemeton` **décide** (gating, anomalie, correction) et **consomme**.
La frontière suit celle de `sanitize_chm()` (nemeton assainit un CHM produit par
`opencanopy`) — mais ici l'assainissement SL2P (masques, hors-domaine) est
intrinsèque au traitement et reste **amont**.

> **HYPOTHÈSE :** le gating reste **côté nemeton** (il pose `augmented`, qui est
> un concept NDP/cœur), tandis que `biophysnemeton` ne fait que **remonter les
> métriques** (`n_obs`, `pct_masked`, part hors-domaine SL2P). Sinon la décision
> de confiance fuiterait hors du cœur, contre l'ADR-011.

## 3. Interface publique proposée

Minimale, sur le modèle `opencanopy` :

```r
# Production : AOI + période -> stack des 4 variables + métriques de qualité.
biophys_sl2p(aoi, start, end, platform_routing = TRUE,
             sensor_auxdata = <table poids par plateforme>,
             cache_dir = ...)
  -> list(
       lai, fapar, fcover, ccc,     # SpatRaster composites (médiane, fenêtre)
       n_obs,                       # SpatRaster : obs valides par pixel
       pct_masked,                  # SpatRaster : taux de masquage
       sl2p_flags,                  # SpatRaster : hors-domaine entrées/sorties
       platform,                    # provenance par scène (S2A/S2B/...)
       window                       # fenêtre appliquée (depuis la table, D4)
     )

# Assainissement séparé (si besoin d'un point d'entrée testable) :
biophys_sanitize(refl, masks, ...) -> refl_clean
```

`nemeton` n'appelle **rien** de cela directement : l'app ou l'utilisateur produit
les rasters via `biophysnemeton`, puis les passe aux indicateurs. Découplage total
(ADR-009), comme `chm`.

## 4. Coefficients SL2P — donnée sourcée, versionnée

Les poids du perceptron sont extraits des **auxdata du toolbox Sentinel-2**,
**distincts par plateforme**. Ils vivent dans `biophysnemeton/inst/extdata/`,
**une table par plateforme**, sourcée (version du toolbox, date d'extraction),
sur le modèle `site_index_curves.csv` + `inst/NOTICE`. **Jamais de poids inventé
ni de repli inter-plateforme.** Le test golden 1e-4 (spec 043 §9) valide leur
transcription.

## 5. Arbitrage : accès aux données Sentinel-2

Le brief demande d'arbitrer **`theia2r` contre accès STAC direct**.

**Constat sur le code réel de `nemeton`** : il n'utilise **pas** `theia2r`. Il a
un pipeline STAC maison (`R/theia_stac.R`, source `theia_stac`
= `api.stac.teledetection.fr`), avec signature S3 SigV4 des COG THEIA/MUSCATE
(spec 029). C'est ce pipeline qui alimente déjà `lai_sentinel2()` (spec 033).

**Recommandation : accès STAC direct, en réutilisant le pipeline THEIA existant**,
pas `theia2r`.

*Justification.*
1. **Cohérence** : `nemeton` acquiert déjà S2 par STAC/THEIA maison ; introduire
   `theia2r` dans `biophysnemeton` ferait deux voies d'accès S2 dans le même
   écosystème, à maintenir en parallèle.
2. **Robustesse aux abandons** : la session a vu trois dépendances R lâcher en
   deux jours (lidR/rlas archivés CRAN, dissUtils archivé, Rfast/TBB). Un
   wrapper tiers de plus est un point de rupture de plus ; le STAC direct
   (`httr2` + GDAL `/vsicurl/`) ne dépend que de briques stables.
3. **Contrôle de la signature** : les assets THEIA/MUSCATE exigent une signature
   (gateway teledetection) déjà implémentée côté nemeton (`theia_sign_urls`).
   `theia2r` devrait la ré-implémenter ou l'ignorer.

*Réserve.* Si `biophysnemeton` doit rester **strictement indépendant** de nemeton
(ADR-009 : dépendances vers le cœur, jamais l'inverse — donc `biophysnemeton` ne
peut pas importer `nemeton`), alors le code de signature/STAC doit être **dupliqué
ou extrait** dans une brique commune. À trancher :
- **(a)** dupliquer le peu de code STAC/signature dans `biophysnemeton`
  (indépendance stricte, un peu de redite) ;
- **(b)** extraire un micro-package `theiastacnemeton` partagé (propre, une
  dépendance de plus).
> **HYPOTHÈSE :** (a) au démarrage (le code de signature est court), (b) si un
> troisième consommateur apparaît. Ne pas introduire `theia2r`.

## 6. Ce que cette note ne tranche pas

- Q2 (spec 043) : CCC sortie directe de SL2P ou composé — **à vérifier dans les
  auxdata SNAP** avant de figer l'interface (le `ccc` du retour §3 suppose une
  sortie directe).
- La localisation de la correction de biais forêt (amont vs cœur, §2) — dépend de
  si elle est « donnée » (table, plutôt cœur avec les autres tables de référence)
  ou « traitement » (plutôt amont). **Recommandation faible : côté cœur**, avec
  les autres tables sourcées (`site_index_curves.csv`, `european_species_…`), car
  c'est une correction *métier* indexée essence×région, pas un traitement optique.
