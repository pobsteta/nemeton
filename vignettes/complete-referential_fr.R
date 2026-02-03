## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 7,
  fig.height = 5,
  warning = FALSE,
  message = FALSE
)

## ----message=FALSE------------------------------------------------------------
library(nemeton)
library(ggplot2)
library(dplyr)

## -----------------------------------------------------------------------------
# Le jeu de données de démonstration
data(massif_demo_units)

# Aperçu des données de base
head(massif_demo_units)

# Calculer les indicateurs pour la démonstration
# Les indicateurs sont générés de manière synthétique pour les besoins de cette vignette
set.seed(42)
n <- nrow(massif_demo_units)

# Générer des valeurs synthétiques pour tous les indicateurs
massif_demo_units$C1 <- runif(n, 50, 300)  # Biomasse t/ha
massif_demo_units$C2 <- runif(n, 0.3, 0.9)  # NDVI
massif_demo_units$B1 <- runif(n, 0, 100)    # Protection %
massif_demo_units$B2 <- runif(n, 20, 80)    # Structure diversity
massif_demo_units$B3 <- runif(n, 100, 3000) # Distance corridor m
massif_demo_units$W1 <- runif(n, 0, 500)    # Distance hydro m
massif_demo_units$W2 <- runif(n, 0, 50)     # Zones humides %
massif_demo_units$W3 <- runif(n, 2, 15)     # TWI
massif_demo_units$A1 <- runif(n, 40, 95)    # Couverture %
massif_demo_units$A2 <- runif(n, 1, 5)      # Qualité air (ATMO)
massif_demo_units$F1 <- runif(n, 30, 90)    # Fertilité
massif_demo_units$F2 <- runif(n, 0, 50)     # Érosion
massif_demo_units$L1 <- runif(n, 0.1, 0.9)  # Fragmentation
massif_demo_units$L2 <- runif(n, 0, 200)    # Lisière m
massif_demo_units$T1 <- runif(n, 20, 150)   # Ancienneté ans
massif_demo_units$T2 <- runif(n, -20, 20)   # Changement %
massif_demo_units$R1 <- runif(n, 10, 90)    # Risque incendie
massif_demo_units$R2 <- runif(n, 10, 80)    # Risque tempête
massif_demo_units$R3 <- runif(n, 0, 100)    # Stress
massif_demo_units$S1 <- runif(n, 0, 5)      # Accessibilité
massif_demo_units$S2 <- runif(n, 0, 100)    # Sentiers
massif_demo_units$S3 <- runif(n, 0, 50000)  # Proximité m
massif_demo_units$P1 <- runif(n, 50, 500)   # Volume m³/ha
massif_demo_units$P2 <- runif(n, 2, 15)     # Productivité
massif_demo_units$P3 <- runif(n, 30, 90)    # Qualité
massif_demo_units$E1 <- runif(n, 1, 12)     # Bois-énergie
massif_demo_units$E2 <- runif(n, 5, 25)     # Évitement CO2
massif_demo_units$N1 <- runif(n, 100, 5000) # Distance infra m
massif_demo_units$N2 <- runif(n, 0, 100)    # Continuité
massif_demo_units$N3 <- runif(n, 20, 80)    # Naturalité composite

## -----------------------------------------------------------------------------
# Créer tous les indices de famille (12 familles)
# create_family_index() détecte automatiquement toutes les familles par préfixe
result <- create_family_index(massif_demo_units)

# Afficher les indices de famille
result |>
  sf::st_drop_geometry() |>
  select(parcel_id, starts_with("family_")) |>
  head()

## ----fig.width=8, fig.height=8------------------------------------------------
# Radar pour la parcelle 1 (toutes les 12 familles)
nemeton_radar(
  result,
  unit_id = 1,
  mode = "family"
)

## ----fig.width=10, fig.height=9-----------------------------------------------
# Calculer les corrélations entre toutes les familles
families_all <- c(
  "family_C", "family_B", "family_W", "family_A",
  "family_F", "family_L", "family_T", "family_R",
  "family_S", "family_P", "family_E", "family_N"
)

correlations <- compute_family_correlations(result, families = families_all)

# Visualiser la matrice de corrélation
plot_correlation_matrix(correlations)

## -----------------------------------------------------------------------------
# Hotspots pour conservation (C, B, N)
hotspots_conservation <- identify_hotspots(
  result,
  families = c("family_C", "family_B", "family_N"),
  threshold = 0.7,
  min_families = 2
)

# Hotspots pour production durable (P, C, E)
hotspots_production <- identify_hotspots(
  result,
  families = c("family_P", "family_C", "family_E"),
  threshold = 0.7,
  min_families = 2
)

# Hotspots pour services sociaux (S, A, L)
hotspots_social <- identify_hotspots(
  result,
  families = c("family_S", "family_A", "family_L"),
  threshold = 0.7,
  min_families = 2
)

# Afficher les hotspots
table(hotspots_conservation$is_hotspot)
table(hotspots_production$is_hotspot)
table(hotspots_social$is_hotspot)

## ----fig.width=10, fig.height=8-----------------------------------------------
# Visualiser les nouvelles familles S, P, E, N
library(patchwork)

