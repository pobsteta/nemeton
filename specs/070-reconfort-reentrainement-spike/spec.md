# Spec 070 — Spike de ré-entraînement RECONFORT et noyau Rust

> Mission 060 de nemetonplateforme ; décision : [ADR 0003](https://github.com/pobsteta/nemetonplateforme/blob/main/docs/adr/0003-noyau-rust-dans-nemeton.md)
> (noyau Rust dans nemeton, repli R pur). Statut : **spike**. Aucun changement de la
> production RECONFORT (spec 021, `R/reconfort_ingest.R`, `R/reconfort_postprocess.R`, R5).

## Ce que fait le spike

1. **Indices** — `reconfort_indices()` calcule CRswir et CRre par pixel
   (formules d'`iota2/external_features/custom_index.py`, RECONFORT amont, Apache-2.0 ;
   dénominateur nul → 1, NA propagés). Le calcul passe par le crate `src/rust/`
   (`extendr`) s'il est compilé ; sinon, ou avec `options(nemeton.rust = FALSE)`, par un
   repli R pur égal à 1e-12 près (`nemeton_rust_disponible()` dit lequel sert).
2. **Étiquettes** — `reconfort_etiquettes()` contrôle le format amont de `train_new_model/`
   (`dep_cor` ∈ {1, 2, 3}, jamais 0 ; `DEPERIS_pe` ∈ [0, 1] ; `id_unique` unique par année),
   recalcule la classe depuis `DEPERIS_pe` (< 0,20 saine ; 0,20 à 0,50 dépérissante ;
   > 0,50 très dépérissante), puis propage de Y-2 à Y+2 : saine en Y ⇒ saine en Y-1 et Y-2 ;
   dépérissante (2 ou 3) en Y ⇒ classe 2 en Y+1 et Y+2. Une observation réelle n'est jamais
   écrasée ; tout désaccord est listé (attribut `conflits`), et deux propagations en
   désaccord écartent la ligne au lieu de trancher.
3. **Masques** — `reconfort_masquer()` retire les pixels hors chênaie (couche fournie, BD
   Forêt v2 en pratique) et les coupes rases (`YYDDD`, raster ou polygones au format
   nemetonsar/SUFOSAT) pour toute année d'observation ≥ l'année de coupe ;
   `reconfort_coupe_decoder()` / `reconfort_coupe_encoder()` testent l'aller-retour date ↔ code.
4. **Apprentissage** — `reconfort_entrainer()` : `ranger` sur 36 pas de 10 jours × 2 indices
   par (placette, année), validation croisée **spatiale par blocs** (un bloc entier dans un
   seul pli ; aucune placette d'un bloc dans l'apprentissage de ce bloc), seed fixée ; rendu :
   modèle, matrice de confusion hors-pli, précision globale (et sur observations seules, les
   étiquettes propagées étant plus faibles). `reconfort_predire()` applique le modèle.
5. **Comparaison** — `reconfort_comparer_amont()` : accord pixel à pixel avec une carte de
   classes (celle du modèle v3 amont en pratique) et, avec `placettes`, accord de chaque
   carte avec des placettes de terrain tenues à l'écart.

Tout est testé sans réseau sur des jeux `synth_` (`tests/testthat/helper-reconfort-synth.R`).

## Ce qui manque (rien de ceci n'est établi par le spike)

- **Les notes DEPERIS réelles.** Aucune placette publique n'existe : la précision mesurée
  sur `synth_` ne dit rien du modèle sur le terrain. Le signal synthétique est net par
  construction.
- La carte de classes du modèle v3 amont (à fournir) et des placettes de terrain tenues à
  l'écart pour la comparer.
- La chaîne image : extraction des séries Sentinel-2 aux placettes, application du modèle à
  une zone, écriture de la carte (le spike s'arrête aux tables de séries).
- Le portage Windows du crate (le paquet s'y installe sans Rust).
- Le choix de la classe propagée pour « très dépérissante » : le spike propage la classe 2
  (le minimum garanti par la règle) ; à confirmer avec les notes réelles.

## Critère pour amender la spec 021

La spec 021 (§ 1.4) garde le modèle amont comme référence tant que le ré-entraînement n'a pas
fait mieux **sur du terrain**. Elle sera amendée si, sur des placettes de terrain tenues à
l'écart (jamais utilisées pour l'entraînement ni les blocs de validation), l'**accord du
modèle amont** avec les notes DEPERIS est établi et chiffré par
`reconfort_comparer_amont(..., placettes = )$terrain$accord_amont`, avec un intervalle de confiance
à calculer sur le nombre de placettes (le spike ne le calcule pas) ;
un modèle ré-entraîné ne le remplace que si son `accord_carte` sur les mêmes placettes est
supérieur, borne basse de l'intervalle comprise. Pascal fixe les seuils.

## Rust : ce qui est installé, ce qui est optionnel

`configure` compile `src/rust/` si `cargo` et `rustc` existent ; sinon, avec
`NEMETON_NO_RUST=1`, ou si la compilation échoue, il installe sans (repli R pur) et le dit.
`SystemRequirements` déclare Cargo et rustc comme optionnels. La CI installe la chaîne Rust
dans les trois jobs qui construisent le paquet. Les crates sont téléchargés à l'installation
(pas de `vendor/` : à ajouter avant un dépôt CRAN).
