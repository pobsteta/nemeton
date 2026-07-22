# Brief cœur — Places de dépôt pour le moteur câble-mât (`potentiel_cable`)

> **Destinataire** : session dédiée `/home/pascal/dev/nemeton` (et/ou `foretaccess`).
> **Émetteur** : session app `nemetonshiny` (règle 12 : je ne touche pas au cœur).
> **But** : débloquer l'exposition du moteur câble-mât dans l'onglet Accessibilité
> de l'app. Le blocage n'est pas dans l'app — c'est l'absence d'une **couche de
> places de dépôt** exploitable, dont la définition est du métier.

## 1. État constaté côté app

- `foretaccess::potentiel_cable()` est prêt, noyau Rust actif
  (`cablehelp_version()` = 0.1.0). Signature :
  ```r
  potentiel_cable(pre, config = foretaccess_config(),
                  departs = NULL, write_dir = NULL, bord = NULL)
  ```
- Retour `foretaccess_cable` : `$accessibilite` (raster catégoriel
  accessible_cable / non_accessible / hors_foret), `$longueur_ligne`,
  `$azimut_ligne`, `$nb_supports`, `$lignes` (data.frame candidates :
  `depart`, `azimut`, `longueur_m`, `surface_ha`, `sens`, `supports`,
  `volume_m3`, `ipc`), `$recap`, `$grid`, `$config`, `$fichiers`.
- **Intégration app triviale** : même forme de retour que `skidder`/`porteur`
  (`$accessibilite` + `$recap`), donc le moteur se branche en une ligne dans
  `run_accessibility()` (`engine_fun$cable <- foretaccess::potentiel_cable`).
  **Rien ne manque côté app** sauf la couche `departs`.

## 2. Le vrai blocage : `departs = NULL` est inutilisable

Mesuré sur AOI Chastel-Nouvel (projet réel, 2,65 × 2,85 km, MNT 5 m
530×571 px, desserte ≈ 806 km / 3 299 tronçons) :

- Avec `departs = NULL`, `foretaccess` **retombe sur toute la desserte** et
  avertit lui-même :
  > « Aucune couche de places de dépôt (`departs`) : le balayage part des
  > **10 681 cellules** de desserte. La couverture câble sera **optimiste** —
  > une piste n'accueille pas un câble-mât. »
- Coût : 10 681 départs × 360 azimuts (`config$cable$pas_angulaire_deg = 1`)
  ≈ **3,8 M rayons**. Le run **n'a pas fini en > 1 h**, contre ~2 s pour
  `preprocess()` et quelques secondes par moteur terrestre.
- **Double problème** : (a) inutilisable en interactif, (b) résultat
  sciemment faux (une piste ≠ une place de dépôt câble).

Conclusion : impossible d'exposer un bouton « câble » tant qu'on n'a pas une
vraie couche de départs, restreinte et pertinente.

## 3. Décision demandée au cœur

**Qu'est-ce qui qualifie une place de dépôt (landing) ?** C'est du métier
forestier → doit vivre dans `foretaccess` (ou `nemeton`), pas dans l'app
(règle 1). Trois options, ma recommandation en premier :

### Option A (recommandée) — helper d'acquisition dans `foretaccess`
Une fonction exportée qui dérive des places de dépôt candidates pour une AOI,
avec une règle documentée. Ébauche de signature :
```r
acquire_places_depot(aoi, desserte = NULL, crs = 2154,
                     cache_dir = tempdir(), ...) -> sf (points ou polygones)
```
Règle métier à arrêter (exemples de critères Sylvaccess / pratique ETF) :
- élargissements et aires de retournement de la desserte (déjà calculés en
  partie par `flag_dfci()` — heuristiques emprise/traversée/retournement) ;
- intersections / culs-de-sac de pistes accessibles aux grumiers ;
- bande carrossable de largeur/pente compatibles (réutiliser `terrain_roulable`
  / `zone_roulable_connectee` déjà exportés) ;
- éventuel filtrage par `classe` de desserte (route empierrée vs piste).

La sortie porte un champ `cable` (1/0) : `potentiel_cable()` ne retient déjà
que les entités `cable != 0` (équivalent attribut CABLE de Sylvaccess). Ainsi
l'app appelle `acquire_places_depot()` puis
`potentiel_cable(pre, departs = places)` sans logique métier.

### Option B — la couche vient du projet `nemeton`
Si les places de dépôt sont une donnée terrain/gestion (saisies, importées),
les exposer dans le modèle projet `nemeton` et documenter le format attendu par
`departs` (sf lignes/polygones/points + champ `cable`). L'app les passerait
telles quelles.

### Option C (dernier recours) — saisie/​import côté app
L'utilisateur dessine/importe ses places. Acceptable en complément, mais ne
doit pas être le **seul** chemin : sans dérivation automatique, l'onglet reste
vide pour la majorité des projets. À ne retenir que si A et B sont hors scope.

## 4. Garde-fous performance (à cadrer avec la couche `departs`)

Même avec de vraies places de dépôt, borner le coût :
- **Nombre de départs** : c'est le facteur dominant (coût ∝ n_départs × azimuts).
  Documenter un ordre de grandeur cible (ex. quelques centaines de départs max
  sur une AOI de gestion) et/​ou un garde-fou (avertissement au-delà de N).
- **`pas_angulaire_deg`** : 1° = 360 rayons/départ. Confirmer si un pas plus
  grossier (2–5°) est acceptable pour une carte de potentiel, exposable en
  paramètre.
- **`longueur_max_m`** (750 m) et `nb_supports_max` (3) : confirmer les valeurs
  par défaut ou les rendre pilotables.
- Indiquer si `potentiel_cable()` sait **tuiler** (`bord` est « réservé Lot 7,
  ignoré ici ») — utile pour les grandes AOI.

## 5. Livrables attendus de la session cœur

1. Décision A / B / C +, si A, la fonction `acquire_places_depot()` exportée
   (avec tests + doc Rd, règle métier explicite).
2. Bornes/​defaults perf documentés (§4).
3. Le cas échéant, bump cycle dev `foretaccess`/`nemeton` + entrée `PLAN.md`
   cœur (chantier câble-mât).
4. Signaler à l'app la version exposant la fonction : l'app posera alors
   `Imports: foretaccess (>= X.Y.Z)` et branchera le moteur (une ligne dans
   `run_accessibility()` + case à cocher opt-in + clés i18n déjà esquissées).

## 6. Ce que l'app fera une fois la couche disponible (pour info)

- `engine_fun$cable <- foretaccess::potentiel_cable` dans `run_accessibility()`,
  appelé avec `departs = <places>`.
- Case à cocher **non pré-cochée** (opt-in) + libellé d'avertissement « calcul
  long » — le coût reste supérieur aux moteurs terrestres.
- Couche carte + légende (`accessible_cable` a déjà une couleur sémantique
  prévue), export GPKG. Couleurs/i18n déjà prototypés côté app, réintégrables
  en un patch une fois le cœur livré.