p_social <- ggplot(result) +
  geom_sf(aes(fill = family_S)) +
  scale_fill_viridis_c(name = "Social") +
  labs(title = "Famille S - Social & Usages") +
  theme_minimal()

p_production <- ggplot(result) +
  geom_sf(aes(fill = family_P)) +
  scale_fill_viridis_c(name = "Production") +
  labs(title = "Famille P - Production & Économie") +
  theme_minimal()

p_energy <- ggplot(result) +
  geom_sf(aes(fill = family_E)) +
  scale_fill_viridis_c(name = "Énergie") +
  labs(title = "Famille E - Énergie & Climat") +
  theme_minimal()

p_naturalness <- ggplot(result) +
  geom_sf(aes(fill = family_N)) +
  scale_fill_viridis_c(name = "Naturalité") +
  labs(title = "Famille N - Naturalité & Wilderness") +
  theme_minimal()

(p_social + p_production) / (p_energy + p_naturalness)

## ----fig.width=12, fig.height=10----------------------------------------------
# Créer une facette pour toutes les 12 familles
result_long <- result |>
  sf::st_drop_geometry() |>
  tidyr::pivot_longer(
    cols = starts_with("family_"),
    names_to = "famille",
    values_to = "valeur"
  ) |>
  left_join(
    result |> select(parcel_id, geometry),
    by = "parcel_id"
  ) |>
  sf::st_as_sf()

# Labels des familles pour la facette
family_labels <- c(
  family_C = "C - Carbone",
  family_B = "B - Biodiversité",
  family_W = "W - Eau",
  family_A = "A - Air",
  family_F = "F - Fertilité",
  family_L = "L - Paysage",
  family_T = "T - Temps",
  family_R = "R - Risques",
  family_S = "S - Social",
  family_P = "P - Production",
  family_E = "E - Énergie",
  family_N = "N - Naturalité"
)

ggplot(result_long) +
  geom_sf(aes(fill = valeur)) +
  facet_wrap(~famille, ncol = 4, labeller = labeller(famille = family_labels)) +
  scale_fill_viridis_c(name = "Score") +
  labs(title = "Référentiel Complet 12 Familles") +
  theme_minimal() +
  theme(
    strip.text = element_text(face = "bold"),
    axis.text = element_blank(),
    axis.ticks = element_blank()
  )

## -----------------------------------------------------------------------------
# Normaliser tous les indicateurs
result_norm <- normalize_indicators(
  result,
  indicators = c(
    paste0("C", 1:2), paste0("B", 1:3), paste0("W", 1:3),
    paste0("A", 1:2), paste0("F", 1:2), paste0("L", 1:2),
    paste0("T", 1:2), paste0("R", 1:3), paste0("S", 1:3),
    paste0("P", 1:3), paste0("E", 1:2), paste0("N", 1:3)
  ),
  method = "minmax"
)

# Créer un indice composite global (toutes familles)
result_composite <- create_composite_index(
  result_norm,
  indicators = families_all,
  weights = rep(1, 12), # Poids égaux pour toutes les familles
  name = "nemeton_index_12"
)

# Visualiser l'indice composite
ggplot(result_composite) +
  geom_sf(aes(fill = nemeton_index_12)) +
  scale_fill_viridis_c(name = "Score", limits = c(0, 100)) +
  labs(title = "Indice Composite Nemeton (12 Familles)") +
  theme_minimal()

## -----------------------------------------------------------------------------
# Créer différents indices pour différents objectifs de gestion

# Scénario 1: Conservation intégrale
composite_conservation <- create_composite_index(
  result_norm,
  indicators = c("family_C", "family_B", "family_W", "family_N"),
  weights = c(0.3, 0.4, 0.15, 0.15),
  name = "conservation"
)

# Scénario 2: Production durable
composite_production <- create_composite_index(
  result_norm,
  indicators = c("family_P", "family_E", "family_F", "family_C"),
  weights = c(0.4, 0.25, 0.2, 0.15),
  name = "production"
)

# Scénario 3: Services sociaux
composite_social <- create_composite_index(
  result_norm,
  indicators = c("family_S", "family_A", "family_L", "family_R"),
  weights = c(0.35, 0.25, 0.2, 0.2),
  name = "social"
)

# Comparer les scénarios
comparison <- result |>
  mutate(
    conservation = composite_conservation$conservation,
    production = composite_production$production,
    social = composite_social$social
  ) |>
  sf::st_drop_geometry() |>
  select(parcel_id, conservation, production, social) |>
  tidyr::pivot_longer(cols = -parcel_id, names_to = "scenario", values_to = "score")

# Visualiser le classement des parcelles selon les scénarios
ggplot(comparison, aes(x = reorder(parcel_id, score), y = score, fill = scenario)) +
  geom_col(position = "dodge") +
  coord_flip() +
  scale_fill_viridis_d() +
  labs(
    title = "Classement des Parcelles selon 3 Scénarios de Gestion",
    x = "Parcelle",
    y = "Score",
    fill = "Scénario"
  ) +
  theme_minimal()

