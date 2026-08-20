# Spec 047 — R1 incendie sur `firexpovulnR`

**Version** : 1.0.0 (cadrage)
**Date**    : 2026-08-20
**Statut**  : **À décider.** Cadrage écrit à la demande de Pascal. Aucune ligne
de code écrite : la convention du dépôt veut spec + ADR avant l'ajout d'une
dépendance.
**Auteur**  : Pascal Obstétar (via Claude).
**Cible**   : `nemeton` (cœur). ADR associé : `ADR-016` (brouillon joint).

---

## 1. Pourquoi toucher à R1

`indicateur_r1_feu()` fonctionne, mais trois faiblesses sont documentées dans
son propre code, et deux ont déjà produit un incident.

### 1.1 Des seuils qui sont des conventions, pas des références

Le chemin de repli pose `min(pente / 30°, 1)`, une normalisation climatique sur
`(T − 8)/8` et `(1400 − P)/900`, et `50` comme inflammabilité d'une essence
inconnue. Aucun de ces nombres n'est sourcé. Ils sont plausibles ; ils ne sont
pas défendables devant un lecteur qui demande d'où ils viennent.

### 1.2 L'exposition sature, et c'est mesuré

Le commentaire de `R/indicators-risk.R` le dit avec les chiffres : sur un massif
continu, chaque unité a ~tout son voisinage de 500 m combustible — **93 % sur le
projet Fordead, R1 entre 98,7 et 100 sur les 30 unités**. L'indicateur ne
classait plus rien. D'où la pondération actuelle `exposure 0,5 / slope 0,25 /
climate 0,25`, qui est un correctif empirique, pas une méthode.

### 1.3 Aucune calibration

R1 n'a jamais été confronté à des surfaces réellement brûlées. On ne sait pas
s'il classe juste.

### 1.4 Et le chemin suivi n'est pas tracé dans le résultat

Selon que `fireexposuR` est installé et que la BD Forêt recouvre le MNT, R1 est
produit par deux méthodes aux pondérations différentes. Le choix n'apparaît que
dans les logs (`R1: Using fireexposuR…` / `R1: Using fallback method…`), jamais
dans la sortie : deux projets peuvent porter des R1 non comparables sans que
rien ne le signale.

## 2. Ce que `firexpovulnR` apporte

Dépôt `pobsteta/firexpovulnR`, **v0.32.0**, GPL-3, même auteur, même pile
(`sf`/`terra`). Lu le 2026-08-20 : README, `DESCRIPTION`, `NAMESPACE`, doc
roxygen et sources citées des fonctions visées.

| Faiblesse R1 | Réponse du package |
|---|---|
| Seuils non sourcés | Principe de conception affiché : « aucun seuil en dur ; tout seuil ou rayon importé d'une publication est un argument avec valeur par défaut **sourcée**, surchargeable » |
| Rayon de transmission figé à 500 m | `fev_exposure(type = c("ember", "ember_short", "radiant"), radius =)`, rayons de Beverly et al. 2010 / 2021 et Khan et al. 2025, géométrie de fenêtre vérifiée |
| Aucune calibration | `fev_validate(risk, burnt_areas)` — confrontation aux surfaces brûlées, courbe sur `n_thresholds` |
| Méthode non tracée | Tout objet `fev_stack` transporte sources, millésimes, période de calibration et paramètres ; `fev_provenance()` exporte en YAML |
| Proxy climatique WorldClim | FWI calibré en percentiles régionaux (`fev_fwi_percentile`, `fev_danger_index`) |

**Coût d'entrée faible** : `Imports` = `cffdrs`, `cli`, `grDevices`, `graphics`,
`rlang`, `sf`, `stats`, `terra (>= 1.7)`, `tools`, `utils`, `yaml`. `ecmwfr`,
`fireexposuR`, `lidR`, `medfate` sont en **`Suggests`** — le CDS n'est donc pas
obligatoire, et `fev_exposure()` part d'un raster de combustible, donc le chemin
principal reste **jouable en NDP 0 sur données publiques**.

## 3. Périmètre — ce qu'on prend et ce qu'on ne prend pas

### 3.1 On prend : les briques de calcul

Chaîne visée, telle qu'elle apparaît dans la vignette `maures.Rmd` du package :

```r
fuel <- fev_fuel_source(bdforet, type = "bdforet_v2", res = 25, crs_work = 2154)
burn <- fev_fuel_binary(fuel)
expo <- fev_exposure(burn, type = "ember")        # rayons sourcés
```

`fev_fuel_source()` accepte directement **BD Forêt v2** — ce que `layers$bdforet`
fournit déjà — ainsi que CLC 2018, WorldCover 2021, LiDAR HD et `custom`.

### 3.2 On prend, mais conditionnellement à la source : le danger FWI

```r
danger <- fev_danger_index(fwi, fuel_availability)   # si CDS configuré
```

Motif **déjà établi dans le dépôt** : SUFOSAT conditionne T3 (spec 030),
FORDEAD conditionne R5 (spec 008). Sans CDS, R1 garde son proxy climatique
actuel ; avec, il gagne un vrai indice de danger météorologique.

**Pourquoi conditionnel et non requis** : la friction CDS est connue et
documentée — c'est elle qui a bloqué E-OBS (variable `.Renviron` mal nommée,
licence non acceptée). Rendre R1 dépendant du CDS rendrait R1 fragile.

### 3.3 On ne prend PAS : `fev_risk()`

`fev_risk(danger, vulnerability)` croise le danger avec une vulnérabilité
d'**enjeux** — population, bâti, habitats protégés. C'est du **risque
sociétal**. Or dans Néméton ces enjeux sont déjà **S1** (routes), **S2** (bâti),
**S3** (population) et la famille **N**. L'adopter ferait doublon et changerait
le sens de R1, qui est une propriété de l'unité forestière.

### 3.4 On ne prend PAS : les `fev_fetch_*`

Le package sait chercher DEM, BD Forêt, FWI, LiDAR HD, WorldCover, GHSL et
**SUFOSAT** — il recouvre donc notre couche d'acquisition. Deux chaînes
parallèles finiraient par diverger sur les CRS et les millésimes : c'est
exactement la famille de bugs que `safe_rasterize()` et `.normalize_crs()`
existent pour rattraper. **Frontière posée : `firexpovulnR` calcule, `nemeton`
acquiert.**

## 4. Contrat de sortie — inchangé

Non négociable, sous peine de casser l'app et le radar :

- `indicateur_r1_feu(units, …)` rend l'`sf` d'entrée augmenté d'une colonne
  `R1` **numérique 0-100, haut = plus de risque** ;
- R1 reste dans la liste des indicateurs **inversés** de `normalization.R` —
  l'app ne ré-inverse jamais ;
- `NA` quand l'indicateur n'est pas calculable, jamais `0` ;
- la signature actuelle reste valide : les nouveaux paramètres ont des défauts.

## 5. Ce qui doit être tracé dans le résultat

Corrige le §1.4. Le retour porte un attribut de méthode :

```r
attr(units$R1, "methode")   # "fev_exposure" | "fireexposur" | "fallback"
```

et, quand le chemin `firexpovulnR` est pris, la provenance `fev_provenance()`
est jointe. Sans ça, on reproduit le défaut qu'on corrige.

## 6. Étapes, dans l'ordre

| | Étape | Sortie |
|---|---|---|
| **0** | **Décision** : ADR-016 accepté ou refusé | ADR |
| **1** | **Comparaison à l'aveugle** sur un massif connu — Fordead (où R1 sature à 98,7-100) et les Maures (vignette existante) : R1 actuel vs `fev_exposure` | note chiffrée |
| **2** | **Calibration** : `fev_validate()` contre les surfaces brûlées (`fev_fetch_burnt` côté package, ou notre propre source) | courbe + seuil retenu |
| **3** | Câblage du chemin principal + attribut de méthode + tests | `nemeton` mineur |
| **4** | FWI conditionnel à la source (CDS) | `nemeton` mineur |

**L'étape 1 conditionne tout.** Si `fev_exposure` sature comme l'actuel sur un
massif continu, le gain se réduit aux seuils sourcés et à la provenance — ce qui
resterait utile, mais ne justifierait pas le même effort.

## 7. Critères d'acceptation

- **AC1** — Sur le projet Fordead, R1 **classe** : écart-type non nul, et pas
  30 unités entre 98,7 et 100.
- **AC2** — `fev_validate()` rend une performance **mesurée et consignée**
  contre les surfaces brûlées, quelle qu'elle soit. Un R1 non calibré ne doit
  plus être livré en silence.
- **AC3** — Sans `firexpovulnR` installé, R1 se comporte **exactement** comme
  aujourd'hui (repli inchangé, aucune régression).
- **AC4** — Sans CDS, le chemin principal fonctionne quand même (NDP 0).
- **AC5** — La méthode retenue est **lisible dans le résultat**, pas seulement
  dans les logs.
- **AC6** — Aucun appel à un `fev_fetch_*` dans `nemeton`.

## 8. Réserves, à lever avant de coder

**Ma revue est documentaire.** J'ai lu signatures, roxygen, README et sources
citées — **pas les implémentations**. Rien n'a été exécuté. L'étape 1 n'est pas
une formalité, c'est la vérification.

**Le package est `lifecycle: experimental`, v0.32.0**, et sa `DESCRIPTION` dit
« internal research use, not for CRAN ». Néméton est dans le même cas, donc le
facteur de bus ne change pas — mais l'API peut bouger : plancher de version
strict et `Suggests`, jamais `Imports`, tant que le chemin de repli existe.

**Recouvrement à surveiller** : `fev_fetch_sufosat` recouvre notre acquisition
T3, `fev_fetch_bdforet` et `fev_fetch_lidarhd` la nôtre. La frontière du §3.4
est la protection ; elle doit être vérifiée à la revue, pas supposée.

## 9. Ce que cette spec ne demande pas

- Aucun changement du contrat de sortie de R1 (§4).
- Aucune reprise de la famille S ou N : la vulnérabilité d'enjeux n'entre pas
  dans R1 (§3.3).
- Aucune dépendance obligatoire au CDS (§3.2).
