# Tableau récapitulatif des 31 indicateurs par NDP

> Document de référence — Néméton v0.14.1.9000
>
> Pour chaque indicateur : formule synthétique et données d'entrée par Niveau De Précision (NDP 0 à 4).

---

## Rappel des niveaux NDP

| NDP | Nom | Fibonacci | Confiance φ | Sources de données cumulatives |
|-----|-----|-----------|-------------|-------------------------------|
| 0 | Découverte | 1 | 8.3 % | Sentinel-2, WorldClim, BD TOPO, MNT 25 m (données publiques) |
| 1 | Observation | 1 | 16.7 % | + IGN RGE ALTI, BD ORTHO, LiDAR HD |
| 2 | Exploration | 2 | 33.3 % | + Drone RGB, LiDAR drone |
| 3 | Diagnostic | 3 | 58.3 % | + Inventaire terrain complet |
| 4 | Jumeau | 5 | 100 % | + Scanner terrestre, modèle 3D |

**Principe** : les 12 familles sont toujours calculées ; seule la **précision** augmente avec le NDP. Le mécanisme est un **fallback par priorité** — la meilleure source disponible est choisie automatiquement.

---

## B — Biodiversité

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| B1 | Protection | 0.7 × couverture_pondérée + 0.3 × diversité_statuts. Poids : RNN/APB=1.0, Natura 2000=0.6, PNR/ZNIEFF2=0.3 | INPN WFS (non implémenté → 0 %) | INPN WFS | + vérification drone des limites | Relevé terrain des statuts | Jumeau numérique complet |
| B2 | Structure | Shannon sur strates/âges/essences (terrain) → SD hauteur MNH (LiDAR) → CV du NDVI (satellite) | CV du NDVI Sentinel-2 | SD hauteur LiDAR MNH | SD hauteur LiDAR drone | Shannon strates + classes d'âge terrain | Modèle 3D complet |
| B3 | Connectivité | 0.7 × score_global (cohésion, coût, graphe, kernel) + 0.3 × connectivité_locale | Distance euclidienne simple | + distance-coût + graphe (igraph) | + analyse kernel (adehabitatHR) | Emprise forestière vérifiée terrain | Réseau complet modélisé 3D |

---

## C — Carbone & Vitalité

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| C1 | Biomasse carbone | Allométrie (terrain) → AGB = 2.5 × (pzabove2/100) × zmean^1.5 × 0.47 (LiDAR) → NDVI × 150 (satellite) | NDVI × 150 (Sentinel-2) | LiDAR MNH ou BD Forêt V2 + allométrie par défaut | LiDAR drone MNH | Inventaire terrain : essence, âge, densité → allométrie espèce | Scanner terrestre → modèle allométrique précis |
| C2 | NDVI vitalité | Moyenne zonale du NDVI par parcelle (0–1) | NDVI Sentinel-2 (10–20 m) | NDVI Sentinel-2 | NDVI drone haute résolution | NDVI + vigueur terrain | NDVI + scan spectral détaillé |

---

## W — Eau & Régulation

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| W1 | Réseau hydrographique | densité = longueur_cours_eau / surface + bonus_proximité (< 500 m) | BD TOPO réseau hydro | BD TOPO réseau hydro | + drainage LiDAR drone | Relevé terrain des cours d'eau | Hydrologie complète modélisée |
| W2 | Zones humides | min(couverture_eau_BD_TOPO + couverture_TWI>12 + couverture_OSO, 100) | OSO + TWI terra D8 (MNT 25 m) | BD TOPO surfaces eau + TWI GRASS (LiDAR) | Détection drone des zones humides | Cartographie terrain des zones humides | Inventaire complet modélisé |
| W3 | TWI | TWI = ln(SCA / tan(pente)). GRASS (préféré) ou terra D8 (fallback) | TWI terra D8 sur MNT 25 m | TWI GRASS sur LiDAR HD | TWI GRASS sur LiDAR drone | TWI vérifié terrain | MNT très haute résolution scanner |

---

## A — Air & Microclimat

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| A1 | Couverture forestière | % pixels forêt dans buffer 1 000 m (classes OSO 16-18) | OSO 30 m | BD TOPO + OSO | Ortho drone | Relevé terrain couverture | Ortho précision scanner |
| A2 | Qualité air | ATMO IDW (direct) ou proxy distance routes pondéré par type de voie | Proxy BD TOPO routes | Proxy BD TOPO routes | Proxy routes amélioré | Stations ATMO IDW (NO₂ + PM₁₀) | Réseau ATMO complet + capteurs |

