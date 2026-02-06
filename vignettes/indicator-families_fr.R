## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 8,
  fig.height = 5,
  warning = FALSE,
  message = FALSE
)

## -----------------------------------------------------------------------------
library(nemeton)
library(ggplot2)
library(dplyr)
library(sf)

## -----------------------------------------------------------------------------
# Charger les données de base
data(massif_demo_units)

set.seed(42)
n <- nrow(massif_demo_units)

# Créer les indicateurs pour chaque famille
demo_data <- massif_demo_units

# Famille C - Carbone & Vitalité
demo_data$C1 <- runif(n, 80, 250)     # Biomasse carbone (tC/ha)
demo_data$C2 <- runif(n, 0.5, 0.9)    # NDVI (vitalité)

# Famille B - Biodiversité
demo_data$B1 <- sample(0:3, n, replace = TRUE)  # Protection (0-3)
demo_data$B2 <- runif(n, 0.5, 2.5)    # Diversité structurelle (Shannon)
demo_data$B3 <- runif(n, 0.2, 0.95)   # Connectivité (0-1)

# Famille W - Eau
demo_data$W1 <- runif(n, 10, 100)     # Densité réseau hydro (m/ha)
demo_data$W2 <- runif(n, 0, 40)       # % zones humides
demo_data$W3 <- runif(n, 5, 15)       # TWI

# Famille A - Air & Microclimat
demo_data$A1 <- runif(n, 0.4, 0.95)   # Couverture arborée buffer 1km
demo_data$A2 <- runif(n, 50, 95)      # Qualité air

# Famille F - Fertilité sols
demo_data$F1 <- sample(1:5, n, replace = TRUE, prob = c(0.1, 0.3, 0.35, 0.2, 0.05))
demo_data$F2 <- runif(n, 0, 25)       # Pente % (risque érosion)

# Famille L - Paysage
demo_data$L1 <- runif(n, 0.1, 0.8)    # Fragmentation (0-1, faible = mieux)
demo_data$L2 <- runif(n, 0.05, 0.35)  # Ratio lisière

# Famille T - Temps & Dynamique
demo_data$T1 <- demo_data$age         # Ancienneté (années)
demo_data$T2 <- runif(n, 0, 5)        # Taux changement (%/an)

# Famille R - Risques (échelle 0-100)
demo_data$R1 <- runif(n, 5, 80)       # Risque incendie
demo_data$R2 <- runif(n, 10, 70)      # Risque tempête
demo_data$R3 <- runif(n, 15, 75)      # Stress hydrique
demo_data$R4 <- runif(n, 10, 65)      # Risque abroutissement

# Famille S - Social & Usages
demo_data$S1 <- runif(n, 0, 5)        # Densité sentiers (km/ha)
demo_data$S2 <- runif(n, 20, 100)     # Score accessibilité
demo_data$S3 <- runif(n, 500, 50000)  # Population proximité

# Famille P - Production
demo_data$P1 <- demo_data$volume      # Volume sur pied (m³/ha)
demo_data$P2 <- runif(n, 3, 15)       # Productivité (m³/ha/an)
demo_data$P3 <- runif(n, 40, 95)      # Qualité bois

# Famille E - Énergie
demo_data$E1 <- runif(n, 1, 10)       # Potentiel bois-énergie (t/an)
demo_data$E2 <- runif(n, 5, 50)       # Évitement CO2 (tCO2eq/an)

# Famille N - Naturalité
demo_data$N1 <- runif(n, 100, 3000)   # Distance infrastructure (m)
demo_data$N2 <- runif(n, 5, 100)      # Continuité forestière (ha)
demo_data$N3 <- runif(n, 20, 95)      # Score naturalité composite

cat("Dataset avec", n, "parcelles et 29 indicateurs\n")

