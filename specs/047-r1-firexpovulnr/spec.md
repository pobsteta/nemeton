# Spec 047 — R1 : `firexpovulnR` comme source de l'exposition au feu ?

> **Statut** : étape préalable **faite** (comparaison à l'aveugle, 2026-10-05) ;
> **décision à prendre par Pascal** sur l'ADR-016 (« Proposé », 2026-08-20,
> `briefs/vers-nemetonplateform/ADR-016_R1_incendie_firexpovulnR.md`).
> Aucun câblage dans le cœur tant que l'ADR n'est pas tranché.
> **Script** : `specs/047-r1-firexpovulnr/comparaison.R` (lecture seule des
> caches projet, `firexpovulnR` 0.34.0, cœur 0.212.2).

## 1. Ce que l'ADR-016 demandait avant tout câblage

L'ADR s'appuie sur une revue **documentaire** de `firexpovulnR` et impose une
comparaison à l'aveugle **avant** le câblage, en prévenant : « si
`fev_exposure()` sature comme l'actuel, le gain se réduit aux seuils sourcés et
à la provenance, ce qui ne justifierait pas le même effort ». C'est l'objet de
cette spec.

Contexte nouveau depuis l'ADR : jusqu'à la 0.212.0, le chemin `fireexposuR` du
cœur **n'aboutissait sur aucun projet** (MNT en EPSG:4326 → allocation de
~59 600 Go, repli silencieux ; corrigé le 2026-10-04). Les R1 « mesurés » que
l'ADR critique venaient donc presque tous du repli. La comparaison ci-dessous
est la première sur le chemin réel.

## 2. Protocole

Six projets dont les caches portent parcelles, BD Forêt et MNT : Fordead,
Reconfort, ForetAccess, Dabo, Couchey, Aumur. Grille 30 m en Lambert-93,
anneau de 500 m (« ember », Beverly et al.). Moyenne par parcelle, × 100.

| Chemin | Combustible | Calcul |
|---|---|---|
| **A** | BD Forêt binaire, hors-forêt = 0 | cœur actuel : `fireexposuR::fire_exp()` (composante exposition de R1) |
| B | BD Forêt binaire, hors-forêt = NA | `fev_exposure(fev_fuel_binary())` |
| C | BD Forêt graduée, hors-forêt = NA | `fev_exposure(fev_fuel_availability())` |
| **D** | BD Forêt + CORINE 2018, binaire | `fev_fuel_merge()` puis comme B |
| **E** | BD Forêt + CORINE 2018, gradué | `fev_fuel_merge()` puis comme C |

B et C ne sont pas comparables : sur BD Forêt seule, `firexpovulnR` tient le
hors-forêt pour « rien de cartographié » (NA), donc ne regarde que des cellules
de forêt (B = 100 partout, nombreuses parcelles NA, aucune à Aumur). La
comparaison loyale est **A / D / E**.

`millesime = NA` (vintage BD Forêt non connu des caches, déclaré comme tel).
Pas de validation contre surfaces brûlées (`fev_validate()`) : aucune couche
d'incendies sur ces projets, et l'est de la France en compte peu.

## 3. Résultats

Part des parcelles à ≥ 95 (« saturées ») et dispersion :

| Projet | n | A moy (ét) | A ≥ 95 | D moy (ét) | D ≥ 95 | E moy (ét) | E plage | ρ A~D | ρ A~E |
|---|---|---|---|---|---|---|---|---|---|
| Fordead | 30 | 99,6 (0,4) | **100 %** | 100 (0) | **100 %** | 89,3 (4,0) | 78-94 | — | 0,13 |
| Reconfort | 28 | 94,1 (9,9) | 71 % | 94,4 (9,5) | 71 % | 59,3 (5,2) | 45-71 | 0,87 | 0,47 |
| ForetAccess | 30 | **échec** | — | 97,8 (3,8) | 83 % | 77,8 (7,2) | 65-89 | — | — |
| Dabo | 4 | 98,5 (1,8) | **100 %** | 99,3 (1,5) | **100 %** | 89,0 (2,9) | 86-92 | 0,77 | -0,20 |
| Couchey | 23 | 83,0 (16,4) | 30 % | 85,1 (16,0) | 39 % | 57,2 (12,4) | 29-77 | 0,96 | 0,91 |
| Aumur | 13 | 51,5 (23,0) | 0 % | 54,2 (22,4) | 0 % | 32,5 (13,4) | 13-53 | 0,98 | 0,98 |