---

## F — Fertilité des sols

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| F1 | Fertilité | Extraction raster ou moyenne pondérée par surface (vecteur sol) → normalisation 0–100 | Raster sol public (si disponible) | Raster sol + BD Sol vecteur | Idem | Relevé pédologique terrain | Analyse sol complète |
| F2 | Érosion | (TWI_norm + pente_norm) / 2. TWI [2.5–10] → [0–100], pente [0°–45°] → [100–0] | TWI D8 + pente sur MNT 25 m | TWI GRASS + pente sur LiDAR HD (1 m) | TWI + pente sur LiDAR drone | Vérification terrain | MNT scanner très haute résolution |

---

## L — Paysage

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| L1 | Sylvosphère (effet lisière) | 0.30 × géométrie (Shape Index) + 0.40 × contraste matrice (OSO) + 0.30 × exposition (vent NASA POWER + soleil) | OSO 30 m + NASA POWER vent | Idem | Occupation du sol drone | Relevé terrain des lisières | Modèle 3D complet des lisières |
| L2 | Fragmentation | (COHESION + AI) / 2 via landscapemetrics → fallback : 100 / Shape Index | OSO 30 m (si landscapemetrics disponible) | Idem | Occupation du sol drone haute résolution | Vérification terrain | Modèle paysager 3D |

---

## T — Dynamique temporelle

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| T1 | Ancienneté | BD Forêt TFV (âge estimé par type) → colonne âge directe → année d'installation → proxy NDVI → défaut 50 ans | Défaut 50 ans ou proxy NDVI (20 + (NDVI−0.2)/0.6 × 100) | BD Forêt V2 TFV (âge estimé par essence) | Idem + drone | Inventaire terrain : âge réel des peuplements | Dendrochronologie / scanner |
| T2 | Changement | Colonne N2 (continuité) → T1 capé à 100 → défaut 50 | Défaut 50 | Dérivé de T1 ou N2 | Idem | Dérivé de T1 terrain | Analyse temporelle scanner |

---

## R — Risques & Résilience

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| R1 | Feu | fireexposuR (BD Forêt, dist. 500 m) → fallback : ⅓ pente + ⅓ inflammabilité espèce + ⅓ climat (T°/précip) | Fallback : pente MNT 25 m + NDVI proxy + climat WorldClim | + BD Forêt + fireexposuR | Drone + pente LiDAR | Inventaire terrain espèces → inflammabilité réelle | Modèle feu complet 3D |
| R2 | Tempête | microclima::windcoef (si dispo) → fallback : exposition vent × (0.6 × pente + 0.4 × TRI) | Pente + TRI + aspect sur MNT 25 m, vent NASA POWER | LiDAR HD pente + TRI | LiDAR drone | microclima si disponible + terrain | Modèle aérodynamique 3D |
| R3 | Sécheresse | 0.6 × climat (SPEI-3 Hargreaves) + 0.4 × topo (0.4 × aspect_sud + 0.3 × pente + 0.3 × TWI inversé) | Climat simulé + TWI D8 MNT 25 m | + TWI GRASS LiDAR HD | + TWI drone | Données climatiques terrain + TWI vérifié | Modèle hydrique complet |
| R4 | Abroutissement | 0.35 × appétence (BD Forêt) + 0.30 × vulnérabilité (MNH) + 0.20 × lisière + 0.15 × pression gibier | BD Forêt appétence + défaut vulnérabilité 50 + lisière géométrique + défaut gibier 50 | + LiDAR MNH (hauteur → vulnérabilité) | + MNH drone | Inventaire terrain : espèces réelles + dégâts observés | Modèle complet pression faune |

---

## S — Social & Usages

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| S1 | Distance routes | Distance euclidienne moyenne parcelle → réseau routier (rasterisation + terra::distance) | BD TOPO routes + MNT 25 m | BD TOPO + LiDAR HD (1 m) | Idem | Relevé terrain des accès | Modèle d'accessibilité 3D |
| S2 | Distance bâti | Distance euclidienne moyenne parcelle → bâtiments (rasterisation + terra::distance) | BD TOPO bâti + MNT 25 m | BD TOPO + LiDAR HD (1 m) | Idem | Relevé terrain | Modèle 3D |
| S3 | Population | Proxy : surface buffer × 100 hab/km² (buffers 5/10/20 km) | Proxy densité 100 hab/km² | Idem | Idem | INSEE Carroyage 1 km/200 m (infrastructure prête, non implémenté) | INSEE + données locales précises |