## ----fig.height=4-------------------------------------------------------------
ggplot(demo_data |> st_drop_geometry()) +
  geom_point(aes(x = C1, y = C2, color = forest_type), size = 3, alpha = 0.7) +
  labs(
    title = "Famille C - Carbone & Vitalité",
    x = "C1: Stock carbone (tC/ha)",
    y = "C2: NDVI (vitalité)",
    color = "Type forestier"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

## ----fig.height=4-------------------------------------------------------------
library(tidyr)

demo_data |>
  st_drop_geometry() |>
  select(parcel_id, W1, W2, W3) |>
  pivot_longer(cols = c(W1, W2, W3), names_to = "indicator", values_to = "value") |>
  ggplot(aes(x = indicator, y = value, fill = indicator)) +
  geom_boxplot(alpha = 0.7) +
  scale_fill_manual(
    values = c(W1 = "#00838F", W2 = "#0097A7", W3 = "#26C6DA"),
    labels = c("Réseau hydro (m/ha)", "Zones humides (%)", "TWI")
  ) +
  labs(
    title = "Famille W - Distribution des indicateurs Eau",
    x = "Indicateur",
    y = "Valeur"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

## ----fig.height=6-------------------------------------------------------------
ggplot(demo_data) +
  geom_sf(aes(fill = B2), color = "white", linewidth = 0.3) +
  scale_fill_viridis_c(name = "Shannon\n(diversité)", option = "D") +
  labs(
    title = "B2 - Diversité structurelle",
    subtitle = "Indice de Shannon des strates et âges"
  ) +
  theme_minimal() +
  theme(axis.text = element_blank(), axis.ticks = element_blank())

## ----fig.height=5-------------------------------------------------------------
demo_data |>
  st_drop_geometry() |>
  select(parcel_id, R1, R2, R3, R4) |>
  tidyr::pivot_longer(cols = c(R1, R2, R3, R4), names_to = "indicator", values_to = "value") |>
  ggplot(aes(x = indicator, y = value, fill = indicator)) +
  geom_boxplot(alpha = 0.8) +
  scale_fill_brewer(palette = "YlOrRd") +
  labs(
    title = "Famille R - Distribution des risques",
    x = "Indicateur",
    y = "Score (0-100)",
    fill = "Indicateur"
  ) +
  theme_minimal()

## -----------------------------------------------------------------------------
# Indicateurs à normaliser
indicators_to_norm <- c("C1", "C2", "B2", "B3", "W1", "W2", "W3",
                         "A1", "A2", "S1", "S2", "P1", "P2", "P3",
                         "E1", "E2", "N1", "N2", "N3")

# Normalisation min-max
demo_norm <- demo_data

for (ind in indicators_to_norm) {
  values <- demo_norm[[ind]]
  min_val <- min(values, na.rm = TRUE)
  max_val <- max(values, na.rm = TRUE)
  demo_norm[[paste0(ind, "_norm")]] <- (values - min_val) / (max_val - min_val) * 100
}

# Indicateurs inversés (faible = mieux)
inv_indicators <- c("L1", "L2", "T2", "F2")
for (ind in inv_indicators) {
  values <- demo_norm[[ind]]
  min_val <- min(values, na.rm = TRUE)
  max_val <- max(values, na.rm = TRUE)
  demo_norm[[paste0(ind, "_norm")]] <- (1 - (values - min_val) / (max_val - min_val)) * 100
}

# Indicateurs catégoriels transformés
# F1: 1 (très fertile) = 100, 5 (très pauvre) = 20
demo_norm$F1_norm <- (6 - demo_norm$F1) / 4 * 80 + 20

# R1-R4: déjà en 0-100, inverser (faible risque = meilleur score)
demo_norm$R1_norm <- 100 - demo_norm$R1
demo_norm$R2_norm <- 100 - demo_norm$R2
demo_norm$R3_norm <- 100 - demo_norm$R3
demo_norm$R4_norm <- 100 - demo_norm$R4

# B1: 0 = 0, 3 = 100
demo_norm$B1_norm <- demo_norm$B1 / 3 * 100

# T1: log transformation pour ancienneté
demo_norm$T1_norm <- pmin(100, log(demo_norm$T1 + 1) / log(200) * 100)

cat("Indicateurs normalisés créés\n")

## -----------------------------------------------------------------------------
# Calculer les indices de famille
demo_norm$family_C <- (demo_norm$C1_norm + demo_norm$C2_norm) / 2
demo_norm$family_B <- (demo_norm$B1_norm + demo_norm$B2_norm + demo_norm$B3_norm) / 3
demo_norm$family_W <- (demo_norm$W1_norm + demo_norm$W2_norm + demo_norm$W3_norm) / 3
demo_norm$family_A <- (demo_norm$A1_norm + demo_norm$A2_norm) / 2
demo_norm$family_F <- (demo_norm$F1_norm + demo_norm$F2_norm) / 2
demo_norm$family_L <- (demo_norm$L1_norm + demo_norm$L2_norm) / 2
demo_norm$family_T <- (demo_norm$T1_norm + demo_norm$T2_norm) / 2
demo_norm$family_R <- (demo_norm$R1_norm + demo_norm$R2_norm + demo_norm$R3_norm + demo_norm$R4_norm) / 4
demo_norm$family_S <- (demo_norm$S1_norm + demo_norm$S2_norm) / 2
demo_norm$family_P <- (demo_norm$P1_norm + demo_norm$P2_norm + demo_norm$P3_norm) / 3
demo_norm$family_E <- (demo_norm$E1_norm + demo_norm$E2_norm) / 2
demo_norm$family_N <- (demo_norm$N1_norm + demo_norm$N2_norm + demo_norm$N3_norm) / 3

# Afficher les scores moyens par famille
family_means <- demo_norm |>
  st_drop_geometry() |>
  summarise(across(starts_with("family_"), mean, na.rm = TRUE)) |>
  pivot_longer(everything(), names_to = "family", values_to = "mean_score") |>
  mutate(family = gsub("family_", "", family)) |>
  arrange(desc(mean_score))

family_means

## ----fig.height=7-------------------------------------------------------------
# Radar pour une parcelle (mode famille)
nemeton_radar(
  demo_norm,
  unit_id = "P01",
  mode = "family",
  title = "Profil écosystémique - Parcelle P01"
)

## ----fig.height=7-------------------------------------------------------------
# Comparer plusieurs parcelles sur le même radar
nemeton_radar(
  demo_norm,
  unit_id = c("P01", "P05", "P10"),
  mode = "family",
  title = "Comparaison de 3 parcelles - 12 familles"
)

## ----fig.height=8, fig.width=10-----------------------------------------------
# Préparer les données pour les cartes
map_data <- demo_norm |>
  select(parcel_id, family_C, family_B, family_W, family_P, geometry) |>
  pivot_longer(
    cols = starts_with("family_"),
    names_to = "family",
    values_to = "score"
  ) |>
  mutate(family = case_when(
    family == "family_C" ~ "Carbone",
    family == "family_B" ~ "Biodiversité",
    family == "family_W" ~ "Eau",
    family == "family_P" ~ "Production"
  ))

ggplot(map_data) +
  geom_sf(aes(fill = score), color = "white", linewidth = 0.3) +
  facet_wrap(~family, ncol = 2) +
  scale_fill_viridis_c(name = "Score\n(0-100)", option = "D") +
  labs(
    title = "Scores par famille de services écosystémiques",
    subtitle = "4 familles clés : Carbone, Biodiversité, Eau, Production"
  ) +
  theme_minimal() +
  theme(
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    strip.text = element_text(face = "bold", size = 11)
  )

## ----fig.height=7, fig.width=8------------------------------------------------
# Extraire les scores de famille
family_scores <- demo_norm |>
  st_drop_geometry() |>
  select(starts_with("family_"))

# Renommer pour lisibilité
names(family_scores) <- gsub("family_", "", names(family_scores))

# Calculer la matrice de corrélation
cor_matrix <- cor(family_scores, use = "complete.obs")

# Préparer pour ggplot
cor_data <- as.data.frame(as.table(cor_matrix))
names(cor_data) <- c("Family1", "Family2", "Correlation")

ggplot(cor_data, aes(x = Family1, y = Family2, fill = Correlation)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.2f", Correlation)), size = 3) +
  scale_fill_gradient2(
    low = "#2166AC",
    mid = "white",
    high = "#B2182B",
    midpoint = 0,
    limits = c(-1, 1)
  ) +
  labs(
    title = "Corrélations entre familles d'indicateurs",
    subtitle = "Rouge = synergies, Bleu = trade-offs",
    x = "", y = ""
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank()
  )

## ----fig.height=5-------------------------------------------------------------
ggplot(demo_norm |> st_drop_geometry(), aes(x = family_C, y = family_B)) +
  geom_point(aes(color = family_P, size = family_N), alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE, color = "gray40", linetype = "dashed") +
  scale_color_viridis_c(name = "Production", option = "D") +
  scale_size_continuous(name = "Naturalité", range = c(2, 8)) +
  labs(
    title = "Synergies Carbone-Biodiversité",
    subtitle = "Taille = naturalité, Couleur = production",
    x = "Score Carbone (famille C)",
    y = "Score Biodiversité (famille B)"
  ) +
  theme_minimal()

## ----fig.height=6-------------------------------------------------------------
# Identifier les parcelles excellentes sur plusieurs familles
threshold <- 60  # Top 40%

demo_norm <- demo_norm |>
  mutate(
    high_C = family_C >= threshold,
    high_B = family_B >= threshold,
    high_W = family_W >= threshold,
    high_N = family_N >= threshold,
    high_P = family_P >= threshold,
    hotspot_count = high_C + high_B + high_W + high_N + high_P,
    is_hotspot = hotspot_count >= 3
  )

# Cartographier les hotspots
ggplot(demo_norm) +
  geom_sf(aes(fill = factor(hotspot_count)), color = "white", linewidth = 0.5) +
  scale_fill_manual(
    values = c("0" = "#FFEBEE", "1" = "#FFCDD2", "2" = "#EF9A9A",
               "3" = "#E57373", "4" = "#EF5350", "5" = "#C62828"),
    name = "Familles\nélevées"
  ) +
  labs(
    title = "Hotspots multi-services écosystémiques",
    subtitle = sprintf("Seuil = %d/100 (5 familles: C, B, W, N, P)", threshold)
  ) +
  theme_minimal() +
  theme(
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    legend.position = "right"
  )

## -----------------------------------------------------------------------------
hotspot_stats <- demo_norm |>
  st_drop_geometry() |>
  group_by(hotspot_count) |>
  summarise(
    n_parcelles = n(),
    surface_totale = round(sum(surface_ha), 1),
    C_mean = round(mean(family_C), 1),
    B_mean = round(mean(family_B), 1),
    P_mean = round(mean(family_P), 1),
    .groups = "drop"
  )

hotspot_stats

## ----fig.height=6-------------------------------------------------------------
# Créer un indice global pondéré
demo_norm <- demo_norm |>
  mutate(
    ecosystem_index = (
      family_C * 0.15 +  # Carbone
      family_B * 0.15 +  # Biodiversité
      family_W * 0.10 +  # Eau
      family_A * 0.05 +  # Air
      family_F * 0.05 +  # Fertilité
      family_L * 0.05 +  # Paysage
      family_T * 0.05 +  # Temporel
      family_R * 0.10 +  # Risques (résilience)
      family_S * 0.05 +  # Social
      family_P * 0.10 +  # Production
      family_E * 0.05 +  # Énergie
      family_N * 0.10    # Naturalité
    )
  )

# Carte de l'indice global
ggplot(demo_norm) +
  geom_sf(aes(fill = ecosystem_index), color = "white", linewidth = 0.3) +
  scale_fill_viridis_c(
    name = "Indice\nglobal",
    option = "D"
  ) +
  labs(
    title = "Indice de services écosystémiques global",
    subtitle = "Agrégation pondérée des 12 familles"
  ) +
  theme_minimal() +
  theme(
    axis.text = element_blank(),
    axis.ticks = element_blank()
  )

## -----------------------------------------------------------------------------
ggplot(demo_norm |> st_drop_geometry(), aes(x = ecosystem_index)) +
  geom_histogram(bins = 10, fill = "#2E7D32", alpha = 0.7, color = "white") +
  geom_vline(
    aes(xintercept = mean(ecosystem_index)),
    color = "red",
    linetype = "dashed",
    linewidth = 1
  ) +
  annotate("text", x = mean(demo_norm$ecosystem_index) + 3, y = 4,
           label = sprintf("Moyenne: %.1f", mean(demo_norm$ecosystem_index)),
           color = "red", fontface = "bold") +
  labs(
    title = "Distribution de l'indice global",
    x = "Score (0-100)",
    y = "Nombre de parcelles"
  ) +
  theme_minimal()

## -----------------------------------------------------------------------------
sessionInfo()

