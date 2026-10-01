# ADR-016 — Estimation sur petits domaines (Fay-Herriot) pour les références IFN

> **Statut : Proposé (draft cœur).** Rédigé dans `nemeton/specs/`, à reporter dans
> `platform_nemeton/docs/` (dépôt canonique des ADR) une fois accepté.
>
> - **Date** : 2026-10-01
> - **Décideur** : Pascal Obstétar
> - **Contexte technique** : spec 054, nemeton ≥ v0.199.2
> - **ADR liés** : [[ADR-002]] (pas de raster en base), [[ADR-009]] (dépendances
>   vers le cœur), [[ADR-011]] (NDP / Fibonacci)
> - **Amende** : rien. L'ADR introduit une méthode d'estimation, pas de niveau NDP.

## Contexte et problème

Le cœur tire déjà des références de l'IFN par domaine : volume sur pied et
prélèvement par essence × SER (spec 040). Il les tire par **moyenne directe** et un
**repli en escalier** SER → GRECO → national sous un seuil de placettes
(`min_plac`). Deux défauts :

1. Le repli est discontinu : une SER à 29 placettes est jetée au profit de la
   GRECO, une SER à 30 est gardée telle quelle avec sa variance.
2. Aucune valeur ne porte son incertitude.

De plus, le cœur n'a **aucun flux de production** mesuré : P2 lit une table ONF de
2021, E1 récolte 2 % du stock.

Onwunji et al. (2026, Ann. For. Sci. 83:46) montrent sur la Bourgogne-Franche-Comté
qu'un estimateur Fay-Herriot (FH) au niveau du domaine, avec des covariables lidar
spatial agrégées, améliore la précision de la production IFN d'un facteur 1,2 à
plus de 4. L'efficacité relative est supérieure à 1 dans **tous** les domaines.

## Décision

1. **Le FH devient la méthode d'estimation de référence** pour toute valeur IFN
   publiée par domaine dans le cœur. On commence par la production (PG, PV, spec
   054), puis on l'étend au volume (`completer_volume_ifn(methode = "fay_herriot")`).
   La moyenne directe et la cascade restent disponibles, et restent le **défaut**
   tant qu'un cas réel n'a pas validé le FH.

2. **Implémentation maison, sans dépendance d'exécution.** Les paquets CRAN de
   référence (`sae`, `JoSAE`, `emdi`) sont sous GPL-2 stricte, et `emdi` tire une
   quinzaine de dépendances. `sae` n'est admis qu'en `Suggests`, pour un test
   d'égalité numérique.

3. **Chaque valeur publiée porte sa nature** (`direct` / `fay_herriot` /
   `synthetique`), son γ et sa MSE. Une estimation **synthétique** ne se présente
   jamais comme une mesure : c'est le principe de la provenance ligne à ligne de la
   spec 040 D8, étendu.

4. **Covariables sans circularité, choisies sur critères fixés à l'avance.** On
   n'utilise jamais un produit calé sur l'IFN pour estimer un attribut IFN : la
   hauteur FORMS-T (apprise sur GEDI) est admise, mais **pas** le volume ni la
   biomasse FORMS-T. Deux jeux sont mis en concurrence : GEDI L2A brut, comme
   l'article, et FORMS-T hauteur + MNT. Ils sont départagés sur l'efficacité
   relative, la validation croisée « un domaine en moins » et le I de Moran des
   résidus (spec 054 §5.b). En cas d'égalité, FORMS-T l'emporte, car sa couverture
   est continue. GEDI ne vit que dans `data-raw/`, jamais à l'exécution.

5. **Le NDP n'est pas touché.** Une référence de domaine, même précise, reste une
   donnée publique de NDP 0 du point de vue de l'UGF (règle 7). La RSE est un
   attribut d'affichage, elle n'entre pas dans la confiance φ.

6. **Précalcul hors paquet.** L'agrégation des covariables se fait dans
   `data-raw/` sur la France entière, dans un cgroup plafonné. Le paquet n'embarque
   que des CSV (ADR-002).

## Conséquences

- **Positives** :
  - un flux de production mesuré pour P2, E1/E2 et le ratio
    prélèvement/production ;
  - un repli continu pour P1/C1 ;
  - une incertitude affichable ;
  - un moteur `estimer_fay_herriot()` réutilisable pour d'autres attributs (G, Dg,
    puis domaines utilisateur : UT ONF, massifs).
- **Négatives** :
  - le FH **dépend d'un modèle**. Si la relation covariables → attribut est mal
    spécifiée, il peut être biaisé là où le direct ne l'est pas (Kangas et al.
    2025). C'est atténué par la publication de γ et de `nature`, et par la
    convergence vers le direct quand n croît ;
  - un moteur statistique de plus à maintenir et à tester ;
  - la production en volume (PV) repose sur une hypothèse de croissance en hauteur
    (spec 054 D1), contrairement à PG, qui est exacte.
- **Neutres** : aucun impact sur `nemetonshiny` tant qu'un brief n'est pas émis.
  Les signatures existantes gardent leur défaut.

## Alternatives écartées

- **Garder la cascade seule** : pas d'incertitude, discontinuité conservée, et pas
  de flux de production.
- **Estimateurs assistés par modèle (GREG)** : sans biais sous le plan de sondage,
  mais exigent un échantillon suffisant **dans chaque domaine**, ce qui est
  précisément ce qui manque. Le FH emprunte de la force aux autres domaines.
- **Modèles au niveau de l'unité (placette ↔ pixel)** : plus précis en principe,
  mais demandent les coordonnées exactes des placettes. Les coordonnées publiques
  sont floutées : c'est inapplicable avec des données ouvertes.
- **`sae` / `JoSAE` en `Imports`** : licence GPL-2 stricte et dépendance pour
  environ 150 lignes de calcul.
