# Spec 045 — Famille L : le nom des fonctions doit dire ce qu'elles calculent

**Version** : 1.0.0
**Date**    : 2026-08-18
**Statut**  : **Décidée par Pascal le 2026-08-18**, en réponse au brief
`specs/BRIEF-nemeton-libelles-famille-L.md`. Trois options étaient sur la table
(ne rien changer / échanger les libellés / renommer les fonctions) ; c'est la
troisième — traiter la cause — qui est retenue.
**Auteur**  : Pascal Obstétar (via Claude).
**Cible**   : `nemeton` (cœur). Suite obligatoire côté `nemetonshiny`.

---

## 1. Le fait

Une colonne d'indicateur porte le nom de la **fonction qui la remplit** :
`compute_indicator()` résout la fonction par le nom de l'indicateur
(`R/indicators-core.R:199`). Pour la famille L, ce nom contredit le contenu :

| Fonction (avant) | Titre roxygen | Ce qu'elle calcule réellement |
|---|---|---|
| `indicateur_l2_fragmentation()` | « Sylvosphere - Edge Effect (L1) » | indice de forme (30 %) + contraste de matrice (40 %) + exposition vent/soleil (30 %) — **sylvosphère / effet lisière** |
| `indicateur_l1_sylvosphere()` | « Landscape Fragmentation (L2) » | landscapemetrics COHESION + AI sur un tampon de 1 km — **fragmentation paysagère** |

Preuve indépendante du corps des fonctions : `indicateur_l2_fragmentation(u)`
rend des scores **sans aucune couche de landcover** (36,4 / 34,5 / 37,5 sur le
massif démo) — une métrique de fragmentation paysagère ne le peut pas.

Conséquences en cascade, toutes constatées :

1. `INDICATOR_FAMILIES` a dû **croiser** l'appariement `code ↔ colonne` pour que
   les libellés restent justes (`L1 -> indicateur_l2_fragmentation`).
2. Ce croisement se lit comme une erreur — il a produit un brief demandant
   d'échanger les libellés, ce qui aurait retitré les cartes à faux.
3. `.normalize_resolve_alias()` déduit le code court **du slug**
   (`^indicateur_([a-z][0-9]+)_`), donc `"L1"` résout aujourd'hui vers
   `indicateur_l1_sylvosphere`, c'est-à-dire vers la fragmentation. Sans
   conséquence tant que les deux sont des 0-100 natifs, mais c'est un piège armé.
4. Trois tables côté app, indexées par nom de colonne, suivent le slug et sont
   donc inversées.

Tant que le nom ment, chaque consommateur doit connaître l'exception. La
renommer supprime la classe entière.

## 2. Décisions

### D1 — Ne pas réutiliser les deux slugs existants

L'échange en place (`indicateur_l1_sylvosphere` devenant la sylvosphère) est
**refusé** : les noms de colonnes sont **persistés** (parquet de projet,
PostGIS, alias DB de l'app). Réutiliser un slug en lui donnant le sens opposé
ferait basculer en silence la signification de toute donnée déjà écrite —
aucune relecture ne pourrait distinguer l'ancien du nouveau. Les deux slugs sont
donc **retirés définitivement**, jamais recyclés.

### D2 — Noms retenus

| Code | Nom (après) | Libellé (inchangé) |
|------|-------------|--------------------|
| L1 | `indicateur_l1_effet_lisiere` | Sylvosphère (effet lisière) |
| L2 | `indicateur_l2_morcellement` | Fragmentation paysagère |

Convention NMT respectée (snake_case français sans accent, ≤ 30 caractères).
Le code court et le slug **concordent** : la famille L sort du croisement.

### D3 — Les anciens noms restent, dépréciés

`indicateur_l2_fragmentation()` et `indicateur_l1_sylvosphere()` restent
exportés comme enveloppes minces, émettent `.Deprecated()` (idiome déjà en place
dans `R/qgis_import.R`) et **rendent exactement ce qu'elles rendaient** — donc
`indicateur_l1_sylvosphere()` continue de rendre la fragmentation. Aucun
appelant existant ne casse. Retrait au prochain palier majeur.

### D4 — Une aide à la migration des données déjà écrites

`migrer_colonnes_l(data)`, exportée : renomme les colonnes héritées **sans
toucher aux valeurs**.

```
indicateur_l2_fragmentation       -> indicateur_l1_effet_lisiere
indicateur_l1_sylvosphere         -> indicateur_l2_morcellement
indicateur_l2_fragmentation_norm  -> indicateur_l1_effet_lisiere_norm
indicateur_l1_sylvosphere_norm    -> indicateur_l2_morcellement_norm
```

Les colonnes de code court (`L1`, `L2`) ne bougent pas : elles étaient déjà
appariées correctement. Quand ancienne et nouvelle colonne coexistent, la
nouvelle est conservée et un avertissement nomme le conflit — pas d'écrasement
silencieux.

### D5 — La famille F reste croisée, et c'est délibéré

`F1 -> indicateur_f2_erosion` n'est pas le même défaut : là, aucune fonction ne
contredit son propre titre. `indicateur_f1_fertilite()` calcule bien une
fertilité de sol ; `indicateur_f2_erosion()` porte le titre « Soil Fertility
Index (F2) » et combine TWI + pente + résistance texturale à l'érosion. Ce qui
reste à trancher pour F est **sémantique** (que désigne F1 : l'érosion, ou
l'indice TWI+pente ?), pas typographique. Hors périmètre de cette spec ; le
croisement F reste documenté et verrouillé par test.

## 3. Critères d'acceptation

- **CA-1** — `indicator_labels()` ne porte plus qu'**un seul** couple croisé,
  `F1`/`F2`. Le balayage structurel des 41 lignes le vérifie.
- **CA-2** — Les libellés et infobulles de L sont **inchangés** : ils décrivaient
  déjà les valeurs. Seuls les slugs bougent.
- **CA-3** — Les deux anciennes fonctions restent appelables, avertissent, et
  rendent les mêmes valeurs qu'avant (test de non-régression sur le massif démo).
- **CA-4** — `migrer_colonnes_l()` renomme sans toucher aux valeurs, gère les
  `_norm`, avertit sur conflit, et laisse passer un jeu déjà migré.
- **CA-5** — `.normalize_resolve_alias("L1")` résout désormais vers
  `indicateur_l1_effet_lisiere` : slug et code court concordent.
- **CA-6** — `nemeton_compute()` par défaut produit les nouvelles colonnes ;
  aucune valeur ne change.

## 4. Suite côté `nemetonshiny`

Brief : `specs/brief-nemetonshiny-renommage-famille-L.md`. L'app doit
adopter les nouveaux noms, appeler `migrer_colonnes_l()` à la relecture des
projets existants, et cesser de tenir ses propres tables de libellés indexées
par colonne (`utils_i18n.R`, `mod_progress.R`, `service_db.R`).