(ρ = Spearman entre parcelles ; « — » : variance nulle ou chemin en échec.)

## 4. Lecture

1. **`fev_exposure()` binaire = l'actuel.** D reproduit A (ρ 0,77 à 0,98) et
   **sature exactement pareil** sur massif continu (Fordead, Dabo : 100 % des
   parcelles ≥ 95). La fusion CORINE change peu les valeurs : le hors-forêt de
   ces massifs est peu combustible. Sur la métrique d'exposition elle-même,
   `firexpovulnR` n'apporte rien.
2. **La désaturation vient du combustible gradué (E), dont les poids ne sont
   pas sourcés.** La documentation de `fev_fuel_availability()` le dit :
   « *The weights are conventional, not sourced* ». Là où A sature, l'ordre E
   n'a plus de rapport avec l'exposition (Fordead ρ = 0,13, Dabo ρ = -0,20) :
   il classe les parcelles selon le **type de peuplement** de leur voisinage,
   pas selon la quantité de combustible. C'est le défaut que l'ADR reproche au
   repli actuel (« seuils non sourcés ») — déplacé, pas résolu.
3. **Là où A discrimine déjà** (Couchey, Aumur), E garde l'ordre (ρ 0,91-0,98)
   et abaisse le niveau d'un tiers : changement d'échelle, pas d'information.
4. **Robustesse : un point pour `firexpovulnR`.** Sur ForetAccess (petite
   emprise), `fireexposuR::fire_exp()` refuse le calcul (« *Extent of hazard
   raster too small* ») et R1 passe au repli ; `fev_exposure()` aboutit
   (`trim`, `na_rm`). Le repli est tracé depuis la 0.212.0
   (`r1_status = "fallback_fire_exp_failed"`).
5. **Validation absente.** Le critère d'acceptation de l'ADR
   (`fev_validate()` contre surfaces brûlées) n'est pas exerçable sur ces
   projets. Les Maures, prévus par l'ADR, n'ont pas de projet en cache.

## 5. Recommandation (à trancher par Pascal)

**Ne pas adopter `firexpovulnR` comme source principale de R1 en l'état.**
L'hypothèse de l'ADR (« la méthode sature, `firexpovulnR` la désature avec des
seuils sourcés ») ne tient pas : la métrique binaire sature à l'identique, et
la seule voie qui désature repose sur des poids conventionnels. Le gain se
réduit à la provenance et à la robustesse sur petite emprise : c'est
exactement le cas où l'ADR jugeait l'effort injustifié.

Options, de la moins à la plus coûteuse :

1. **Statu quo du cœur 0.212** : `fire_exp` + modulation pente/climat
   (0,5 / 0,25 / 0,25), méthode tracée dans `r1_status`. Passer l'ADR-016 en
   « Rejeté » avec renvoi à cette spec.
2. **Emprunt ciblé** : garder `fireexposuR`, mais prendre de `firexpovulnR` le
   seul gain mesuré — le calcul sur petite emprise (ForetAccess). Petit
   chantier dans le cœur, sans nouvelle dépendance.
3. **Rouvrir après validation** : si un projet méditerranéen avec surfaces
   brûlées (Maures) entre en cache, rejouer `comparaison.R` avec
   `fev_validate()` ; seul un gain de validation (AUC) justifierait le câblage
   et des poids de combustible.

## 6. Reproduire

```bash
Rscript specs/047-r1-firexpovulnr/comparaison.R
```

Lit `~/.local/share/nemeton/projects/*/` (parcelles, BD Forêt, MNT en cache),
télécharge CORINE 2018 par `fev_fetch_corine()` (WFS, cache de
`firexpovulnR`). Rien n'est écrit dans les projets.
