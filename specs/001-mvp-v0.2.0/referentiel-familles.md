# Référentiel des 12 Familles d'Indicateurs - nemeton v0.2.0+

**Date**: 2026-01-05
**Version**: v0.2.0
**Source**: Journal Vivre en Forêt

---

## Vue d'ensemble

Le référentiel nemeton repose sur **12 familles d'indicateurs** correspondant chacune à une dimension concrète de la forêt. Chaque famille possède un code lettre unique et une double nomenclature (français/métaphorique).

---

## Les 12 Familles

### B – Biodiversité / V - Vivant

**Dimension**: Diversité des espèces (faune, flore, champignons), présence d'habitats variés (zones humides, lisières, bois mort, vieux arbres), continuités écologiques permettant les déplacements des espèces.

**Indicateurs clés**:
- B1: Présence d'habitats variés
- B2: Diversité structurelle
- B3: Connectivité écologique

---

### W – Water (eau) / I - Infiltrée

**Dimension**: Rôle de la forêt dans l'infiltration, le stockage et la restitution de l'eau : crues, étiages, protection des sources, filtration naturelle, qualité de l'eau.

**Indicateurs clés**:
- W1: Densité du réseau hydrographique
- W2: Couverture en zones humides
- W3: Indice topographique d'humidité (TWI)

**Statut v0.2.0**: ✅ Implémenté (US3 - Phase 5)

---

### A – Air (microclimat) / V – Vaporeuse

**Dimension**: Effet de la forêt sur la température, l'humidité, le vent et la qualité de l'air local : îlots de fraîcheur, humidification, piégeage des particules.

**Indicateurs clés**:
- A1: Couverture forestière (buffer 1 km)
- A2: Qualité de l'air (données ATMO)

**Statut v0.2.0**: ⏳ Planifié pour v0.3.0+

---

### F – Fertilité / R - Riche

**Dimension**: Santé biologique, chimique et physique des sols : matière organique, structure, porosité, activité biologique, capacité à porter des peuplements résilients.

**Indicateurs clés**:
- F1: Fertilité du sol (BD Sol)
- F2: Risque d'érosion (pente × couvert)

**Statut v0.2.0**: ✅ Implémenté (US4 - Phase 6)

---

### C – Carbone / E – Énergétique

**Dimension**: Stock de carbone aérien (tronc, branches, feuillage) et souterrain (racines, matière organique du sol), dynamique de stockage ou d'émission en fonction des pratiques de gestion.

**Indicateurs clés**:
- C1: Stock de biomasse aérienne (modèles allométriques)
- C2: Indice de vitalité NDVI (Sentinel-2)

**Statut v0.2.0**: ✅ Implémenté (US2 - Phase 4)

---

### L – Landscape (paysage) / E – Esthétique

**Dimension**: Qualité paysagère : composition des peuplements, diversité des structures, lisières, ouvertures, harmonies ou ruptures dans le paysage.

**Indicateurs clés**:
- L1: Fragmentation du paysage (métriques de taches)
- L2: Ratio lisière-surface
- L3: Intégration dans la Trame Verte et Bleue (TVB)

**Statut v0.2.0**: ✅ Partiel (L1, L2 - US5 Phase 7) | ⏳ L3 en v0.3.0+

---

### T – Trame / N - Nervurée

**Dimension**: Continuité forestière et paysagère : maillage de parcelles, corridors écologiques, connexion avec d'autres milieux (haies, ripisylves, bocage, zones humides).

**Indicateurs clés**:
- T1: Ancienneté de la couverture forestière
- T2: Changements d'occupation du sol (analyse temporelle)

