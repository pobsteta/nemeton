# Brief nemetonshiny — Affichage & calcul de B4 / L3 (diversité spectrale)

**Cœur requis :** `nemeton (>= 0.110.0)` (indicateurs + primitive
`compute_spectral_diversity()`, GPL-3).
**Contexte :** spec 028. B4 (α/Shannon) et L3 (β/Bray-Curtis) via biodivMapR,
calculables au NDP 0 (Sentinel-2). Sens *haut = mieux*, bornes de normalisation
**provisoires** (recalibrage après premier run réel).

> **TL;DR** : l'affichage est **quasi gratuit** (radar + vue famille sont
> *config-driven* et lisent `nemeton::get_family_config()`, déjà à jour B4/L3
> avec labels/tooltips FR/EN). Le vrai travail est le **calcul** : ces deux
> indicateurs ont besoin d'un **cube réflectance Sentinel-2** que le service de
> calcul standard n'a pas dans ses `layers` — il faut l'assembler et l'injecter.

---

## Partie 1 — Activer B4/L3 dans la liste de calcul (rapide)

`R/service_compute.R` → `list_available_indicators()` est **hardcodé** et ne
liste ni B4 ni L3. Ajouter :

```r
    # Biodiversity (B)
    "indicateur_b1_protection", "indicateur_b2_structure",
    "indicateur_b3_connectivite", "indicateur_b4_div_spectrale",
    ...
    # Landscape (L)
    "indicateur_l2_fragmentation", "indicateur_l1_sylvosphere",
    "indicateur_l3_het_spectrale",
```

> ⚠️ Si tu n'implémentes pas encore la Partie 3 (cube S2), B4/L3 seront
> **calculés mais NA** (les fonctions cœur renvoient `NA` sans `spectral`/
> `reflectance` — rétrocompatibles). Affichage OK (cases grisées), pas de
> plantage. Tu peux donc livrer la Partie 1 seule d'abord.

## Partie 2 — Assembler le cube réflectance Sentinel-2

biodivMapR veut un raster **multi-bandes de réflectance** (pas un simple NDVI).
Les bandes S2 sont déjà en cache COG (pipeline FAST/RECONFORT). Réutiliser les
lecteurs cœur (spec 010) plutôt que de réacquérir :

```r
# bandes utiles biodivMapR / Sentinel-2 (10–20 m), ordre spectral :
bands <- c("B02","B03","B04","B05","B06","B07","B08","B8A","B11","B12")
refl  <- nemeton::read_s2_band_stack(<cache_s2>, bands = bands, aoi = <aoi>)
# `refl` = SpatRaster multi-bandes, EPSG:2154, découpé sur l'AOI.
```

- Source du cache : le même que FAST/RECONFORT (voir `service_monitoring.R` /
  `mod_monitoring*`). Prendre **une** scène estivale peu nuageuse (juin–sept),
  ou un composite médian si dispo.
- Masque : passer le **masque forêt/UGF** (`mask =`) pour ne calculer la
  diversité que sur le couvert (sinon PCA polluée par le bâti/agri).

## Partie 3 — Calculer la diversité une seule fois, injecter dans B4 & L3

B4/L3 partagent la **même** primitive : la lancer **une fois** et passer le
résultat en `spectral =` aux deux (biodivMapR est coûteux). Le loop générique
`compute_single_indicator()` résout les args par nom (`dem`, `ndvi`, `chm`…) et
ne connaît pas `spectral`/`reflectance` → **wiring dédié**, sur le modèle de
`CHM_REQUIRED_INDICATORS` :

