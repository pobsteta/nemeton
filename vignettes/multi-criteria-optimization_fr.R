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

# Le jeu de données étendu est disponible via LazyData

## -----------------------------------------------------------------------------
# Exemple 1: Maximiser Carbon (C), Biodiversité (B), et Production (P)
result_pareto <- identify_pareto_optimal(
  massif_demo_units_extended,
  objectives = c("family_C", "family_B", "family_P"),
  maximize = c(TRUE, TRUE, TRUE)
)

# Combien de parcelles sont Pareto-optimales ?
table(result_pareto$is_optimal)

# Quelles parcelles sont optimales ?
result_pareto |>
  sf::st_drop_geometry() |>
  filter(is_optimal) |>
  select(name, family_C, family_B, family_P, is_optimal)

## -----------------------------------------------------------------------------
# Cartographier les parcelles Pareto-optimales
ggplot(result_pareto) +
  geom_sf(aes(fill = is_optimal), color = "white", size = 0.5) +
  scale_fill_manual(
    values = c("gray70", "red"),
    labels = c("Non-optimal", "Pareto-optimal"),
    name = "Statut"
  ) +
  labs(title = "Parcelles Pareto-Optimales (C, B, P)") +
  theme_minimal()

## -----------------------------------------------------------------------------
# Exemple 2: Maximiser C et B, Minimiser Risque incendie (R1)
result_mixed <- identify_pareto_optimal(
  massif_demo_units_extended,
  objectives = c("family_C", "family_B", "R1"),
  maximize = c(TRUE, TRUE, FALSE)  # Minimiser R1
)

table(result_mixed$is_optimal)

# Profil des parcelles optimales
result_mixed |>
  sf::st_drop_geometry() |>
  filter(is_optimal) |>
  select(name, family_C, family_B, R1, is_optimal)

## -----------------------------------------------------------------------------
# Clustering avec k=3 prédéfini
result_kmeans <- cluster_parcels(
  massif_demo_units_extended,
  families = c("family_C", "family_B", "family_P", "family_S"),
  k = 3,
  method = "kmeans"
)

# Distribution des clusters
table(result_kmeans$cluster)

# Profil moyen de chaque cluster
profiles <- attr(result_kmeans, "cluster_profile")
print(profiles)

## -----------------------------------------------------------------------------
# Carte des clusters
ggplot(result_kmeans) +
  geom_sf(aes(fill = factor(cluster)), color = "white", size = 0.5) +
  scale_fill_viridis_d(name = "Cluster") +
  labs(title = "Clusters K-means (k=3) sur C, B, P, S") +
  theme_minimal()

## -----------------------------------------------------------------------------
# Laisser l'algorithme déterminer k optimal
result_auto <- cluster_parcels(
  massif_demo_units_extended,
  families = c("family_C", "family_B", "family_P", "family_S"),
  k = NULL,  # Auto-détermination
  method = "kmeans"
)

# K optimal déterminé
optimal_k <- attr(result_auto, "optimal_k")
print(paste("K optimal:", optimal_k))

# Scores de silhouette pour chaque k testé
silhouette_scores <- attr(result_auto, "silhouette_scores")
print(silhouette_scores)

# Visualiser les scores de silhouette
k_values <- as.integer(names(silhouette_scores))
plot(k_values, silhouette_scores,
     type = "b", pch = 19, col = "blue",
     xlab = "Nombre de clusters (k)",
     ylab = "Score de silhouette moyen",
     main = "Détermination du K Optimal")
abline(v = optimal_k, col = "red", lty = 2)

## -----------------------------------------------------------------------------
# Clustering hiérarchique
result_hclust <- cluster_parcels(
  massif_demo_units_extended,
  families = c("family_C", "family_B", "family_P", "family_S"),
  k = 3,
  method = "hierarchical"
)

# Comparer avec K-means
comparison <- data.frame(
  kmeans = result_kmeans$cluster,
  hierarchical = result_hclust$cluster
)
table(comparison)

