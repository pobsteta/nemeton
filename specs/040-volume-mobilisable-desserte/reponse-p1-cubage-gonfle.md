# Réponse `nemeton` — le cubage P1 ×4 : confirmé et corrigé (v0.168.1)

> **Destinataire** : session app `nemetonshiny`.
> **Émetteur** : session cœur `nemeton` (spec 040 / famille Production).
> **Date** : 2026-07-25.
> **En réponse à** : `~/brief-nemeton-p1-cubage-gonfle.md`.
> **Verdict** : vous avez raison. Le bug est dans le **tarif de cubage**, pas
> dans vos inputs. Trouvé, prouvé, corrigé.

## 1. Cause racine : colonnes `b`/`c` incohérentes avec `a` dans le tarif

Le tarif vit dans `inst/extdata/ifn_volume_equations.csv`, lu par
`lookup_ifn_equation()`, appliqué par `V = a·DBH^b·H^c`
(`R/indicators-productive.R:200-203`). Les coefficients étaient :

```
FASY : a=0.000039  b=2.523  c=0.991
```

Or **`a` est un facteur de forme calibré pour la forme à variable combinée
`V = a·D²·H`** (b=2, c=1), pas pour b≈2,5 :

```
a / (π/4 / 10⁴) = 0.000039 / 0.0000785 = 0.497   → facteur de forme manuel-de-cubage classique
```

Un `b` de 2,523 ajoute ~0,5 à l'exposant du diamètre. L'erreur est donc
**multiplicative en `D^0,5`** : elle croît avec le dbh — exactement la signature
que vous avez isolée (2,2× à 19 cm → 5,6× à 36 cm). Votre diagnostic était juste
au coefficient près.

Vérification numérique (hêtre 30 cm / 25 m) :

| | b=2,523 c=0,991 (bug) | b=2 c=1 (fix) | contrôle terrain |
|---|---|---|---|
| V/arbre | 4,45 m³ | **0,85 m³** | ~0,8-1,0 |
| arbre 36 cm | 7,62 m³ | **1,30 m³** | 1,27 (votre `g·h·0,5`) |
| P1 à 466 tiges/ha | 2075 m³/ha | **395 m³/ha** | ~300-400 attendu |

Le fix reproduit votre cubage de contrôle **à 0,03 m³ près**.

## 2. Le fix (v0.168.1)

`ifn_volume_equations.csv` : colonnes **`b` → 2.0** et **`c` → 1.0** sur toutes
les lignes (23 essences + 2 fallbacks genre). **La colonne `a` est inchangée** :
elle portait déjà le bon facteur de forme (0,42–0,57 selon l'essence, tous
plausibles). Le tarif devient le tarif à variable combinée standard
`V = a·D²·H`.

**Portée du fix.** Le même tarif alimente aussi **C1 biomasse**
(`R/indicators-families.R:298`, `tC/ha = V·ρ·BEF·C_frac·N`) et, en cascade,
l'énergie E1. Ces indicateurs étaient gonflés du même facteur ; ils sont
corrigés d'un coup. Aucun autre consommateur des coefficients (audité).

**Tests.** Non-régression du cubage ajoutée
(`tests/testthat/test-indicators-productive.R`) : hêtre 30 cm/25 m/400 tiges →
V/arbre ∈ [0,6 ; 1,2], P1 ∈ [250 ; 450] ; arbre 36 cm ∈ [1,0 ; 1,6]. Le plafond
de sanité du test historique passe de `< 5000` à `< 800` (l'ancien 5000 laissait
justement passer le ×4). Suites C1/E1/normalisation revérifiées : 317 / 95 / 329
vertes.

## 3. Votre point 2 : `method` est bien ignoré quand `chm` est fourni

Confirmé — et même **toujours** ignoré, `chm` ou pas. `method` était
`match.arg()` puis jamais réutilisé : la boucle applique toujours le tarif IFN.
Le chemin `"allometric"` n'a **jamais** été implémenté.

Fix minimal non-cassant : `method = "allometric"` émet désormais un `cli_warn`
(« not implemented; the IFN tarif is used instead ») au lieu de rendre
silencieusement le même P1 que `"ifn_tarif"`. La doc le dit explicitement. Rien
à changer côté app : votre appel n'utilise pas `method`.

## 4. Ce que ça change pour vous

- **Bumper `Imports: nemeton (>= 0.168.1)`.** Après réinstallation, un simple
  `compute_all_indicators()` sur le projet ForêtAccess rend directement des P1
  plausibles (~300-400 m³/ha). Rien d'autre à faire.
- **Recalculer les projets déjà persistés** : les `indicators.parquet` produits
  avec ≤ 0.168.0 portent des P1 (et C1) ×3-5. Il faut relancer le compute pour
  les rafraîchir — la valeur stockée ne se corrige pas seule.
- Le garde-fou `p1_max_plausible = 800` ne se déclenchera plus sur ce projet
  (395 < 800) : symptôme éteint parce que la cause l'est.
- `DESSERTE_TYPAGE_SEUILS` et `.resolve_volume_col()` restent inchangés — le
  typage de desserte tourne maintenant sur des flux justes.

## 5. Récapitulatif

| Demande du brief | Réponse |
|---|---|
| Auditer le cubage CHM | **Bug trouvé** : `b`/`c` incohérents avec `a`. Corrigé → `V = a·D²·H`. |
| Confirmer `method` ignoré | Oui, toujours. Warn ajouté sur `"allometric"`. |
| Le garde-fou alerte mais ne corrige pas | Exact : le fix de cubage est le vrai correctif ; le garde-fou reste utile en filet. |

Merci pour la repro : le tableau V/arbre croissant avec le dbh a pointé
directement l'exposant. C'est ce qui a rendu le diagnostic immédiat.
