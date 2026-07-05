# Brief `nemetonshiny` — câbler le bilan hydrique BILJOU réel (option B, spec 027 L2)

**Cœur requis** : `nemeton (>= 0.132.0)`.
**Objectif** : rendre le **bilan hydrique réel** (`regen_bilan_hydrique()`, chemin
moteur) lançable depuis l'onglet reGénération, **symétrique de l'option B
microclimf déjà livrée**. Le cœur expose désormais l'acquisition météo/sol —
l'app orchestre/cache seulement (règles #1/#3).

---

## 1. Contrat cœur (nemeton >= 0.132.0)

```r
# meteo journalier format biljouR (date/doy/pet/rain), liste nommée par unité
# (ids alignés sur les points internes de regen_bilan_hydrique).
meteo <- nemeton::load_biljou_forcing(
  aoi = units, years = c(cfg$year_moyenne, cfg$year_canicule),
  source = cfg$forcing,                    # "safran" (défaut, FR) | "era5"
  cache_dir = file.path(project_path, "cache", "regeneration", "biljou"))

# sol = objet biljou_soil (réserve utile ewm ; défaut 150 mm).
sol <- nemeton::build_biljou_soil(units, ewm = cfg$ewm)

# run : lai_max + type + phénologie (forwarded à biljou_run_grid via `...`).
res <- nemeton::regen_bilan_hydrique(
  units, meteo = meteo, sol = sol,
  lai_max = cfg$lai_max, forest_type = cfg$forest_type,
  years = c(cfg$year_moyenne, cfg$year_canicule),
  budburst = cfg$budburst, leaf_fall = cfg$leaf_fall)
# -> colonnes par unité : njstress, istress, rew_min, deb_stress
```

**`load_biljou_forcing()` / `build_biljou_soil()` dégradent en `NULL`** (pas de
`biljouR`, pas de clé CDS pour ERA5, réseau KO, hors couverture). Traiter `NULL`
comme aujourd'hui (garde → message i18n / saisie manuelle), ne pas planter.

## 2. Câblage dans `service_regeneration.R`

Le bloc BILJOU (« étape 3 ») suit déjà le patron option A/B. Passer en **option
B** quand l'utilisateur lance le calcul réel (case opt-in), en **remplaçant** le
`precomputed = pc$biljou` par les vraies entrées :

```r
report("regen_bilan_hydrique", 0.40)
if (!is.null(pc$biljou)) {                              # fast-path cache
  units <- .regen_step(function() nemeton::regen_bilan_hydrique(
    units, precomputed = pc$biljou), units, env, "regen_bilan_hydrique")
} else if (engine_opt_in) {                             # option B — run réel
  meteo <- nemeton::load_biljou_forcing(units, years = c(years$year_moyenne, years$year_canicule),
            source = cfg$forcing, cache_dir = <cache>/biljou)
  sol   <- nemeton::build_biljou_soil(units, ewm = cfg$ewm)
  if (is.null(meteo) || is.null(sol)) {
    env$warnings <- c(env$warnings, i18n$t("regen_guard_biljou"))
  } else {
    units <- .regen_step(function() nemeton::regen_bilan_hydrique(
      units, meteo = meteo, sol = sol, lai_max = cfg$lai_max,
      forest_type = cfg$forest_type, years = c(years$year_moyenne, years$year_canicule),
      budburst = cfg$budburst, leaf_fall = cfg$leaf_fall),
      units, env, "regen_bilan_hydrique")
    # cache fast-path pour les runs suivants
    sf::st_write(units[c("njstress","istress","rew_min","deb_stress", <geom>)],
                 file.path(<cache>, "biljou.gpkg"), delete_dsn = TRUE, quiet = TRUE)
  }
} else {
  env$warnings <- c(env$warnings, i18n$t("regen_guard_biljou"))   # option A
}
```

Points clés :

- **Async** : `load_biljou_forcing(source = "safran"|"era5")` **télécharge** (lent
  la 1ʳᵉ fois : dataverse SAFRAN ou ERA5-Land). Le lancer dans le **même worker
  `future`/ExtendedTask** que le moteur microclimf, pas dans le thread UI.
- **Cache** `biljou.gpkg` (fast-path) + cache disque cœur du forçage sous
  `<cache>/biljou/` (SAFRAN/ERA5 volumineux, stables par année). Les runs suivants
  réutilisent sans re-télécharger.

## 3. Sources & prérequis

| `cfg$forcing` | Source | Prérequis |
|---------------|--------|-----------|
| `"safran"` (défaut) | SAFRAN 8 km France (dataverse Recherche Data Gouv, DOI par défaut) | **aucune clé** — accès ouvert |
| `"era5"` | ERA5-Land (`mcera5`) | **clé CDS** `ecmwfr::wf_set_key()` — la même que le forçage microclimf |

Donc **SAFRAN marche sans clé CDS** : c'est le chemin à privilégier en France, et
il débloque le bilan hydrique même sans les identifiants Copernicus.
Réutiliser le garde `regen_cds_credentials_ready()` **uniquement** quand
`cfg$forcing == "era5"`.

## 4. Inputs UI — déjà présents

`forcing` (safran/era5), `ewm`, `lai_max`, `forest_type`, `budburst`,
`leaf_fall`, `year_moyenne`, `year_canicule` existent déjà dans
`mod_regeneration.R`. **Aucun nouvel input requis.**

## 5. Dégradation & garde

- `load_biljou_forcing()`/`build_biljou_soil()` → `NULL` : afficher
  `regen_guard_biljou` (i18n) au lieu de l'erreur cœur brute ; le reste du run
  (radar A/W/R, priorité) continue sur ce qui est disponible.
- `regen_bilan_hydrique()` conserve son chemin `precomputed` (fast-path cache) —
  inchangé.

## 6. Règles

1. **Aucune acquisition/logique données côté app** : tout passe par
   `load_biljou_forcing` / `build_biljou_soil` (cœur). L'app cache et orchestre.
2. Textes UI via `i18n$t(...)`.
3. Chemin async + cache `biljou.gpkg`, identique au patron microclimf option B.

---

### Note (résidu cœur)
Les **téléchargements SAFRAN/ERA5 réels** (dataverse + clé CDS) ne sont pas
jouables en CI : validés côté app sur un premier run réel. La conversion
`raw → meteo` et le sol sont testés côté cœur.