## -----------------------------------------------------------------------------
# Analyser les profils des clusters
profiles_kmeans <- attr(result_kmeans, "cluster_profile")

# Identifier les caractéristiques de chaque cluster
for (i in seq_len(nrow(profiles_kmeans))) {
  cat("\n=== Cluster", i, "===\n")
  cat("Carbone (C):", round(profiles_kmeans[i, "family_C"], 2), "\n")
  cat("Biodiversité (B):", round(profiles_kmeans[i, "family_B"], 2), "\n")
  cat("Production (P):", round(profiles_kmeans[i, "family_P"], 2), "\n")
  cat("Social (S):", round(profiles_kmeans[i, "family_S"], 2), "\n")

  # Interprétation
  if (profiles_kmeans[i, "family_B"] > 0.7 && profiles_kmeans[i, "family_C"] > 0.7) {
    cat("→ Type: Haute conservation\n")
  } else if (profiles_kmeans[i, "family_P"] > 0.7) {
    cat("→ Type: Production intensive\n")
  } else if (profiles_kmeans[i, "family_S"] > 0.7) {
    cat("→ Type: Usage récréatif\n")
  } else {
    cat("→ Type: Usage mixte/équilibré\n")
  }
}

## -----------------------------------------------------------------------------
# Trade-off entre Carbone et Biodiversité
plot_tradeoff(
  massif_demo_units_extended,
  x = "family_C",
  y = "family_B",
  xlab = "Carbone & Vitalité",
  ylab = "Biodiversité",
  title = "Trade-off: Carbone vs Biodiversité"
)

## -----------------------------------------------------------------------------
# Ajouter une 3ème dimension (Production) via la couleur
plot_tradeoff(
  massif_demo_units_extended,
  x = "family_C",
  y = "family_B",
  color = "family_P",
  xlab = "Carbone",
  ylab = "Biodiversité",
  title = "Trade-off C-B (coloré par Production)"
)

## -----------------------------------------------------------------------------
# D'abord identifier les parcelles Pareto-optimales
pareto_result <- identify_pareto_optimal(
  massif_demo_units_extended,
  objectives = c("family_C", "family_B"),
  maximize = c(TRUE, TRUE)
)

# Puis tracer avec frontière Pareto
plot_tradeoff(
  pareto_result,
  x = "family_C",
  y = "family_B",
  pareto_frontier = TRUE,
  xlab = "Carbone",
  ylab = "Biodiversité",
  title = "Trade-off C-B avec Frontière de Pareto"
)

## ----fig.width=10, fig.height=8-----------------------------------------------
library(patchwork)

# Créer une matrice de trade-off plots
p1 <- plot_tradeoff(massif_demo_units_extended, "family_C", "family_B",
                     title = "C vs B") + theme(legend.position = "none")
p2 <- plot_tradeoff(massif_demo_units_extended, "family_C", "family_P",
                     title = "C vs P") + theme(legend.position = "none")
p3 <- plot_tradeoff(massif_demo_units_extended, "family_B", "family_P",
                     title = "B vs P") + theme(legend.position = "none")
p4 <- plot_tradeoff(massif_demo_units_extended, "family_P", "family_E",
                     title = "P vs E") + theme(legend.position = "none")
p5 <- plot_tradeoff(massif_demo_units_extended, "family_S", "family_N",
                     title = "S vs N") + theme(legend.position = "none")
p6 <- plot_tradeoff(massif_demo_units_extended, "family_B", "family_N",
                     title = "B vs N") + theme(legend.position = "none")

(p1 + p2 + p3) / (p4 + p5 + p6) +
  plot_annotation(title = "Matrice de Trade-offs Entre Familles")

## -----------------------------------------------------------------------------
# Ajouter des labels pour les parcelles Pareto-optimales
plot_tradeoff(
  pareto_result,
  x = "family_C",
  y = "family_B",
  pareto_frontier = TRUE,
  label = "name",  # Afficher les noms
  xlab = "Carbone",
  ylab = "Biodiversité",
  title = "Parcelles Identifiées sur la Frontière de Pareto"
)