```r
SPECTRAL_INDICATORS <- c("indicateur_b4_div_spectrale",
                         "indicateur_l3_het_spectrale")

# --- pré-étape, avant/pendant la boucle de calcul ---
spectral <- NULL
if (length(intersect(SPECTRAL_INDICATORS, indicators_to_compute)) > 0) {
  refl <- tryCatch(build_reflectance_stack(layers, aoi), error = function(e) NULL)
  if (!is.null(refl)) {
    spectral <- nemeton::compute_spectral_diversity(
      reflectance = refl,
      mask        = forest_mask,      # masque UGF/forêt
      window_size = 10L,              # spec 028 D2 (~100 m)
      nb_cpu      = getOption("nemeton.biodivmapr_cpu", 1L)
    )
  } else {
    # pas de scène S2 exploitable -> message i18n, B4/L3 restent NA
  }
}

# --- dans la boucle, court-circuiter le dispatch générique pour B4/L3 ---
if (indicator == "indicateur_b4_div_spectrale") {
  return(nemeton::extract_indicator_value(
    nemeton::indicateur_b4_div_spectrale(parcels, spectral = spectral),
    indicator, exclude = names(parcels)))
}
if (indicator == "indicateur_l3_het_spectrale") {
  return(nemeton::extract_indicator_value(
    nemeton::indicateur_l3_het_spectrale(parcels, spectral = spectral),
    indicator, exclude = names(parcels)))
}
```

Notes :
- **Un seul** appel `compute_spectral_diversity()` pour les deux indicateurs.
- `spectral = NULL` (pas de scène) → les deux renvoient `NA` proprement.
- Coût CPU/temps notable (PCA + k-means sur la scène) → passe par
  l'`ExtendedTask`/`future` déjà en place ; exposer `nb_cpu` en option.
- biodivMapR écrit des rasters temporaires (`output_dir`) → prévoir le nettoyage
  (`tempdir()` par défaut convient).

## Partie 4 — Affichage (quasi rien à faire)

- **Vue famille** (`mod_family.R`) : itère sur
  `get_family_config(code)$indicators` / `$column_names` → B4 (famille B) et L3
  (famille L) apparaissent **automatiquement** dès qu'ils sont dans les
  résultats. Labels + tooltips FR/EN viennent du **cœur** (déjà renseignés,
  avec le caveat « proxy à valider terrain »).
- **Radar** (`mod_synthesis.R`) : idem si le radar est construit depuis la
  config famille. **À vérifier** : nb d'axes B (3→4) et L (2→3) — s'assurer que
  le radar ne suppose pas un compte fixe.
- **Normalisation** : `nemeton::normalize_indicator()` gère B4/L3 (haut=mieux).
  Rien à faire côté app.
- **i18n** : aucun nouveau littéral requis si les libellés proviennent de la
  config cœur. Vérifier qu'aucun texte n'est codé en dur pour les axes.

## Partie 5 — Dépendance & relicence

- **DESCRIPTION app** : bumper `Imports: nemeton (>= 0.110.0)`.
- **Install** : nemeton 0.110.0 tire **biodivMapR** (arbre lourd : caret/mlr/
  prosail/Rfast…). Prévoir dans l'image Docker / l'environnement de déploiement
  (compilation longue ; en CI privilégier des binaires).
- **Relicence** : nemetonshiny importe désormais du **GPL-3** → basculer son
  `LICENSE`/`DESCRIPTION` en **GPL-3** (cohérence copyleft).

## Partie 6 — Après le premier run réel (boucle avec le cœur)

Le premier calcul réel sur une scène Sentinel-2 donne la distribution effective
de B4 (Shannon) et de la sortie β de biodivMapR. **Remonter ces plages** pour
que je **recalibre les bornes de normalisation** côté cœur (spec 028 D3 —
actuellement B4 `[0, log 50]`, L3 `[0, 1]` provisoires).

## Ordre de livraison conseillé

1. **P1 + P4** (liste + affichage) → B4/L3 visibles en *NA* (livrable immédiat,
   zéro risque).
2. **P2 + P3** (cube S2 + calcul) → valeurs réelles.
3. **P5** (dep + relicence).
4. **P6** → recalibrage cœur.
