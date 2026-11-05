# Brief `maestronemeton` — MAESTRO en extracteur de représentations (chantier B)

> **Statut** : **préavis**. Le chantier B n'a pas encore de spec cœur ; il
> réutilise les fonctions génériques de la spec 064 (`embedding_summary()`,
> `distance_reference()`), validées le 2026-11-05 (spec 064). Rien à coder
> côté `maestronemeton` avant la release cœur qui les livre.
> **Origine** : brief « Modèles de fondation… » du 2026-11-05, chantier B.

## Ce qui est demandé à `maestronemeton`

1. **`maestro_embed(aoi, modalities = c("ortho_rvbi", "mnt", "s2", "s1"))`**
   → raster d'embeddings par patch de 50 m. Dimension native 768, réduite à
   64 par une **PCA ajustée une fois** sur un corpus BFC et **versionnée**
   dans `inst/extdata/` (même exigence de stabilité que le dictionnaire de
   clusters AEF, spec 064 D-6 : une PCA réajustée par projet rendrait les
   embeddings incomparables).
2. **Normalisation globale par jeu de données.** Corriger
   `_normaliser_mnt()`, qui normalise en min-max **par batch** (noté dans le
   DEV_PLAN de `maestronemeton`) : deux batches d'un même projet n'ont pas la
   même échelle.
3. **Sortie** consommée par le cœur comme un SpatRaster multi-bandes, avec
   `attr(, "embedding_source") = "maestro"` et un fichier de provenance (poids,
   version, PCA). Cache adressé par contenu (emprise + modèle + version des
   poids), comme FAST.
4. **BD Forêt v3** : `map_bdforet_essence()` (cœur) devra accepter la
   nomenclature v3 ; `maestronemeton` documente la correspondance de ses
   13 classes PureForest vers v3, et la migration des 11 classes BFC.
5. **Fusion ortho + LiDAR HD** : le MNH LiDAR comme modalité du fine-tuning
   PureForest (déjà au DEV_PLAN) ; la concaténation avec ForPT viendra au
   chantier C.

## Ce que le cœur fera (spec à écrire, après 064)

`probe_indicator(embedding, units, target)` : régression ridge de l'embedding
vers chaque indicateur calculable, validation croisée spatiale par blocs,
table `indicateur × R²_probe` (« ce que les modèles voient »). Elle sera
appliquée à AEF comme à MAESTRO.

## Question à `maestronemeton`

La dimension 768 est-elle celle du token de classe ou une moyenne des tokens
de patch ? Le choix change ce que « embedding du patch de 50 m » veut dire.