---

## P — Production & Économie

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| P1 | Volume bois | V = a × DBH^b × H^c (tarifs IFN par espèce) × densité → m³/ha | Non calculable (pas de DBH) → NA | LiDAR : hauteur estimée → volume approché | Drone LiDAR : DBH/hauteur estimés | Inventaire terrain : DBH, hauteur, densité mesurés | Scanner terrestre : mesures exactes |
| P2 | Station (productivité) | Lookup table ONF/IFN : espèce × fertilité × climat → accroissement m³/ha/an | Données climat WorldClim + sol par défaut | Idem | Idem | Fertilité terrain + espèce inventoriée | Classification station complète |
| P3 | Qualité bois | 0.4 × forme + 0.4 × diamètre + 0.2 × défauts | Non calculable → défauts 70/85 | LiDAR : forme estimée | Drone : forme + défauts visuels | Inventaire terrain : forme, DBH, défauts notés | Scanner : forme 3D précise |

---

## E — Énergie & Climat

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| E1 | Bois-énergie | Résidus = volume × 2 %/an × 30 % × densité bois × 0.5 DM + taillis (2 t DM/ha/an) | Dépend de P1 (NA si P1 indisponible) | LiDAR volume → résidus estimés | Drone volume → résidus | Inventaire terrain volume → résidus précis | Volume scanner exact → résidus précis |
| E2 | Évitement carbone | E1 × 4 500 kWh/t DM × facteur ADEME (0.222 kgCO₂eq/kWh par défaut) | Dépend de E1 | Idem E1 | Idem E1 | Facteurs ADEME + volume terrain | Idem + substitution matériau |

---

## N — Naturalité

| Code | Indicateur | Formule synthétique | NDP 0 | NDP 1 | NDP 2 | NDP 3 | NDP 4 |
|------|-----------|---------------------|-------|-------|-------|-------|-------|
| N1 | Distance infrastructures | 0.40 × dist_routes + 0.35 × dist_bâti + 0.25 × dist_urbain. Normalisation : 0 m=0, 2 000 m+=100 | BD TOPO routes + bâti | Idem | Idem | Vérification terrain | Modèle 3D |
| N2 | Continuité forestière | Ancienne forêt (>1850) : 60 + taux×40 ; forêt récente : 30 + taux×30 ; hors forêt : 15 | BD Forêt V2 (si disponible) | BD Forêt V2 + forêt ancienne | Idem | Vérification terrain des limites | Historique complet modélisé |
| N3 | Naturalité composite | 0.35 × N1 + 0.35 × N2 + 0.15 × (100−L1) + 0.15 × B3 | Composé de N1, N2, L1, B3 au NDP 0 | Composé au NDP 1 | Composé au NDP 2 | Composé au NDP 3 | Composé au NDP 4 |

---

## Notes

1. **Fallback par priorité** : la plupart des indicateurs n'ont pas de branchement NDP explicite dans le code. Ils sélectionnent automatiquement la meilleure source disponible (terrain > LiDAR > satellite > défaut).

2. **Résolution vs algorithme** : pour les indicateurs topographiques (F2, W2, W3, R2, R3), l'algorithme reste identique — seule la résolution du MNT change (25 m → 1 m avec LiDAR).

3. **Cache partagé** : le TWI est calculé une seule fois et partagé entre W2, W3, F2 et R3 via `.twi_cache`.

4. **Indicateurs dérivés** : T2 dépend de T1 ou N2 ; E1 dépend de P1 ; E2 dépend de E1 ; N3 dépend de N1, N2, L1, B3.

5. **Fichiers source** :
   - `R/indicators-biodiversity.R` — B1, B2, B3
   - `R/indicators-families.R` — C1, C2, W1, W2, W3, A1, A2, F1, F2, L1, L2
   - `R/indicators-temporal.R` — T1, T2
   - `R/indicators-risk.R` — R1, R2, R3, R4
   - `R/indicators-social.R` — S1, S2, S3
   - `R/indicators-productive.R` — P1, P2, P3
   - `R/indicators-energy.R` — E1, E2
   - `R/indicators-naturalness.R` — N1, N2, N3
   - `R/ndp.R` — Système NDP, Fibonacci, confiance φ
