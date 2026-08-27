# Spec 051 — Houppiers par LSMS (OTB), cadré sur AOI

**Statut :** cadrée le 2026-08-27, **non implémentée**. Décisions D1-D5 tranchées
par Pascal sur mesures réelles (§4).

**Origine :** brief `2026-08-24-houppiers-sans-lidar-otb-lsms.md` (session
`nemetonshiny`), étude de faisabilité. Ce document en reprend les conclusions
utiles, en corrige deux, et **cadre le sujet à l'emprise que le coût autorise**.

---

## 1. Ce que le brief avait raison de dire

- **La prémisse « pas de LiDAR » était fausse.** Ce cas est déjà couvert par le
  CHM prédit d'Open-Canopy. Le vrai cas non couvert est « aucun modèle de
  hauteur », et LSMS n'y répond pas — il segmente une image, il ne mesure pas
  une hauteur.
- **Le défaut du CookBook OTB sur-segmente massivement.** Confirmé : à
  `5/15/50`, on segmente des facettes de houppier, pas des arbres.
- **`h_max` se récupère par zonale, pas par LSMS.** Confirmé et mesuré :
  `-imfield` ne calcule que moyenne et écart-type par région, or `h_max` est un
  apex. `terra::extract(chm, segments, fun = max)` place **876 segments sur
  886** dans la plage 1–70 m qu'exige Marculus, avec une médiane identique à
  celle de la voie CHM (35,5 m).
- **`-mode.vector.out` en `.gpkg` échoue** (`Unable to commit transaction for
  OGR layer`), le `.shp` passe. Non re-testé ici, repris tel quel.

## 2. Les deux corrections

### 2.1 Le coût : un facteur 18 d'écart avec le brief

Le brief annonçait **~9 s** pour l'enchaînement complet sur 1000 × 1000 px, et
refusait — à juste titre — d'extrapoler. Mesuré ici sur une fenêtre de même
taille en pixels :

| Fenêtre | Pixels | LSMS (`15/20/500`) | Voie CHM |
|---|---|---|---|
| 200 × 200 m (4 ha) | 1,0 Mpx | **160,5 s** | **2,3 s** |
| 400 × 400 m (16 ha) | 4,0 Mpx | **716 s** | — |

La **vectorisation** coïncide au dixième de seconde (1,05 s ici, 1,1 s au
brief) : tout l'écart est dans la segmentation. **LSMS est ~70× plus lent que la
voie CHM à surface égale.**

**Hypothèse sur l'écart, non vérifiable** : le mean-shift converge selon le
*contenu*, pas seulement selon le nombre de pixels. La fenêtre mesurée ici est le
peuplement le plus haut du massif — 89 % de couvert, h_max médian 35,5 m,
maximum de texture. Le brief ne dit pas quel couvert avait la sienne, et le
projet qu'il a mesuré **n'existe plus** (le Couchey de référence a été remplacé
le 2026-08-25 par l'import CSV destructif de l'app, v0.133.0). L'écart est donc
constaté, pas expliqué.

**Conséquence directe** : sur l'emprise entière de Fordead (292 Mpx, 1 170 ha),
l'extrapolation donne **13 à 20 h**. LSMS n'est pas un algorithme d'emprise.

### 2.2 Le filtre par hauteur : un mécanisme juste, non validé ici

Une segmentation **partitionne** l'image ; la voie CHM **sélectionne** des
houppiers au-dessus de `hmin`. Filtrer les segments sur `h_max >= hmin` devrait
donc rapprocher les comptes. **Mesuré : il ne retire que 3 %** — la fenêtre étant
fermée à 89 %, il n'y a presque pas de sol à écarter. Le mécanisme reste juste et
nécessaire, mais **sa valeur n'est démontrée que sur un peuplement clair**, qui
reste à mesurer.

## 3. Périmètre retenu — LSMS est un outil d'AOI

`segment_houppiers()` gagne un algorithme `"lsms"` **borné par un budget de
calcul**, décision de Pascal : *« une surface acceptable, jusqu'à 10 min de
calcul »*.