**Statut v0.2.0**: ⏳ Planifié pour v0.3.0+ (US1 fournit l'infrastructure temporelle de base)

---

### R – Résilience / F - Flexible

**Dimension**: Capacité de la forêt à encaisser des chocs (sécheresse, tempêtes, maladies, pression de la faune) et à se rétablir sans basculer dans un état dégradé.

**Indicateurs clés**:
- R1: Risque incendie
- R2: Risque tempête
- R3: Risque sécheresse

**Statut v0.2.0**: ⏳ Planifié pour v0.3.0+

---

### S – Santé / O – Ouverte

**Dimension**: Contribution de la forêt au bien-être humain : qualité d'ambiance, possibilités de marche, d'immersion, de repos, accessibilité, sécurité pour les usagers.

**Indicateurs clés**:
- S1: Densité de sentiers
- S2: Accessibilité (distance aux routes)
- S3: Proximité des populations

**Statut v0.2.0**: ⏳ Partiel en v0.1.0 (indicator_accessibility existe) | Extension en v0.4.0+

---

### P – Patrimoine / R – Radicale

**Dimension**: Dimension patrimoniale et culturelle : vieux peuplements, arbres remarquables, traces de l'histoire humaine, liens avec les communautés locales.

**Indicateurs clés**:
- P1: Volume de bois sur pied
- P2: Productivité forestière
- P3: Proportion bois d'œuvre vs bois énergie

**Statut v0.2.0**: ⏳ Planifié pour v0.4.0+

---

### E – Éducation / E – Éducative

**Dimension**: Capacité de la forêt à accueillir des publics et à transmettre des savoirs : sentiers pédagogiques, panneaux, animations, accueils d'écoles, médiation.

**Indicateurs clés**:
- E1: Potentiel bois-énergie
- E2: Évitement d'émissions carbone (substitution)

**Statut v0.2.0**: ⏳ Planifié pour v0.4.0+

---

### N – Nuit / T – Ténébreuse

**Dimension**: Qualité de l'obscurité et du silence : faible pollution lumineuse, respect des cycles jour/nuit, espaces de nuit propices à la faune nocturne et à la contemplation (ciel étoilé, silence).

**Indicateurs clés**:
- N1: Distance aux infrastructures
- N2: Continuité de la couverture forestière
- N3: Indice composite de naturalité

**Statut v0.2.0**: ⏳ Planifié pour v0.3.0+

---

## Roadmap d'implémentation

### v0.2.0 (Actuel) - Fondations
- ✅ **Infrastructure temporelle** (US1)
- ✅ **Famille C** (Carbone/Énergétique): C1, C2
- ✅ **Famille W** (Water/Infiltrée): W1, W2, W3
- ✅ **Famille F** (Fertilité/Riche): F1, F2
- ✅ **Famille L** (Landscape/Esthétique): L1, L2

**Total**: 5 familles, 10 sous-indicateurs

---

### v0.3.0 - Extension Biodiversité & Risques
- ⏳ **Famille B** (Biodiversité/Vivant): B1, B2, B3
- ⏳ **Famille R** (Résilience/Flexible): R1, R2, R3
- ⏳ **Famille T** (Trame/Nervurée): T1, T2
- ⏳ **Famille A** (Air/Vaporeuse): A1, A2
- ⏳ **Famille N** (Nuit/Ténébreuse): N1, N2, N3

**Total cumulé**: 10 familles, 25 sous-indicateurs

---

### v0.4.0 - Extension Socio-Économique
- ⏳ **Famille S** (Santé/Ouverte): S1, S2, S3
- ⏳ **Famille P** (Patrimoine/Radicale): P1, P2, P3
- ⏳ **Famille E** (Éducation/Éducative): E1, E2
- ⏳ **Famille A** (complétion): A3, A4
- ⏳ **Famille L** (complétion): L3 (TVB)

**Total cumulé**: 12 familles, 36 sous-indicateurs

---

### v0.5.0 - Dashboard & Intégration Complète
- ⏳ Shiny dashboard
- ⏳ Analyse d'incertitude
- ⏳ Export multi-formats
- ⏳ Tutoriels interactifs

**Total**: Framework complet opérationnel

---

## Utilisation dans le code

### Accès aux noms de familles

```r
# Obtenir le nom complet d'une famille
nemeton:::get_family_name("C")
# [1] "Carbone/Énergétique"

nemeton:::get_family_name("W")
# [1] "Water/Infiltrée"

# Détecter la famille d'un indicateur
nemeton:::detect_indicator_family("C1")
# [1] "C"

nemeton:::detect_indicator_family("W3_norm")
# [1] "W"
```

### Messages bilingues

Le système i18n (`R/i18n.R`) gère automatiquement les messages en français et anglais :

```r
# Français
nemeton::nemeton_set_language("fr")
# → Messages en français avec noms de familles

# Anglais
nemeton::nemeton_set_language("en")
# → Messages en anglais avec noms de familles
```

---

## Références

- **Source**: Journal Vivre en Forêt, classification des 12 dimensions de la forêt
- **Constitution nemeton**: `.specify/memory/constitution.md`
- **Spécification v0.2.0**: `specs/001-mvp-v0.2.0/spec.md`
- **Plan d'implémentation**: `specs/001-mvp-v0.2.0/plan.md`
- **Modèle de données**: `specs/001-mvp-v0.2.0/data-model.md`

---

## Notes d'implémentation

### Conventions de nommage

**Fonctions indicateurs**:
- Format: `indicator_<famille>_<nom>()` en minuscules
- Exemples: `indicator_carbon_biomass()`, `indicator_water_twi()`

**Codes indicateurs**:
- Format: `<LETTRE><CHIFFRE>` en majuscules
- Exemples: `C1`, `W3`, `F2`, `L1`

**Colonnes normalisées**:
- Format: `<code>_norm` pour valeurs normalisées 0-100
- Exemples: `C1_norm`, `W3_norm`

**Scores de familles**:
- Format: `score_<famille_lowercase>`
- Exemples: `score_carbon`, `score_water`, `score_soil`

### Extensibilité

Le système est conçu pour ajouter facilement de nouvelles familles et indicateurs :

1. Ajouter la fonction dans `R/indicators-families.R`
2. Ajouter les messages dans `R/i18n.R` (en/fr)
3. Mettre à jour `get_family_name()` dans `R/utils.R` si nouvelle famille
4. Générer la documentation : `devtools::document()`
5. Écrire les tests dans `tests/testthat/test-indicators-families.R`

---

**Document vivant** - Mis à jour au fur et à mesure de l'évolution du package nemeton.
