# Réponse `nemeton` — unité de `indicateur_p1_volume` (desserte spec 040)

> **Destinataire** : session app `nemetonshiny`.
> **Émetteur** : session cœur `nemeton`.
> **Date** : 2026-07-25.
> **En réponse à** : `~/brief-nemeton-unite-p1-volume.md` (2026-07-24).
> **Verdict** : l'unité n'est pas en cause. P1 est bien en **m³/ha**. Les
> valeurs observées (682–2315, médiane 1556) sont des m³/ha **hors domaine** :
> le bug est en **amont, dans les inputs**, pas dans le pipeline desserte.

## 1. Unité de `indicateur_p1_volume()` : m³/ha, volume sur pied brut

Ni score normalisé, ni total. Le cœur est univoque :

| Source | Preuve |
|---|---|
| `R/indicator-config.R:293` | label **« Volume de bois (m³/ha) »** |
| `R/indicator-config.R:300` | tooltip **« Valeurs typiques : 100-400 m³/ha »** |
| `R/indicators-productive.R:50` | `@return … P1 (standing volume in m3/ha)` |
| `R/indicators-productive.R:200-203` | `V = a·DBH^b·H^c` (m³/arbre) × `density` (tiges/ha) = **m³/ha** |
| `R/indicators-productive.R:228` | message succès *« Standing timber volume (m3/ha) »* |
| `R/normalization.R:550` | plafond de normalisation P1 = **800 m³/ha** |

Conséquence directe : la lecture « m³/ha » du brief est la bonne. Médiane
1556 m³/ha = ~2× le plafond de normalisation, ~4× le max typique. **Ce ne sont
pas des faux m³ : ce sont de vrais m³/ha, mais faux en valeur.** À tracer sur
vos données d'entrée (voir §5).

## 2. Le « volume brut » n'existe pas séparément : P1 EST le brut

- `volume_mobilisable(volume_col = …)` consomme **directement** la colonne P1.
- L'indice normalisé [0..1] est une **autre** colonne (`R/normalization.R`),
  jamais passée à `volume_mobilisable`. Aucun rappel avec d'autres arguments
  n'est nécessaire.
- Cas NDP 0 sans inventaire ni CHM → P1 = `NA`. Complété par
  **`completer_volume_ifn()`** avec le volume de référence IFN régional
  (cascade SER → GRECO → national), en m³/ha, colonne de provenance
  `volume_source`. **C'est votre ancre de plausibilité toute trouvée** : un P1
  mesuré/synthétique qui s'écarte d'un facteur 3-4 de la référence IFN pour la
  même essence/SER est presque sûrement faux.

## 3. `P1` vs `indicateur_p1_volume` : les deux sont canoniques

Deux couches, pas une divergence :

- La **fonction** écrit `column_name = "P1"` par défaut (code court NMT).
- La **config** (`R/indicator-config.R:291`) mappe le code `P1` → colonne
  persistée **`indicateur_p1_volume`**.

Donc votre persistance sous `indicateur_p1_volume` est **alignée avec le cœur**,
et votre `.resolve_volume_col()` est correct. Côté appel :
`volume_mobilisable(volume_col = "indicateur_p1_volume")`. Rien à réconcilier.

## 4. Garde-fou de plausibilité — **livré côté cœur** (v0.168.0)

`volume_mobilisable()` gagne un paramètre `p1_max_plausible = 800` (m³/ha, le
plafond de normalisation P1) :

- toute unité dont le P1 dépasse le seuil déclenche un `cli_warn` (compte, max,
  médiane des valeurs hors domaine) ;
- **`warn`, jamais `abort`** : un peuplement très capitalisé peut frôler le
  plafond légitimement — on alerte, on ne bloque pas ;
- `p1_max_plausible = NULL` désactive ; le seuil est réglable.

Sur votre projet réel, le premier appel de `volume_mobilisable()` aurait donc
émis :

```
! 30 units with "indicateur_p1_volume" above 800 m3/ha (max 2315.5, median 1556).
i P1 is a standing volume in m3/ha (typical 100-400). Values this high usually
  mean a wrong unit or an over-estimated inventory upstream; the road typing
  would run on inflated flux.
```

C'est-à-dire exactement l'alerte qui manquait pour attraper le bug avant le
typage. Rien à faire côté app : le paramètre a un défaut ; l'avertissement
remonte tout seul.

## 5. Ce qui reste à faire côté app : tracer la source des 1556 m³/ha

Le cœur ne voit pas d'où viennent vos inputs. Pistes, par ordre de probabilité :

1. **Chemin d'inventaire.** Si `chm` est fourni, P1 passe par
   `ensure_inventory_fields()` → `estimate_synthetic_inventory()` (CHM → D_g via
   Charru 2012 → N = `stocking` × N_max). Vérifier `stocking` (défaut 0.75) et
   surtout que `density` n'est pas déjà en tiges/ha ET re-multipliée. Un N gonflé
   ou un D_g hors clamp propage un P1 ×3-4.
2. **`dbh`/`density` fournis dans la mauvaise unité** (ex. densité en tiges/parcelle
   prise pour tiges/ha, ou dbh en mm pris pour cm).
3. **Double comptage** : P1 déjà en m³/ha, puis re-multiplié par une surface
   quelque part avant la persistance.

Diagnostic minimal, en confrontant à `completer_volume_ifn()` sur les mêmes
essences/SER :

```r
library(nemeton)
d   <- sf::st_read(".../parcelles.gpkg")            # vos UGF, avec espar/species
ref <- completer_volume_ifn(
  transform(d, indicateur_p1_volume = NA_real_),    # force la substitution IFN
  volume_col = "indicateur_p1_volume", ser = "<SER>"
)
data.frame(
  p1_observe = d$indicateur_p1_volume,
  p1_ref_ifn = ref$indicateur_p1_volume,
  ratio      = d$indicateur_p1_volume / ref$indicateur_p1_volume
)
# Un ratio ~3-4 systématique pointe la densité ou le double comptage.
```

## 6. Récapitulatif décisionnel

| Question du brief | Réponse |
|---|---|
| Q1 — unité | **m³/ha**, volume sur pied brut. Pas un score. Valeurs hors domaine. |
| Q2 — où est le brut | P1 **est** le brut. NA complété par `completer_volume_ifn()`. |
| Q3 — `P1` vs `indicateur_p1_volume` | Les deux canoniques (code vs colonne). Aligné, rien à réconcilier. |
| Q4 — validation d'entrée | **Livré** : `p1_max_plausible = 800`, `cli_warn`. |

Pas besoin de recalibrer `DESSERTE_TYPAGE_SEUILS` : les seuils
`c(tertiaire=0, secondaire=100, primaire=500)` restent en m³ totaux accumulés,
et `volume_mobilisable(unite="m3_total")` fait bien la conversion m³/ha → total.
Le typage sera juste **dès que le P1 d'entrée sera plausible** — corriger
l'input, pas les seuils.