### 3.1 Le garde-fou porte sur les PIXELS, pas sur les hectares

C'est le point de conception central. Le coût suit le nombre de pixels ; la
surface qu'il achète dépend donc de la résolution de l'ortho, et l'écart est d'un
facteur 6 :

| Budget | Pixels | Emprise à **0,20 m** | Emprise à **0,50 m** |
|---|---|---|---|
| 1 min | 0,40 Mpx | 1,6 ha (127 × 127 m) | 10,0 ha |
| 5 min | 1,79 Mpx | 7,1 ha (267 × 267 m) | 44,6 ha |
| **10 min** | **3,40 Mpx** | **13,6 ha** (369 × 369 m) | **84,9 ha** |
| 30 min | 9,40 Mpx | 37,6 ha | 235,0 ha |

Modèle : `t = 160,5 × P^1,0787` (P en Mpx, t en s), qui reproduit les deux points
mesurés à la seconde près.

**Ce que ce modèle n'est pas** : une prédiction. Il est calé sur **deux points**,
tous deux sur la fenêtre la plus texturée du massif, à `spatialr = 15`. C'est un
**majorant** — une futaie claire ira plus vite — et il ne vaut pas pour un autre
`spatialr` (§3.3). Le garde-fou doit donc *avertir avec une estimation*, pas
promettre une durée.

**Le rééchantillonnage est le seul levier d'ordre de grandeur** : passer l'ortho
de 0,20 à 0,50 m multiplie l'emprise atteignable par 6. Il se paie en détail
spectral — précisément ce qui justifie LSMS. À **exposer** (`resolution_image`),
pas à trancher en dur.

### 3.2 Deux usages séparés (D2)

Marculus ignore toute entité sans hauteur lisible. D'où deux chemins explicites,
et aucun entre-deux silencieux :

- **`usage = "martelage"` (défaut)** — le CHM est **obligatoire**. Sans lui, la
  fonction **refuse** plutôt que de rendre une couche que le téléphone ignorerait
  sans un mot. `h_max` est renseigné par zonale et les entités hors `h_range`
  sont écartées, comme sur la voie CHM.
- **`usage = "couvert"`** — assume de ne produire **aucune hauteur** : surface de
  houppier, densité de tiges, taux de couvert. La colonne `h_max` est absente
  (pas `NA` : absente, pour qu'aucun consommateur ne croie à une mesure
  manquante). Utilisable sans CHM.

### 3.3 Réglage par défaut (D3) — calibré sur mesure

Cible : la voie CHM sur la même fenêtre — **596 houppiers, 149/ha, diamètre
équivalent médian 8,04 m**.

| `spatialr`/`ranger`/`minsize` | Durée | Segments | /ha | Diam. médian | Écart |
|---|---|---|---|---|---|
| 15 / 20 / 500 | 160 s | 886 | 222 | 7,02 m | −1,02 m |
| **15 / 20 / 700** | **167 s** | **698** | **174** | **7,88 m** | **−0,15 m** |
| 15 / 20 / 900 | 178 s | 559 | 140 | 8,86 m | +0,82 m |
| 15 / 20 / 1200 | 183 s | 417 | 104 | 10,45 m | +2,42 m |
| 20 / 20 / 900 | 321 s | 540 | 135 | 9,11 m | +1,07 m |
| 20 / 25 / 1200 | 337 s | 415 | 104 | 10,28 m | +2,24 m |

**Défaut retenu : `spatialr = 15`, `ranger = 20`, `minsize = 700`.** Le diamètre
médian tombe à 2 % de la cible ; le compte reste 12 % au-dessus. Aucun réglage
mesuré ne satisfait les deux à la fois — `minsize = 900` inverse l'arbitrage
(−10 % sur le compte, +0,82 m sur le diamètre). Le diamètre est privilégié parce
qu'il porte la forme de l'objet, que le compte hérite ensuite.