## -----------------------------------------------------------------------------
# Étape 1: Analyse de Pareto sur les 3 objectifs
conservation_pareto <- identify_pareto_optimal(
  massif_demo_units_extended,
  objectives = c("family_B", "family_C", "family_N"),
  maximize = c(TRUE, TRUE, TRUE)
)

# Combien de parcelles Pareto-optimales ?
n_optimal <- sum(conservation_pareto$is_optimal)
cat("Nombre de parcelles Pareto-optimales:", n_optimal, "\n")

# Étape 2: Classer les parcelles Pareto-optimales par score composite
conservation_subset <- conservation_pareto |>
  filter(is_optimal) |>
  mutate(composite_score = (family_B + family_C + family_N) / 3) |>
  arrange(desc(composite_score))

# Top 5 parcelles
top5 <- head(conservation_subset, 5)

top5 |>
  sf::st_drop_geometry() |>
  select(name, family_B, family_C, family_N, composite_score)

## -----------------------------------------------------------------------------
# Cartographier les 5 parcelles sélectionnées
conservation_pareto <- conservation_pareto |>
  mutate(
    selected = name %in% top5$name
  )

ggplot(conservation_pareto) +
  geom_sf(aes(fill = selected), color = "white", size = 0.5) +
  scale_fill_manual(
    values = c("gray80", "darkgreen"),
    labels = c("Non sélectionné", "Top 5 Conservation"),
    name = "Statut"
  ) +
  labs(title = "Sélection de 5 Parcelles pour Conservation Intégrale") +
  theme_minimal()

## -----------------------------------------------------------------------------
# Visualiser les parcelles sélectionnées sur le trade-off B-C
plot_tradeoff(
  conservation_pareto,
  x = "family_B",
  y = "family_C",
  color = "family_N",
  size = "family_N",
  xlab = "Biodiversité",
  ylab = "Carbone",
  title = "Sélection Conservation (taille/couleur = Naturalité)"
)

## -----------------------------------------------------------------------------
# Clustering sur 8 familles représentatives
zonage <- cluster_parcels(
  massif_demo_units_extended,
  families = c("family_C", "family_B", "family_W", "family_N",  # Conservation
               "family_P", "family_E",                            # Production
               "family_S", "family_A"),                           # Social
  k = 4,
  method = "kmeans"
)

# Profils des zones
profiles_zonage <- attr(zonage, "cluster_profile")
print(profiles_zonage)

# Attribuer des noms de zones selon les profils
zonage <- zonage |>
  mutate(
    zone_name = case_when(
      cluster == 1 ~ "Conservation intégrale",
      cluster == 2 ~ "Production durable",
      cluster == 3 ~ "Usage récréatif",
      cluster == 4 ~ "Gestion mixte",
      TRUE ~ paste("Zone", cluster)
    )
  )

table(zonage$zone_name)

## -----------------------------------------------------------------------------
ggplot(zonage) +
  geom_sf(aes(fill = zone_name), color = "white", size = 0.8) +
  scale_fill_viridis_d(name = "Type de Gestion") +
  labs(title = "Zonage Multifonctionnel Basé sur Clustering") +
  theme_minimal() +
  theme(legend.position = "bottom")

## -----------------------------------------------------------------------------
# Résumer les caractéristiques de chaque zone
zonage |>
  sf::st_drop_geometry() |>
  group_by(zone_name) |>
  summarise(
    n_parcelles = n(),
    C_mean = mean(family_C, na.rm = TRUE),
    B_mean = mean(family_B, na.rm = TRUE),
    P_mean = mean(family_P, na.rm = TRUE),
    S_mean = mean(family_S, na.rm = TRUE),
    N_mean = mean(family_N, na.rm = TRUE)
  ) |>
  mutate(across(where(is.numeric), ~ round(., 2)))