**`spatialr = 20` est à la fois plus lent et moins bon** : 321 s contre 178 s à
`minsize` égal, pour un diamètre plus éloigné de la cible. Il n'y a pas
d'arbitrage à faire là — 15 domine. Et `20/25/1200` (337 s) ne fait pas mieux
que `15/20/1200` (183 s) : 10,28 m contre 10,45 m pour **1,8× le temps**.
`spatialr` est le poste de coût dominant du balayage, et il n'achète rien.

**Portée de cette calibration** : **une fenêtre, un peuplement** — futaie mature
fermée à 89 %. Le brief notait qu'un taillis dense et une futaie de chênes
n'appellent pas le même `spatialr`, comme `ws` côté `lmf` ; rien ici ne le
contredit ni ne le confirme. Le défaut est un point de départ documenté, pas une
valeur validée.

## 4. Décisions

- **D1** ✅ **LSMS entre comme algorithme d'AOI, pas d'emprise.** Le coût mesuré
  (~70× la voie CHM) l'interdit sur un massif entier.
- **D2** ✅ **Deux usages séparés** : `"martelage"` exige le CHM et refuse sans
  lui ; `"couvert"` assume l'absence de hauteur et n'expose pas `h_max`.
- **D3** ✅ **Défaut `15/20/700`**, calibré sur la voie CHM (écart −0,15 m sur le
  diamètre équivalent médian). Mono-peuplement, à reprendre sur un taillis et une
  futaie claire.
- **D4** ✅ **Garde-fou en pixels**, budget par défaut **10 min ≈ 3,4 Mpx**.
  Au-delà, la fonction refuse et dit quoi faire : réduire l'AOI, ou
  rééchantillonner l'ortho (le tableau §3.1 chiffre les deux).
- **D5** ✅ **OTB en `Suggests`**, détecté comme `dessertR`/`reticulate` le sont,
  dégradation propre en son absence. Sortie en `.shp` puis relecture (le pilote
  GPKG d'OTB 9.1.1 échoue).

## 5. Interface visée

```r
segment_houppiers(chm, aoi = NULL, ws = 5, hmin = 5,
                  algorithme = c("dalponte", "silva", "watershed", "lsms"),
                  image      = NULL,        # ortho IRC/RVB, exigée par "lsms"
                  usage      = c("martelage", "couvert"),
                  lsms       = list(spatialr = 15, ranger = 20, minsize = 700),
                  resolution_image = NULL,  # reechantillonnage avant LSMS
                  budget_s   = 600,         # garde-fou de duree (D4)
                  ...)
```

- `algorithme = "lsms"` **exige** `image` ; `usage = "martelage"` **exige** en
  plus `chm`.
- Le budget est vérifié **avant** l'appel OTB, à partir du nombre de pixels de
  l'AOI après `resolution_image`.
- LSMS délimite ; `terra::zonal(chm, segments, "max")` renseigne `h_max` — le
  cœur fait déjà exactement cela.

## 6. Ce qui n'est pas mesuré, et qu'il ne faut pas supposer

1. **Le coût sur un peuplement clair.** Toutes les mesures viennent d'une futaie
   fermée à 89 %. Si le coût suit la texture, un taillis clair pourrait être
   nettement moins cher — ce qui déplacerait tout le tableau §3.1.
2. **La valeur du filtre `h_max >= hmin`** (§2.2), invisible ici faute de sol
   dans la fenêtre.
3. **Le gain qualitatif annoncé** — séparer deux houppiers voisins de même
   hauteur mais d'essences différentes — n'a **pas** été vérifié. C'est
   l'argument central du sujet et il reste une hypothèse.
4. **La stabilité du défaut entre peuplements** (§3.3).
5. Le pilote GPKG d'OTB 9.1.1, repris du brief sans re-test.

## 7. Ce que ce cadrage ne fait pas

Il ne remplace pas la voie CHM, qui reste l'algorithme d'emprise et le seul
capable de couvrir un massif. LSMS est une **délimitation alternative sur une
AOI**, à valider sur son propre argument (point 3 ci-dessus) avant d'être
proposée à un utilisateur.
