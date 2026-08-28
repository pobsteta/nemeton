# data-raw/fiche_diagrams_data.R
#
# Contenu des diagrammes des fiches indicateurs. Une entree par indicateur,
# consommee par data-raw/fiche_diagrams.R.
#
# Regle : le diagramme ne redit pas le titre de la fiche, il montre le
# mecanisme — quelles entrees sont lues, quel calcul les transforme, ce que
# la valeur devient en aval, et ou se trouve le piege documente au § 4.
#
# Largeurs utiles (au-dela, le generateur avertit) :
#   entrees  titre <= 34 car.   lignes <= 40 car.
#   calcul   titre <= 33 car.   lignes <= 33 car. (chasse fixe)
#   aval     titre <= 30 car.   lignes <= 28 car. (chasse fixe)

# Chaine aval standard : colonne brute -> normalisation -> famille -> indice.
av <- function(colonne, unite, norm, fam_code, fam_col, membres) {
  list(
    list(titre = colonne, lignes = unite, accent = TRUE),
    list(titre = "normalize_indicator()", lignes = norm),
    list(titre = sprintf('create_family_index("%s")', fam_code),
         lignes = c(fam_col, sprintf("moyenne de %s", membres))),
    list(titre = "compute_general_index()", lignes = "Fibonacci · confiance φ")
  )
}

FICHES <- list(

  # =========================================================== C — Carbone ===
  C2 = list(
    code = "C2", fichier = "fiche-c2-ndvi_fr.Rmd",
    titre = paste("Chaine de calcul de C2 : deux modes exclusifs — FAPAR si le",
                  "raster biophysique est fourni, NDVI sinon — produisent la meme",
                  "moyenne zonale sur [0,1], normalisee par un simple facteur 100",
                  "puis moyennee avec C1 dans la famille Carbone ; l'absence de",
                  "couche NDVI ne rend pas NA mais leve une erreur."),
    liaison = "ou",
    entrees = list(
      list(titre = "Theia s2_biophysical", lignes = "FAPAR restitué (chaîne SL2P), 10 m", vers = 1),
      list(titre = "Sentinel-2 MUSCATE L2A", lignes = "bandes rouge et proche infrarouge", vers = 2),
      list(titre = "Couche ndvi absente", lignes = "aucun raster dans layers", tirets = TRUE, vers = 3)
    ),
    chemins = list(
      list(titre = "Mode FAPAR", lignes = c("argument fapar fourni", "moyenne zonale du raster")),
      list(titre = "Mode NDVI (défaut)", lignes = c("(NIR - Rouge)/(NIR + Rouge)", "safe_extract(fun = \"mean\")")),
      list(titre = "stop()", lignes = "erreur, pas de NA rendu", tirets = TRUE)
    ),
    aval = av("indicateur_c2_ndvi", "valeur dans [0, 1]",
              "min(100, max(0, v × 100))", "C", "famille_carbone", "C1 et C2"),
    notes = c(
      "Les deux modes vivent sur la même échelle : brancher FAPAR ne change aucune ligne d'aval.",
      "trend = TRUE ne calcule rien — avertissement, puis moyenne mono-date.",
      "Le score vaut la mesure × 100 : C2 est le seul indicateur où lire le score, c'est lire la mesure."
    ),
    legende = paste("Deux modes exclusifs pour une seule sortie. Le choix se fait sur la",
                    "présence de l'argument `fapar`, pas sur le NDP — et le NDP, lui, ne bouge",
                    "pas entre 0 et 1 puisque le LiDAR n'améliore rien du signal spectral.")
  ),

  # ============================================================== W — Eau ====
  W1 = list(
    code = "W1", fichier = "fiche-w1-reseau_fr.Rmd",
    titre = paste("Chaine de calcul de W1 : une densite de cours d'eau et un bonus",
                  "de proximite s'additionnent, puis la somme est normalisee a",
                  "ref_max = 50 ; le bonus plein valant lui-meme 50, toute unite",
                  "traversee sature a 100 quelle que soit sa densite."),
    liaison = "+",
    entrees = list(
      list(titre = "BD TOPO — réseau hydro", lignes = c("couche vecteur water_network", "cours d'eau permanents"), vers = 1),
      list(titre = "Géométrie de l'unité", lignes = c("surface (ha), distance au réseau"), vers = 2),
      list(titre = "Aucune couche fournie", lignes = "avertissement, puis 0 partout", tirets = TRUE, vers = 2)
    ),
    chemins = list(
      list(titre = "Densité directe", lignes = "longueur (m) / surface (ha)"),
      list(titre = "Bonus de proximité", lignes = c("traversée        -> 50",
                                                    "d < 500 m -> (1-d/500) × 50",
                                                    "sinon            -> 0"))
    ),
    aval = av("indicateur_w1_reseau", "m/ha + bonus (composite)",
              "min(100, v / 50 × 100)", "W", "famille_eau", "W1 à W4"),
    notes = c(
      "Le bonus plein (50) vaut exactement le ref_max (50) : traversée = 100, densité sans effet.",
      "Sans couche, W1 rend 0 et non NA — un zéro fabriqué tire famille_eau vers le bas.",
      "La colonne brute additionne des m/ha et un score : elle ne se lit pas comme une densité."
    ),
    legende = paste("Deux termes cumulés, un seul plafond. Comme le bonus de traversée égale",
                    "le `ref_max` de normalisation, W1 se comporte en pratique comme un",
                    "indicateur à trois états : traversée, proche, éloignée.")
  ),

  W2 = list(
    code = "W2", fichier = "fiche-w2-zones-humides_fr.Rmd",
    titre = paste("Chaine de calcul de W2 : quatre sources de zone humide apportent",
                  "chacune un pourcentage de surface, ces pourcentages sont",
                  "additionnes sans union geometrique, puis normalises a",
                  "ref_max = 5 — si bien que trois sources concordantes saturent",
                  "le score sur moins de 2 % de surface reelle."),
    entrees = list(
      list(titre = "BD TOPO — surfaces en eau", lignes = "aire(intersection) / aire(unité)"),
      list(titre = "TWI (MNT ou LiDAR HD)", lignes = "part des pixels de TWI > 12"),
      list(titre = "OSO — occupation du sol", lignes = "part des pixels « zone humide »"),
      list(titre = "Theia theia_water", lignes = "part au-dessus du seuil d'occurrence")
    ),
    chemins = list(
      list(titre = "Somme des contributions", lignes = c("W2 = Σ des sources présentes",
                                                         "aucune union géométrique",
                                                         "une même mare peut compter 3×"))
    ),
    aval = av("indicateur_w2_zones_humides", "% de surface, cumulé",
              "min(100, v / 5 × 100)", "W", "famille_eau", "W1 à W4"),
    notes = c(
      "ref_max = 5 : une ripisylve à 30 % et une parcelle à 5 % rendent le même score.",
      "Plus il y a de sources branchées, plus W2 monte — à réalité constante.",
      "TWI > 12 est un seuil de convention topographique, pas une zone humide réglementaire."
    ),
    legende = paste("Quatre sources qui s'additionnent au lieu de s'unir. Le double comptage",
                    "n'est pas un défaut d'implémentation isolé : c'est le mécanisme même de",
                    "l'indicateur, et il explique la saturation précoce du score.")
  ),
  W3 = list(
    code = "W3", fichier = "fiche-w3-humidite_fr.Rmd",
    titre = paste("Chaine de calcul de W3 : un MNT — LiDAR HD s'il existe, MNT 25 m",
                  "sinon — alimente un TWI calcule par GRASS ou par un repli D8,",
                  "moyenne sur l'unite puis reechelonne sur la fenetre etroite",
                  "[2,5 ; 4,5], si bien que le score depend autant de la resolution",
                  "du MNT et du moteur installe que du relief lui-meme."),
    liaison = "puis",
    entrees = list(
      list(titre = "MNT LiDAR HD (lidar_mnt)", lignes = c("cherché en premier", "résolution métrique")),
      list(titre = "Couche dem_layer — MNT 25 m", lignes = "repli, via .dem_working_res()"),
      list(titre = "Aucun MNT disponible", lignes = "stop() — pas de NA rendu", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "TWI pixel à pixel", lignes = c("ln( SCA / tan(pente) )", "SCA = surface drainée amont")),
      list(titre = "Moteur : GRASS ou terra D8", lignes = c("method = \"auto\" choisit seul",
                                                            "cache get_or_compute_twi()")),
      list(titre = "Moyenne zonale", lignes = "W3 = moy(TWI) sur l'unité")
    ),
    aval = av("indicateur_w3_humidite", "indice TWI, sans unité",
              "[2,5 ; 4,5] -> [0 ; 100]", "W", "famille_eau", "W1 à W4"),
    notes = c(
      "Fenêtre étroite : deux points d'indice séparent le 0 du 100, sans calibrage local.",
      "Le TWI dépend fortement de la résolution — passer au LiDAR HD fait bouger W3 sans qu'une goutte bouge.",
      "\"auto\" bascule silencieusement de GRASS à D8 selon la machine : figer method pour reproduire."
    ),
    legende = paste("Trois étapes, deux points de bascule. Le moteur (GRASS ou D8) et la",
                    "résolution du MNT changent la valeur autant que le relief : W3 se lit",
                    "à machine et à support constants, jamais entre deux massifs quelconques.")
  ),

  W4 = list(
    code = "W4", fichier = "fiche-w4-vpd_fr.Rmd",
    titre = paste("Chaine de calcul de W4 : Nemeton ne calcule pas le deficit de",
                  "pression de vapeur, il extrait la couche vpd produite par le",
                  "moteur microclimf puis la retourne sur une echelle decroissante",
                  "de 4,0 a 0,5 kPa ; sans chaine microclimat, W4 vaut NA et la",
                  "famille Eau se calcule sur W1 a W3 seuls."),
    liaison = "puis",
    entrees = list(
      list(titre = "microclimate_run() — microclimf", lignes = c("forçage ERA5-Land + CHM ML", "couche vpd, été")),
      list(titre = "Structure LiDAR HD ou drone", lignes = "canopée mieux décrite (NDP 1–2)"),
      list(titre = "Chaîne microclimat non lancée", lignes = "W4 = NA — cas nominal", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Extraction zonale", lignes = c("W4_vpd = moy(raster vpd)", "colonne annexe, en kPa")),
      list(titre = "Retournement d'échelle", lignes = c("100 × (4,0 - VPD)/(4,0 - 0,5)", "écrêté sur [0, 100]"))
    ),
    aval = av("indicateur_w4_vpd", "score 0–100, natif",
              "écrêtage natif 0–100", "W", "famille_eau", "W1 à W4"),
    notes = c(
      "NA est le cas nominal, pas une anomalie : famille_eau se calcule alors sur W1–W3 (na.rm = TRUE).",
      "Sens inversé : VPD élevé = air sec = défavorable. W4 = 90 signifie ambiance tamponnée.",
      "Le drapeau microclimate_model dit « simulation » ; il ne monte pas le niveau NDP."
    ),
    legende = paste("Un indicateur d'extraction, pas de calcul. Toute la physique est en amont,",
                    "dans microclimf ; Néméton n'y ajoute qu'un retournement d'échelle — d'où",
                    "l'inversion de lecture entre la colonne annexe `W4_vpd` et le score.")
  ),

  # ====================================================== B — Biodiversité ===
  B1 = list(
    code = "B1", fichier = "fiche-b1-protection_fr.Rmd",
    titre = paste("Chaine de calcul de B1 : les zonages de protection qui recoupent",
                  "l'unite donnent chacun un taux de couverture, moyenne pondere",
                  "par la force du statut ; le denominateur etant la somme des",
                  "poids, une unite entierement couverte obtient 100 quel que soit",
                  "le statut, et le mode WFS ne rapatrie aujourd'hui aucune donnee."),
    liaison = "puis",
    entrees = list(
      list(titre = "Couche de zonages fournie", lignes = c("type lu dans type_protection,",
                                                           "zone_type, type ou statut")),
      list(titre = "source = \"wfs\" (INPN)", lignes = "n'interroge rien — NA en pratique", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Couverture par type", lignes = "min(1, aire(inter) / aire(u))"),
      list(titre = "Moyenne pondérée", lignes = c("Σ(couv × poids)/Σ(poids) × 100",
                                                  "forte 1,0 · moyenne 0,6",
                                                  "faible 0,3 · inconnue 0,5"))
    ),
    aval = av("indicateur_b1_protection", "score 0–100, natif",
              "écrêtage natif 0–100", "B", "famille_biodiversite", "B1 à B4"),
    notes = c(
      "Le poids ne hiérarchise pas : 100 % en ZNIEFF 2 rend 100, comme 100 % en réserve intégrale.",
      "Il ne joue qu'entre statuts croisés à couvertures différentes.",
      "Indicateur le moins sensible au NDP : un statut est juridique, aucun capteur ne le produit."
    ),
    legende = paste("Une moyenne, pas une somme. Le dénominateur `Σ(poids)` est ce qui fait que",
                    "la force du statut disparaît dès qu'un seul statut couvre l'unité — le point",
                    "à énoncer avant toute comparaison entre unités de statuts différents.")
  ),

  B2 = list(
    code = "B2", fichier = "fiche-b2-structure_fr.Rmd",
    titre = paste("Chaine de calcul de B2 : quatre chemins essayes en cascade —",
                  "Shannon terrain, CHM, MNH LiDAR, NDVI — produisent la meme",
                  "colonne de structure, alors qu'ils mesurent des grandeurs",
                  "differentes avec des plafonds differents ; sans aucune entree,",
                  "B2 rend NA et un avertissement."),
    entrees = list(
      list(titre = "Colonnes strata + age_class", lignes = "relevé terrain (NDP 3+)", vers = 1),
      list(titre = "CHM ML (argument chm)", lignes = "FORMS-T, FORMSpoT, Open-Canopy", vers = 2),
      list(titre = "Couche lidar_mnh", lignes = "LiDAR HD ou drone", vers = 3),
      list(titre = "Couche ndvi", lignes = "Sentinel-2, 10 m", vers = 4),
      list(titre = "Aucune des quatre", lignes = "NA + avertissement", tirets = TRUE, vers = 5)
    ),
    chemins = list(
      list(titre = "Shannon terrain", lignes = c("strates 0,4 · âges 0,3", "essences 0,3")),
      list(titre = "CHM direct", lignes = "min(CV / 0,4 ; 1) × 100"),
      list(titre = "MNH LiDAR", lignes = "min(σ_h / 10 ; 1) × 100"),
      list(titre = "CV du NDVI", lignes = "min(CV / 0,4 ; 1) × 100"),
      list(titre = "NA", lignes = "aucune valeur fabriquée", tirets = TRUE)
    ),
    aval = av("indicateur_b2_structure", "score 0–100, natif",
              "écrêtage natif 0–100", "B", "famille_biodiversite", "B1 à B4"),
    notes = c(
      "chm fourni ET Shannon servi : le CV du CHM entre en composante additive (cv_chm_weight = 0,20).",
      "Deux plafonds distincts — CV 0,4 sans dimension, σ 10 m en mètres : les scores ne se comparent pas.",
      "Le chemin NDVI mesure une hétérogénéité horizontale et l'appelle structure verticale."
    ),
    legende = paste("Une colonne, quatre grandeurs. La rupture utile n'est pas NDP 0 → 1 mais",
                    "NDP 0 nu → NDP 0 augmenté : brancher un CHM public fait passer B2 d'un proxy",
                    "spectral horizontal à une mesure de hauteur.")
  ),
  B3 = list(
    code = "B3", fichier = "fiche-b3-connectivite_fr.Rmd",
    titre = paste("Chaine de calcul de B3 : quatre composantes de paysage calculees",
                  "sur la bbox du projet tamponnee de 2 km, moyennees a parts",
                  "egales, puis melangees 70/30 avec une composante locale ; toute",
                  "composante dont le paquet Suggests manque est remplacee par 50."),
    liaison = "puis",
    entrees = list(
      list(titre = "bdforet (sf) — obligatoire", lignes = "sans elle, B3 rend NA"),
      list(titre = "MNT (dem)", lignes = "support de la distance-coût"),
      list(titre = "Paquets Suggests absents", lignes = "composante remplacée par 50", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Quatre composantes paysage", lignes = c("structural · cost · graph · kernel",
                                                            "0,25 chacune, bbox + 2 km")),
      list(titre = "Composante locale", lignes = c("proximité forestière",
                                                   "max_distance = 5 000 m")),
      list(titre = "Mélange 70 / 30", lignes = "0,7 × global + 0,3 × local")
    ),
    aval = av("indicateur_b3_connectivite", "score 0–100, natif",
              "écrêtage natif 0–100", "B", "famille_biodiversite", "B1 à B4"),
    notes = c(
      "Une composante absente vaut 50 en silence : le score reste plausible sans avoir été calculé.",
      "70 % du score est un score de paysage identique pour toutes les unités du projet.",
      "La bbox tamponnée dépend du périmètre demandé : B3 ne se compare pas d'un projet à l'autre."
    ),
    legende = paste("Trois quarts de paysage, un quart de local — et un 50 par défaut à chaque",
                    "composante manquante. Vérifier quels paquets Suggests sont installés avant",
                    "de lire un B3 : c'est la variable cachée du score.")
  ),

  B4 = list(
    code = "B4", fichier = "fiche-b4-diversite-spectrale_fr.Rmd",
    titre = paste("Chaine de calcul de B4 : biodivMapR classe les pixels Sentinel-2",
                  "en especes spectrales, leur diversite de Shannon est calculee par",
                  "fenetre de 100 m puis moyennee sur l'unite, et normalisee par un",
                  "plafond conventionnel de dix especes effectives ; sans entree",
                  "spectrale, B4 vaut NA et non 0."),
    liaison = "puis",
    entrees = list(
      list(titre = "Sentinel-2 — objet spectral", lignes = c("compute_spectral_diversity()",
                                                             "partagé avec L3 (diversité β)")),
      list(titre = "Aucune entrée spectrale", lignes = "B4 = NA, jamais 0", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Espèces spectrales", lignes = c("biodivMapR, k-means", "sur les pixels S2")),
      list(titre = "Shannon par fenêtre 100 m", lignes = "H de leur distribution"),
      list(titre = "Moyenne des fenêtres", lignes = ".aggregate_diversity()")
    ),
    aval = av("indicateur_b4_div_spectrale", "indice de Shannon",
              "H / log(10) × 100", "B", "famille_biodiversite", "B1 à B4"),
    notes = c(
      "Plafond = 10 espèces spectrales effectives, exp(H) — valeur provisoire, spec 028.",
      "Ni comparable entre projets, ni dans le temps ; l'interdit remonte à famille_biodiversite.",
      "Un peuplement monospécifique légitime obtient un score bas : ce n'est pas un défaut."
    ),
    legende = paste("Une chaîne à trois étages dont la dernière marche est conventionnelle.",
                    "Le plafond de dix espèces effectives fixe l'échelle du score : c'est lui,",
                    "et non la mesure, qui rend deux projets incomparables.")
  ),

  # ======================================================= A — Air & clim ====
  A1 = list(
    code = "A1", fichier = "fiche-a1-couverture_fr.Rmd",
    titre = paste("Chaine de calcul de A1 : l'unite est d'abord tamponnee de 1 km,",
                  "puis la part boisee de ce voisinage est lue soit dans un raster",
                  "de couvert vegetal, soit dans une occupation du sol dont les",
                  "classes forestieres sont celles d'OSO — ce qui fait de A1 une",
                  "mesure du voisinage, pas de l'unite."),
    liaison = "ou",
    entrees = list(
      list(titre = "Unité tamponnée", lignes = c("st_buffer(unité, buffer_radius)",
                                                 "rayon 1 000 m par défaut")),
      list(titre = "Raster FVC (argument fvc)", lignes = "fraction de couvert végétal", vers = 1),
      list(titre = "Occupation du sol (OSO)", lignes = "land_cover, classes 16/17/18", vers = 2)
    ),
    chemins = list(
      list(titre = "Mode FVC", lignes = "moy(FVC sur buffer) × 100"),
      list(titre = "Mode occupation du sol", lignes = c("pixels forêt / pixels valides",
                                                        "× 100"))
    ),
    aval = av("indicateur_a1_couverture", "pourcentage 0–100",
              "écrêtage natif 0–100", "A", "famille_air", "A1 à A5"),
    notes = c(
      "A1 décrit le voisinage : à 1 km de rayon, deux parcelles voisines rendent presque la même valeur.",
      "Le buffer n'est pas soustrait de l'unité — son propre boisement compte dans son voisinage.",
      "Les classes 16/17/18 sont celles d'OSO ; une autre nomenclature fausse le compte en silence."
    ),
    legende = paste("Le buffer est le vrai sujet du calcul. Changer `buffer_radius` change ce que",
                    "A1 mesure — contexte de massif à 1 km, situation de lisière à 200 m — sans",
                    "que rien dans la colonne ne le dise.")
  ),

  A2 = list(
    code = "A2", fichier = "fiche-a2-qualite-air_fr.Rmd",
    titre = paste("Chaine de calcul de A2 : une interpolation sur les stations de",
                  "mesure quand elles existent, sinon un proxy d'eloignement au",
                  "trafic normalise par le maximum du projet, sinon NA ; la colonne",
                  "annexe A2_method dit laquelle des trois branches a servi."),
    entrees = list(
      list(titre = "atmo_data — stations (sf)", lignes = "colonnes NO2 et PM10", vers = 1),
      list(titre = "BD TOPO — routes", lignes = "nature, classe ou road_type", vers = 2),
      list(titre = "Ni stations ni routes", lignes = "A2_method = \"none\"", tirets = TRUE, vers = 3)
    ),
    chemins = list(
      list(titre = "direct — IDW", lignes = c("3 stations les plus proches", "A2_method = \"direct\"")),
      list(titre = "proxy — éloignement trafic", lignes = c("Σ w / (d/100)²   d < 2 000 m",
                                                            "1 - log1p(p)/log1p(max)",
                                                            "× 100")),
      list(titre = "NA", lignes = "aucune valeur fabriquée", tirets = TRUE)
    ),
    aval = av("indicateur_a2_qualite_air", "score 0–100, natif",
              "écrêtage natif 0–100", "A", "famille_air", "A1 à A5"),
    notes = c(
      "En mode proxy, le score est relatif au projet : l'unité la plus exposée vaut 0, quel que soit le trafic réel.",
      "Une nature de voie non reconnue pèse 0,50 — autant qu'un rond-point.",
      "Deux projets en mode proxy ne se comparent pas ; en mode direct, si."
    ),
    legende = paste("Trois branches, un seul nom de colonne. `A2_method` est la clé de lecture :",
                    "« direct » porte une mesure de qualité d'air, « proxy » porte une distance",
                    "aux routes remise à l'échelle du projet.")
  ),

  A3 = list(
    code = "A3", fichier = "fiche-a3-microclimat_fr.Rmd",
    titre = paste("Chaine de calcul de A3 : la temperature maximale estivale sous",
                  "couvert vient du moteur microclimf force par ERA5-Land et par la",
                  "structure de canopee ; Nemeton l'extrait par unite puis la",
                  "retourne sur l'echelle decroissante 15-40 degres."),
    liaison = "puis",
    entrees = list(
      list(titre = "microclimate_run() — microclimf", lignes = c("forçage ERA5-Land",
                                                                 "raster tmax_understorey")),
      list(titre = "CHM ML ou MNH LiDAR HD", lignes = "structure de canopée du modèle"),
      list(titre = "Chaîne microclimat non lancée", lignes = "A3 = NA", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Extraction zonale", lignes = c("A3_tmax = moy(tmax_under.)", "colonne annexe, en °C")),
      list(titre = "Retournement d'échelle", lignes = c("100 × (40 - Tmax)/(40 - 15)", "écrêté sur [0, 100]"))
    ),
    aval = av("indicateur_a3_microclimat", "score 0–100, natif",
              "écrêtage natif 0–100", "A", "famille_air", "A1 à A5"),
    notes = c(
      "Sortie de modèle, pas mesure : aucun thermomètre n'a été posé sous le couvert.",
      "40 °C est un plafond de convention — au-delà, le score ne distingue plus rien.",
      "Un seul microclimate_run() alimente A3, A4, W4 et R6 : même année, même forçage."
    ),
    legende = paste("Deux étapes seulement, parce que la physique est ailleurs. Ce que A3 ajoute",
                    "à `microclimf`, c'est l'agrégation par unité et l'inversion de sens — frais",
                    "= score élevé, l'inverse de la colonne annexe en degrés.")
  ),
  A4 = list(
    code = "A4", fichier = "fiche-a4-tamponnement_fr.Rmd",
    titre = paste("Chaine de calcul de A4 : l'ecart entre la temperature de l'air",
                  "libre et celle du sous-couvert, extrait du moteur microclimf,",
                  "est rapporte a un plafond de 10 degres jamais atteint sous nos",
                  "latitudes — d'ou une echelle qui n'utilise en pratique que sa",
                  "moitie basse."),
    liaison = "puis",
    entrees = list(
      list(titre = "microclimate_run() — microclimf", lignes = c("couche de tamponnement",
                                                                 "T_air libre - T_sous couvert")),
      list(titre = "CHM ML ou MNH LiDAR HD", lignes = "surface foliaire du modèle"),
      list(titre = "Chaîne microclimat non lancée", lignes = "A4 = NA", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Extraction zonale", lignes = c("A4_delta = moy(ΔT)", "colonne annexe, en °C")),
      list(titre = "Mise à l'échelle croissante", lignes = c("100 × delta / 10", "écrêté sur [0, 100]"))
    ),
    aval = av("indicateur_a4_tamponnement", "score 0–100, natif",
              "écrêtage natif 0–100", "A", "famille_air", "A1 à A5"),
    notes = c(
      "Le plafond de 10 °C n'est pas atteint en France : le haut de l'échelle reste inoccupé.",
      "A3 dit quelle température il fait, A4 combien la canopée en a retiré — un vallon frais peu tamponnant a A3 haut et A4 bas.",
      "Une coupe rase rend A4 proche de 0, et c'est la réponse correcte."
    ),
    legende = paste("La grandeur est un écart, pas une température. C'est ce qui rend A4",
                    "complémentaire de A3 : l'un mesure l'état du sous-bois, l'autre le travail",
                    "que la canopée a fourni pour l'obtenir.")
  ),

  A5 = list(
    code = "A5", fichier = "fiche-a5-rafraichissement_fr.Rmd",
    titre = paste("Chaine de calcul de A5 : la temperature de surface de l'unite est",
                  "comparee a la mediane d'une couronne de 500 m, et l'ecart est",
                  "porte sur une echelle centree ou 50 signifie « aucun effet",
                  "mesure » et non « moyen » ; hors contexte urbain, A5 vaut NA."),
    liaison = "puis",
    entrees = list(
      list(titre = "Raster LST (thermique)", lignes = c("nodata -32768 écarté",
                                                        "K ou °C indifférent")),
      list(titre = "Couronne de référence", lignes = c("buffer(unité, 500 m) \\ unité",
                                                       "ou valeur fixe si reference")),
      list(titre = "Hors contexte urbain", lignes = "A5 = NA, colonne a5_status", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Deux statistiques zonales", lignes = c("LST_unite = moyenne", "LST_ref   = médiane couronne")),
      list(titre = "Écart, puis échelle centrée", lignes = c("delta = LST_ref - LST_unite",
                                                             "A5 = 50 + (delta/5) × 50",
                                                             "écrêté sur [0, 100]"))
    ),
    aval = av("indicateur_a5_rafraichissement", "score centré sur 50",
              "écrêtage natif 0–100", "A", "famille_air", "A1 à A5"),
    notes = c(
      "50 = neutre, pas moyen : l'unité a la même température de surface que sa couronne.",
      "La couronne n'est pas neutre — ce qu'elle contient (ville, culture, forêt) fixe la référence.",
      "La date et l'heure de l'acquisition thermique dominent le résultat ; elles ne sont pas dans la colonne."
    ),
    legende = paste("Le seul indicateur des 41 dont l'échelle est centrée. Un A5 à 50 sur le",
                    "radar ne dit pas « performance moyenne » mais « aucun effet mesuré » — et",
                    "l'écart se lit toujours contre une couronne, jamais dans l'absolu.")
  ),

  # ========================================================= F — Fertilité ===
  F1 = list(
    code = "F1", fichier = "fiche-f1-fertilite_fr.Rmd",
    titre = paste("Chaine de calcul de F1 : quatre sources de fertilite — couche",
                  "fournie, SoilGrids, GIS Sol, textures Theia — sont selectionnees",
                  "par un argument explicite et non par une cascade, chacune avec",
                  "sa propre echelle implicite ; une source demandee sans son",
                  "entree leve une erreur au lieu de se rabattre."),
    liaison = "ou",
    entrees = list(
      list(titre = "Couche soil (raster ou sf)", lignes = "colonne fertility_col", vers = 1),
      list(titre = "SoilGrids 2.0 — CEC", lignes = "modèle global, maille 250 m", vers = 2),
      list(titre = "GIS Sol / RPF", lignes = "via rpf_code_col", vers = 3),
      list(titre = "Textures Theia", lignes = "argile, limon, sable", vers = 4)
    ),
    chemins = list(
      list(titre = "source = \"layer\" (défaut)", lignes = c("moyenne zonale", "ramenée sur 0–100")),
      list(titre = "source = \"soilgrids\"", lignes = "cec_to_fertility_score()"),
      list(titre = "source = \"gissol\"", lignes = "extract_fertility_from_gissol()"),
      list(titre = "source = \"theia_soil\"", lignes = c("texture_to_fertility_score()",
                                                          "tables uts_fertilite_fr"))
    ),
    aval = av("indicateur_f1_fertilite", "score 0–100, natif",
              "écrêtage natif 0–100", "F", "famille_sol", "F1 et F2"),
    notes = c(
      "Quatre sources, quatre échelles implicites : un F1 SoilGrids et un F1 texture ne se comparent pas.",
      "SoilGrids est un modèle global à 250 m — une parcelle y tient dans quelques pixels lissés.",
      "La profondeur de sol n'est pas dans la valeur : deux stations de réserve utile opposée peuvent rendre le même F1."
    ),
    legende = paste("Un aiguillage explicite, pas une cascade. `source` est un argument :",
                    "l'indicateur ne se rabat jamais tout seul, il échoue — c'est ce qui rend",
                    "la provenance lisible, à condition de la consigner avec la valeur.")
  ),

  F2 = list(
    code = "F2", fichier = "fiche-f2-erosion_fr.Rmd",
    titre = paste("Chaine de calcul de F2 : deux ingredients topographiques — TWI et",
                  "pente moyenne — sont normalises separement puis moyennes pour",
                  "produire une resistance a l'erosion, ou un score haut est bon ;",
                  "la couverture vegetale n'entre pas dans le calcul."),
    liaison = "puis",
    entrees = list(
      list(titre = "TWI (cache partagé)", lignes = "commun à W2, W3, F2 et R3"),
      list(titre = "MNT — pente", lignes = "terrain(dem, \"slope\"), en degrés"),
      list(titre = "Textures Theia (optionnel)", lignes = "texture_to_erosion_resistance()", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Deux normalisations", lignes = c("twi_norm   = (TWI-2,5)/7,5 × 100",
                                                     "slope_norm = 100 - pente/45 × 100")),
      list(titre = "Moyenne des composantes", lignes = c("F2 = moy(twi_norm, slope_norm)",
                                                         "+ résistance texturale si fournie"))
    ),
    aval = av("indicateur_f2_erosion", "score 0–100, natif",
              "écrêtage natif 0–100", "F", "famille_sol", "F1 et F2"),
    notes = c(
      "Le nom trompe : F2 mesure une résistance, un score haut est bon.",
      "Deux fenêtres de TWI coexistent dans le paquet — F2 normalise sur [2,5 ; 10], W3 sur [2,5 ; 4,5].",
      "La pente moyenne masque les ruptures : une parcelle plate à talus raide rend un F2 rassurant."
    ),
    legende = paste("Deux ingrédients, aucun couvert. F2 est un score de terrain, pas de",
                    "peuplement : la même topographie donne la même valeur sous futaie fermée",
                    "et après coupe rase.")
  ),
  # =========================================================== L — Paysage ===
  L1 = list(
    code = "L1", fichier = "fiche-l1-effet-lisiere_fr.Rmd",
    titre = paste("Chaine de calcul de L1 : trois composantes ponderees — forme de",
                  "l'unite, contraste de la matrice voisine, exposition au vent et",
                  "au soleil — dont deux retombent silencieusement sur 50 quand",
                  "leurs entrees manquent, soit 70 % du score fige sur une",
                  "constante."),
    liaison = "+",
    entrees = list(
      list(titre = "Géométrie de l'unité", lignes = "périmètre et aire", vers = 1),
      list(titre = "Occupation du sol (OSO)", lignes = c("table de contraste : forêt 0,",
                                                         "cultures 50, routes 75, bâti 90"), vers = 2),
      list(titre = "Relief — vent, ensoleillement", lignes = "sinon repli à 50", vers = 3)
    ),
    chemins = list(
      list(titre = "Géométrie — 30 %", lignes = c("SI = P / (2√(π·A))",
                                                  "min(100, (SI - 1) × 25)")),
      list(titre = "Contraste matrice — 40 %", lignes = c("contraste des pixels voisins",
                                                          "sans couche OSO : 50")),
      list(titre = "Exposition — 30 %", lignes = c("0,6 × vent + 0,4 × soleil",
                                                   "sans relief : 50"))
    ),
    aval = av("indicateur_l1_effet_lisiere", "score 0–100, natif",
              "écrêtage natif 0–100", "L", "famille_paysage", "L1 à L3"),
    notes = c(
      "Deux composantes sur trois retombent sur 50 sans données : 70 % du score peut être une constante.",
      "La géométrie mesure la forme de l'UGF, pas celle du massif : le découpage cadastral pèse sur le score.",
      "indicateur_l1_sylvosphere() reste un alias accepté (spec 045) ; la colonne, elle, a changé de nom."
    ),
    legende = paste("Trois composantes cumulées et deux valeurs par défaut. Avant de lire un L1,",
                    "vérifier quelles couches étaient présentes : le score reste plausible",
                    "lorsqu'il n'a été calculé que pour trois dixièmes.")
  ),

  L2 = list(
    code = "L2", fichier = "fiche-l2-morcellement_fr.Rmd",
    titre = paste("Chaine de calcul de L2 : si landscapemetrics et une couche",
                  "d'occupation du sol sont la, la continuite est mesuree sur un",
                  "masque foret tamponne de 1 km et rend la meme valeur pour toutes",
                  "les unites du projet ; sinon le calcul bascule sur un indice de",
                  "forme, propre a chaque unite — deux grandeurs sous un seul nom."),
    entrees = list(
      list(titre = "landcover + landscapemetrics", lignes = c("masque forêt binaire",
                                                                     "union des unités + 1 000 m"), vers = 1),
      list(titre = "Géométrie de l'unité seule", lignes = "périmètre et aire", vers = 2)
    ),
    chemins = list(
      list(titre = "Métriques de paysage", lignes = c("(COHESION + AI) / 2",
                                                      "calculate_lsm(), déjà 0–100")),
      list(titre = "Indice de forme (repli)", lignes = c("SI = P / (2√(π·A))", "min(100, 100 / SI)"))
    ),
    aval = av("indicateur_l2_morcellement", "score 0–100, natif",
              "écrêtage natif 0–100", "L", "famille_paysage", "L1 à L3"),
    notes = c(
      "Chemin 1 : une seule valeur de paysage, recopiée sur toutes les unités du projet.",
      "Les deux chemins mesurent des choses différentes et basculent sur la seule présence d'un paquet.",
      "indicateur_l2_fragmentation() reste un alias accepté (spec 045)."
    ),
    legende = paste("Le basculement ne dépend pas du terrain mais de l'installation : avec",
                    "`landscapemetrics`, L2 décrit le massif ; sans lui, il décrit la forme du",
                    "polygone. Deux lectures opposées de la même colonne.")
  ),

  L3 = list(
    code = "L3", fichier = "fiche-l3-heterogeneite-spectrale_fr.Rmd",
    titre = paste("Chaine de calcul de L3 : les trois premiers axes d'une PCoA de",
                  "Bray-Curtis entre fenetres spectrales servent d'espace",
                  "d'ordination, et L3 est la distance moyenne des fenetres de",
                  "l'unite a son propre centroide, normalisee par un plafond",
                  "provisoire de 0,5 ; moins de trois fenetres couvertes rendent NA."),
    liaison = "puis",
    entrees = list(
      list(titre = "Sentinel-2 — objet spectral", lignes = c("compute_spectral_diversity()",
                                                             "partagé avec B4 (diversité α)")),
      list(titre = "Moins de min_windows fenêtres", lignes = "L3 = NA (défaut : 3)", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "PCoA de Bray-Curtis", lignes = c("3 axes d'ordination", "biodivMapR")),
      list(titre = "Dispersion multivariée", lignes = c("distance moyenne au centroïde",
                                                        "betadisper (Anderson)"))
    ),
    aval = av("indicateur_l3_het_spectrale", "dispersion, sans unité",
              "min(100, disp / 0,5 × 100)", "L", "famille_paysage", "L1 à L3"),
    notes = c(
      "Correctif 0.190.0 : avant, les 3 axes étaient moyennés — on mesurait une position, pas une dispersion.",
      "Les L3 calculés avant cette version sont inexploitables, pas seulement imprécis.",
      "Plafond 0,5 provisoire et sous-utilisé : le maximum observé sur le jeu de référence est 0,44."
    ),
    legende = paste("Une dispersion, pas une position. C'est exactement ce que le correctif",
                    "0.190.0 a rétabli : la distance des fenêtres à leur centroïde mesure",
                    "l'hétérogénéité ; leur moyenne, elle, ne mesurait rien.")
  ),
  # ======================================================== N — Naturalité ===
  N1 = list(
    code = "N1", fichier = "fiche-n1-distance_fr.Rmd",
    titre = paste("Chaine de calcul de N1 : depuis le centroide de l'unite, deux",
                  "distances mesurees — aux routes, au bati — et un troisieme terme",
                  "qui n'est pas une mesure mais une constante de 2 000 m, laquelle",
                  "ajoute un quart de score fixe a toutes les unites."),
    liaison = "+",
    entrees = list(
      list(titre = "BD TOPO — routes", lignes = "st_distance(centroïde, union)", vers = 1),
      list(titre = "BD TOPO — bâti", lignes = "st_distance(centroïde, union)", vers = 2),
      list(titre = "« Zones urbaines »", lignes = c("aucune couche n'existe",
                                                    "constante figée à 2 000 m"), tirets = TRUE, vers = 3)
    ),
    chemins = list(
      list(titre = "Routes — 40 %", lignes = "pmin(100, d_routes / 20)"),
      list(titre = "Bâti — 35 %", lignes = "pmin(100, d_bati / 20)"),
      list(titre = "Urbain — 25 %", lignes = c("pmin(100, 2000/20) = 100", "soit +25 fixe"), tirets = TRUE)
    ),
    aval = av("indicateur_n1_distance", "score 0–100, natif",
              "écrêtage natif 0–100", "N", "famille_naturalite", "N1 à N3"),
    notes = c(
      "N1 a deux sources de données, pas trois : le terme urbain vaut toujours 100 et n'a rien mesuré.",
      "Sans couche, la distance vaut NA — plus de distance inventée (correctif).",
      "Le calcul part du centroïde : une lanière qui longe une route peut avoir un centroïde éloigné.",
      "N1 et S1/S2 notent la même géométrie en sens contraire — un radar ne peut monter des deux côtés."
    ),
    legende = paste("Trois termes, dont un qui n'est pas une donnée. Le +25 constant relève le",
                    "plancher de N1 pour toutes les unités : la variabilité utile se joue sur",
                    "les 75 points restants.")
  ),

  N2 = list(
    code = "N2", fichier = "fiche-n2-continuite_fr.Rmd",
    titre = paste("Chaine de calcul de N2 : le couvert forestier actuel est croise",
                  "avec un couvert historique, mono-epoque ou multi-epoques ; une",
                  "foret presente aux deux dates est continue, une foret recente sur",
                  "ancienne terre agricole ne l'est pas, et l'absence des deux",
                  "couches rend NA."),
    liaison = "puis",
    entrees = list(
      list(titre = "BD Forêt — couvert actuel", lignes = "bdforet (sf)"),
      list(titre = "Couche foret_ancienne", lignes = c("mono-époque : simple masque",
                                                       "multi : colonne anciennete")),
      list(titre = "Aucune des deux couches", lignes = "N2 = NA", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Croisement des deux époques", lignes = c("présent aux deux = continu",
                                                             "récent sur agricole = non")),
      list(titre = "Pondération d'ancienneté", lignes = c("weight_anciennete",
                                                          "nb d'époques couvertes"), tirets = TRUE)
    ),
    aval = av("indicateur_n2_continuite", "score 0–100, natif",
              "écrêtage natif 0–100", "N", "famille_naturalite", "N1 à N3"),
    notes = c(
      "La continuité n'est pas la naturalité : une plantation d'épicéa sur sol forestier ancien score haut.",
      "N2 alimente aussi T2 en proxy de stabilité dès que la colonne est présente.",
      "La couche multi-époques vient de build_foret_ancienne_mask() — Corona et cartes d'état-major (spec 031)."
    ),
    legende = paste("Un croisement de deux dates, pas une mesure d'état. Ce que N2 sait, c'est",
                    "que le sol est resté forestier — pas ce qui y pousse aujourd'hui.")
  ),

  N3 = list(
    code = "N3", fichier = "fiche-n3-naturalite_fr.Rmd",
    titre = paste("Chaine de calcul de N3 : un composite de quatre colonnes deja",
                  "calculees — N1, N2, L1 retourne en anti-fragmentation, et B3 —",
                  "dont deux appartiennent a d'autres familles ; l'absence d'une",
                  "seule des quatre rend NA, sans calcul partiel."),
    liaison = "puis",
    entrees = list(
      list(titre = "Colonne N1 — éloignement", lignes = "poids 0,35"),
      list(titre = "Colonne N2 — continuité", lignes = "poids 0,35"),
      list(titre = "Colonne L1 — effet de lisière", lignes = "entre inversée, poids 0,15"),
      list(titre = "Colonne B3 — connectivité", lignes = "poids 0,15")
    ),
    chemins = list(
      list(titre = "Inversion de L1", lignes = "anti_frag = 100 - L1"),
      list(titre = "Composite pondéré", lignes = c("0,35·N1 + 0,35·N2",
                                                   "+ 0,15·anti_frag + 0,15·B3"))
    ),
    aval = av("indicateur_n3_naturalite", "score 0–100, natif",
              "écrêtage natif 0–100", "N", "famille_naturalite", "N1 à N3"),
    notes = c(
      "NA dès qu'une des quatre entrées manque : pas de calcul partiel, pas de valeur dégradée.",
      "Composite : N1 et N2 pèsent 70 %, et N1 porte déjà son terme urbain constant.",
      "L1 entre inversé (100 - L1) alors que la normalisation, elle, le lit à l'endroit."
    ),
    legende = paste("Un indicateur qui ne lit aucune donnée : ses quatre entrées sont des",
                    "colonnes. Les défauts de N1, L1 et B3 se propagent donc dans N3, avec",
                    "leurs poids — dont le +25 constant de N1.")
  ),
  # ====================================================== P — Production =====
  P1 = list(
    code = "P1", fichier = "fiche-p1-volume_fr.Rmd",
    titre = paste("Chaine de calcul de P1 : un tarif IFN a variable combinee cube",
                  "l'arbre moyen a partir du diametre et d'une hauteur cherchee dans",
                  "trois sources successives — CHM, colonne fournie, relation de",
                  "secours — puis multiplie par la densite en tiges par hectare."),
    liaison = "puis",
    entrees = list(
      list(titre = "CHM ML ou MNH LiDAR", lignes = "extract_h_dom(chm, p90)", vers = 1),
      list(titre = "Colonne height_field", lignes = "hauteur d'inventaire", vers = 1),
      list(titre = "Ni CHM ni hauteur", lignes = "H = 1,3 + 0,65 × D (secours)", tirets = TRUE, vers = 1),
      list(titre = "dbh et density", lignes = c("ensure_inventory_fields()",
                                                "density en tiges/ha"), vers = 2)
    ),
    chemins = list(
      list(titre = "Cubage de l'arbre moyen", lignes = c("V = a × D² × H",
                                                         "tarif IFN, b = 2, c = 1")),
      list(titre = "Passage à l'hectare", lignes = "P1 = V × N   (m³/ha)")
    ),
    aval = av("indicateur_p1_volume", "volume sur pied, m³/ha",
              "min(100, V / 800 × 100)", "P", "famille_production", "P1 à P3"),
    notes = c(
      "Correctif 0.169.0 (spec 040) : les exposants erronés gonflaient P1 de 3 à 5 — les anciennes valeurs sont à recalculer.",
      "H = 1,3 + 0,65 × D est une relation de secours, pas une allométrie d'essence.",
      "method = \"allometric\" n'existe pas : le dispatch n'a jamais été branché.",
      "density est ici en tiges/ha — le chemin 1 de C1 l'attend en 0–1 : ne pas recycler la colonne."
    ),
    legende = paste("Le tarif ne change pas, la hauteur si. C'est la source de H — CHM mesuré,",
                    "hauteur d'inventaire ou relation de secours — qui décide de ce que vaut",
                    "réellement un P1, et rien dans la colonne ne le dit.")
  ),

  P2 = list(
    code = "P2", fichier = "fiche-p2-station_fr.Rmd",
    titre = paste("Chaine de calcul de P2 : la hauteur dominante, mesuree au CHM ou",
                  "fournie, est ramenee a l'age de reference par les courbes de",
                  "Duplat et Tran-Ha ; l'age, souvent moins bien connu que la",
                  "hauteur, pese donc autant qu'elle sur le resultat."),
    liaison = "puis",
    entrees = list(
      list(titre = "CHM ML ou MNH LiDAR", lignes = "extract_h_dom(chm, p90)"),
      list(titre = "Âge du peuplement", lignes = c("colonne d'inventaire", "ou déduit de BD Forêt")),
      list(titre = "Essence", lignes = "list_site_index_species()")
    ),
    chemins = list(
      list(titre = "Hauteur dominante", lignes = "H_dom = p90 des hauteurs"),
      list(titre = "Courbes Duplat & Tran-Ha", lignes = c("compute_site_index()",
                                                          "site_index_curves.csv",
                                                          "H₀ à l'âge de référence"))
    ),
    aval = av("indicateur_p2_station", "H₀ en mètres",
              "min(100, H₀ / 15 × 100)", "P", "famille_production", "P1 à P3"),
    notes = c(
      "L'âge pèse autant que la hauteur, et il est souvent estimé — un âge faux déplace H₀ d'autant.",
      "Les courbes ne valent que pour des peuplements réguliers purs ; en futaie irrégulière, H₀ n'a pas de sens.",
      "ref_max = 15 est une hauteur : un H₀ de 15 m à l'âge de référence sature le score."
    ),
    legende = paste("Deux entrées de qualité très inégale. La hauteur vient d'une mesure",
                    "métrique, l'âge d'une déduction — et les courbes de station amplifient",
                    "l'erreur sur l'âge, surtout aux âges jeunes.")
  ),

  P3 = list(
    code = "P3", fichier = "fiche-p3-qualite-bois_fr.Rmd",
    titre = paste("Chaine de calcul de P3 : le diametre est compare a deux seuils de",
                  "commercialisation qui dependent du type d'essence — resineux ou",
                  "feuillu, reconnus par un motif sur le code — et une note de forme",
                  "de terrain ne s'ajoute qu'a partir du NDP 3."),
    liaison = "puis",
    entrees = list(
      list(titre = "dbh — diamètre", lignes = "ensure_inventory_fields(), CHM"),
      list(titre = "Code essence", lignes = c("motif PI*, PM*, PL* = résineux",
                                              "inconnue -> seuils 35 / 18 cm")),
      list(titre = "form_score_field (NDP 3+)", lignes = "rectitude, branchaison, défauts", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Seuils par type d'essence", lignes = c("résineux : 30 / 15 cm",
                                                           "feuillus : 40 / 20 cm")),
      list(titre = "Composante diamètre", lignes = c("D ≥ œuvre        -> 100",
                                                     "trit. ≤ D < œuvre -> 50-100",
                                                     "D < trituration   -> < 50")),
      list(titre = "Composante forme", lignes = "note de terrain, si fournie", tirets = TRUE)
    ),
    aval = av("indicateur_p3_qualite_bois", "score 0–100, natif",
              "écrêtage natif 0–100", "P", "famille_production", "P1 à P3"),
    notes = c(
      "30 cm vaut 100 pour un résineux et 75 pour un feuillu : les seuils de commercialisation diffèrent, et c'est voulu.",
      "Sans essence renseignée, les seuils génériques 35/18 cm s'appliquent sans avertissement.",
      "En dessous du NDP 3, la forme est absente — or c'est elle qui fait la qualité d'un bois d'œuvre."
    ),
    legende = paste("Un score de diamètre qui porte le nom de qualité. Tant que la note de",
                    "forme n'est pas relevée, P3 dit seulement que les tiges ont atteint le",
                    "seuil de commercialisation, pas qu'elles valent quelque chose.")
  ),
  # ========================================================== E — Énergie ====
  E1 = list(
    code = "E1", fichier = "fiche-e1-bois-energie_fr.Rmd",
    titre = paste("Chaine de calcul de E1 : le volume sur pied P1 est preleve a 2 %",
                  "par an, 30 % de cette recolte part en remanents, convertis en",
                  "matiere seche par la densite de l'essence, puis additionnes d'un",
                  "forfait taillis de 2 tonnes par hectare et par an ; trois",
                  "constantes portent donc tout le resultat."),
    liaison = "puis",
    entrees = list(
      list(titre = "P1 — volume sur pied", lignes = c("colonne, ou calculé à la volée",
                                                      "hérite des propriétés de P1")),
      list(titre = "wood_density.csv — ρ", lignes = "550 kg/m³ si essence inconnue"),
      list(titre = "Fraction de taillis", lignes = "forfait 2 t MS/ha/an, en dur")
    ),
    chemins = list(
      list(titre = "Récolte annuelle", lignes = c("V × harvest_rate", "défaut 2 % / an")),
      list(titre = "Rémanents en matière sèche", lignes = c("récolte × 30 %",
                                                            "× ρ/1000 × 0,5")),
      list(titre = "Somme des deux gisements", lignes = "E1 = rémanents + taillis")
    ),
    aval = av("indicateur_e1_bois_energie", "t MS / ha / an",
              "min(100, t / 0,3 × 100)", "E", "famille_energie", "E1 et E2"),
    notes = c(
      "Le plafond de 0,3 t MS/ha/an sature dès 150 m³/ha environ : la moitié du domaine forestier est à 100.",
      "Trois constantes portent le résultat — taux de récolte 2 %, fraction rémanents 30 %, forfait taillis 2 t.",
      "La récolte de 2 % est une hypothèse de gestion, pas une mesure de prélèvement réel."
    ),
    legende = paste("Une chaîne de coefficients appliquée à P1. E1 ne mesure pas un gisement",
                    "observé : il décrit ce que produirait une gestion conventionnelle",
                    "appliquée uniformément à toutes les unités.")
  ),

  E2 = list(
    code = "E2", fichier = "fiche-e2-evitement_fr.Rmd",
    titre = paste("Chaine de calcul de E2 : le gisement E1 est converti en kilowatt-",
                  "heures puis en emissions fossiles evitees par un facteur ADEME,",
                  "auxquelles s'ajoute la substitution materiau ; la chaine est",
                  "multiplicative, donc chaque hypothese amont s'y propage entiere."),
    liaison = "+",
    entrees = list(
      list(titre = "E1 — gisement bois-énergie", lignes = "t MS / ha / an", vers = 1),
      list(titre = "Volume de bois d'œuvre", lignes = "voie matériau", vers = 2),
      list(titre = "Facteurs ADEME", lignes = c("ademe_emission_factors.csv",
                                                "repli 0,222 kgCO₂eq/kWh"))
    ),
    chemins = list(
      list(titre = "Substitution énergie", lignes = c("kWh = t MS × 4 500",
                                                      "× facteur / 1000")),
      list(titre = "Substitution matériau", lignes = c("volume bois d'œuvre",
                                                       "× facteur ADEME"))
    ),
    aval = av("indicateur_e2_evitement", "t CO₂eq / ha / an",
              "min(100, t / 0,75 × 100)", "E", "famille_energie", "E1 et E2"),
    notes = c(
      "Chaîne multiplicative : taux de récolte, fraction rémanents, densité, PCI, facteur ADEME — chaque hypothèse s'y propage.",
      "Le facteur de substitution dépend de l'énergie remplacée : le scénario est paramétrable, et il compte.",
      "E2 est un flux évité, pas un stock : il ne s'additionne pas à C1."
    ),
    legende = paste("Deux voies de substitution, une seule colonne. Le scénario énergétique",
                    "retenu change le résultat autant que la forêt elle-même — le consigner",
                    "avec la valeur est la condition pour la relire plus tard.")
  ),

  # =========================================================== S — Social ====
  S1 = list(
    code = "S1", fichier = "fiche-s1-routes_fr.Rmd",
    titre = paste("Chaine de calcul de S1 : les routes sont rasterisees sur la grille",
                  "du MNT, la distance est calculee en mode raster puis moyennee sur",
                  "l'unite, et le score decroit lineairement jusqu'a s'annuler a",
                  "2 000 metres — la resolution du MNT etant la granularite reelle",
                  "de l'indicateur."),
    liaison = "puis",
    entrees = list(
      list(titre = "BD TOPO — routes", lignes = "couche roads (vecteur)"),
      list(titre = "MNT — grille de calcul", lignes = "fixe la résolution de S1"),
      list(titre = "MNT ou routes manquants", lignes = "S1 = NA", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Rasterisation", lignes = "routes sur la grille du MNT"),
      list(titre = "Distance raster", lignes = c("terra::distance()",
                                                 "moyenne zonale, en mètres"))
    ),
    aval = av("indicateur_s1_routes", "distance moyenne, m",
              "100 × (1 - d / 2000)", "S", "famille_social", "S1 à S3"),
    notes = c(
      "Le sens est inversé par rapport au nom : proche = accessible = score haut.",
      "Le plafond de 2 000 m écrase le domaine forestier profond — tout ce qui est au-delà vaut 0.",
      "S1 et N1 notent la même géométrie en sens contraire : accessibilité contre naturalité."
    ),
    legende = paste("Une distance raster, pas vectorielle. La grille du MNT est le vrai pas de",
                    "mesure : sur un MNT à 25 m, une piste et sa parcelle riveraine peuvent",
                    "tomber dans le même pixel.")
  ),

  S2 = list(
    code = "S2", fichier = "fiche-s2-bati_fr.Rmd",
    titre = paste("Chaine de calcul de S2 : meme mecanique que S1, appliquee a la",
                  "couche du bati — rasterisation sur la grille du MNT, distance",
                  "raster, moyenne zonale, puis la meme decroissance lineaire",
                  "jusqu'a 2 000 metres ; routes et bati etant co-localises, S1 et",
                  "S2 varient largement ensemble."),
    liaison = "puis",
    entrees = list(
      list(titre = "BD TOPO — bâti", lignes = "couche buildings (vecteur)"),
      list(titre = "MNT — grille de calcul", lignes = "fixe la résolution de S2"),
      list(titre = "MNT ou bâti manquants", lignes = "S2 = NA", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Rasterisation", lignes = "bâti sur la grille du MNT"),
      list(titre = "Distance raster", lignes = c("terra::distance()",
                                                 "moyenne zonale, en mètres"))
    ),
    aval = av("indicateur_s2_bati", "distance moyenne, m",
              "100 × (1 - d / 2000)", "S", "famille_social", "S1 à S3"),
    notes = c(
      "S1 et S2 sont fortement corrélés : routes et bâti sont co-localisés, la famille S compte deux fois la même géographie.",
      "Même plafond de 2 000 m, mêmes effets de saturation qu'en S1.",
      "Comme S1, le score monte quand la distance baisse — c'est un indicateur d'accessibilité."
    ),
    legende = paste("Le jumeau de S1, sur une autre couche. La redondance n'est pas un défaut",
                    "d'implémentation mais un fait de terrain : là où il y a des maisons, il y",
                    "a des routes — et la famille S en tient deux fois compte.")
  ),

  S3 = list(
    code = "S3", fichier = "fiche-s3-population_fr.Rmd",
    titre = paste("Chaine de calcul de S3 : la population est sommee dans des",
                  "couronnes de 5, 10 et 20 km, ramenee a une densite, puis portee",
                  "sur une echelle logarithmique qui sature a 1 000 habitants au",
                  "kilometre carre ; sans grille de population, S3 vaut NA."),
    liaison = "puis",
    entrees = list(
      list(titre = "Grille de population INSEE", lignes = "ou équivalent local"),
      list(titre = "Couronnes 5, 10 et 20 km", lignes = "colonnes S3_5km, S3_10km, S3_20km"),
      list(titre = "Aucune grille fournie", lignes = "S3 = NA", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Somme par couronne", lignes = "population dans chaque rayon"),
      list(titre = "Densité, puis échelle log", lignes = c("100 × log10(1+d) / log10(1001)",
                                                           "1 000 hab/km² -> 100"))
    ),
    aval = av("indicateur_s3_population", "densité, hab/km²",
              "log10 — plafond 1 000", "S", "famille_social", "S1 à S3"),
    notes = c(
      "L'échelle log est un choix : la grandeur couvre trois ordres de grandeur, du massif isolé au périurbain.",
      "Au-delà de 300 hab/km², la forêt est périurbaine — 400 ou 900 cesse d'être informatif.",
      "Les trois colonnes de rayon ne sont pas agrégées dans la famille : seule la principale y entre."
    ),
    legende = paste("Trois couronnes mesurées, une seule dans le score. Les colonnes annexes",
                    "distinguent une forêt de proximité d'une forêt de bassin de vie — une",
                    "nuance que le score agrégé, lui, ne porte pas.")
  ),
  # ======================================================== T — Temporel =====
  T1 = list(
    code = "T1", fichier = "fiche-t1-anciennete_fr.Rmd",
    titre = paste("Chaine de calcul de T1 : quatre chemins essayes en cascade — age",
                  "typologique de la BD Foret, colonne d'age, annee d'installation,",
                  "conversion du NDVI en annees — et, si aucun ne repond, un age de",
                  "50 ans ecrit en dur ; la colonne est en annees mais la",
                  "normalisation la traite comme un score."),
    entrees = list(
      list(titre = "BD Forêt — champ TFV", lignes = c("TFV, CODE_TFV, ESSENCE, LIB_FV…",
                                                      ".estimate_age_tfv()"), vers = 1),
      list(titre = "Colonne age", lignes = "âge d'inventaire, tel quel", vers = 2),
      list(titre = "establishment_year_field", lignes = "année courante - installation", vers = 3),
      list(titre = "Couche ndvi", lignes = "Sentinel-2, 10 m", vers = 4),
      list(titre = "Aucun des quatre", lignes = "50 ans en dur + avertissement", tirets = TRUE, vers = 5)
    ),
    chemins = list(
      list(titre = "Âge typologique", lignes = c("constante par type",
                                                 "futaie feuillue fermée : 100 ans")),
      list(titre = "Âge d'inventaire", lignes = "valeur reprise sans calcul"),
      list(titre = "Année d'installation", lignes = "âge = année - installation"),
      list(titre = "Conversion du NDVI", lignes = "20 + max(0, NDVI-0,2)/0,6 × 100"),
      list(titre = "50 ans, en dur", lignes = "âge fabriqué, pas NA", tirets = TRUE)
    ),
    aval = av("indicateur_t1_anciennete", "âge, en années",
              "écrêtage à 100 (années)", "T", "famille_temporel", "T1 à T3"),
    notes = c(
      "L'unité est l'année, la normalisation croit lire un score : au-delà de 100 ans, tout est écrêté à 100.",
      "Sans aucune donnée, T1 vaut 50 — un âge fabriqué qui ne se distingue pas d'un âge mesuré.",
      "Le chemin NDVI convertit de la verdeur en années : un peuplement vert et jeune y paraît vieux.",
      "L'âge TFV est une constante par type : toutes les futaies feuillues fermées ont le même âge."
    ),
    legende = paste("Cinq issues pour une colonne en années. L'écrêtage à 100 confond une futaie",
                    "de 110 ans et une de 250 ans, et le dernier recours — 50 ans en dur — se lit",
                    "comme n'importe quelle autre valeur.")
  ),

  T2 = list(
    code = "T2", fichier = "fiche-t2-changement_fr.Rmd",
    titre = paste("Chaine de calcul de T2 : l'indicateur ne mesure rien en propre, il",
                  "recopie la continuite N2 quand elle existe, sinon l'age T1",
                  "plafonne a 100, et remplace les ages inconnus par 50 — d'ou un",
                  "double comptage possible dans la famille temporelle."),
    entrees = list(
      list(titre = "Colonne N2 — continuité", lignes = "ou N2_anciennete / N2_anciennet", vers = 1),
      list(titre = "t1_values — âge T1", lignes = "utilisé seulement sans N2", vers = 2)
    ),
    chemins = list(
      list(titre = "N2 comme proxy", lignes = "T2 = N2, écrêté [0, 100]"),
      list(titre = "T1 plafonné", lignes = c("T2 = min(100, âge)",
                                             "NA remplacés par 50"))
    ),
    aval = av("indicateur_t2_changement", "score 0–100, natif",
              "écrêtage natif 0–100", "T", "famille_temporel", "T1 à T3"),
    notes = c(
      "NA devient 50 sur le chemin 2 : une unité d'âge inconnu se lit comme une unité moyennement stable.",
      "Quand T2 recopie T1, famille_temporel compte deux fois la même grandeur.",
      "Le nom annonce un changement, la valeur mesure une stabilité — haut = stable."
    ),
    legende = paste("Un indicateur dérivé, pas mesuré. Avant de lire une famille T, vérifier",
                    "lequel des deux chemins a servi : sur le second, T1 et T2 portent la même",
                    "information sous deux noms.")
  ),

  T3 = list(
    code = "T3", fichier = "fiche-t3-coupes-rases_fr.Rmd",
    titre = paste("Chaine de calcul de T3 : les dates et les probabilites SUFOSAT",
                  "sont empilees pour une extraction unique, la part de l'unite",
                  "coupee dans les cinq dernieres annees au-dela de 0,9 de",
                  "probabilite est retenue, puis le sens est inverse a la",
                  "normalisation — score = 100 moins la valeur brute."),
    liaison = "puis",
    entrees = list(
      list(titre = "SUFOSAT — dates de coupe", lignes = c("CNES/CESBIO, suivi submensuel",
                                                          "fenêtre window_years = 5")),
      list(titre = "SUFOSAT — probabilité", lignes = "seuil min_proba = 0,9"),
      list(titre = "SUFOSAT non fourni", lignes = "T3 non calculé (conditionnel)", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Empilement des deux rasters", lignes = c("une seule extraction",
                                                             "alignement pixel à pixel")),
      list(titre = "Part de l'unité coupée", lignes = c("pixels retenus / unité × 100",
                                                        "T3 brut : haut = coupé"))
    ),
    aval = list(
      list(titre = "indicateur_t3_coupes_rases", lignes = "brut : haut = beaucoup coupé", accent = TRUE),
      list(titre = "normalize_indicator()", lignes = c("score = 100 - valeur", "comme R1 à R5 (spec 048)")),
      list(titre = "create_family_index(\"T\")", lignes = c("famille_temporel", "moyenne de T1 à T3")),
      list(titre = "compute_general_index()", lignes = "Fibonacci · confiance φ")
    ),
    notes = c(
      "Le sens brut est inversé par rapport au score : ne jamais lire la colonne brute comme un score.",
      "Une coupe rase n'est pas nécessairement une anomalie — T3 pénalise une pratique sylvicole légitime.",
      "min_proba = 0,9 est strict et délibéré : abaisser le seuil ferait entrer des détections douteuses."
    ),
    legende = paste("Un des six indicateurs — R1 à R5 et lui — dont la normalisation retourne le sens.",
                    "La colonne brute mesure une pression de coupe ; le score, lui, mesure son",
                    "absence — deux lectures opposées du même nombre.")
  ),
  # ============================================================ R — Risques ==
  R1 = list(
    code = "R1", fichier = "fiche-r1-feu_fr.Rmd",
    titre = paste("Chaine de calcul de R1 : deux modes selon qu'un paquet optionnel",
                  "est installe — une exposition calculee par fireexposuR, ou une",
                  "moyenne ponderee de pente, essence et climat ; la valeur brute",
                  "monte avec le risque et c'est la normalisation qui la retourne.",
                  "Le combustible de surface n'entre dans aucun des deux."),
    liaison = "ou",
    entrees = list(
      list(titre = "MNT — obligatoire", lignes = "sans lui, R1 = NA"),
      list(titre = "fireexposuR + bdforet", lignes = "paquet Suggests installé", vers = 1),
      list(titre = "Essence et proxy climatique", lignes = "get_species_flammability()", vers = 2)
    ),
    chemins = list(
      list(titre = "Mode fireexposuR", lignes = c("fire_exp(hazard, t_dist = 500)",
                                                  "expo 0,50 · pente 0,25 · reste 0,25")),
      list(titre = "Mode pondéré (défaut)", lignes = c("pente 1/3 · essence 1/3",
                                                       "climat 1/3, poids renormalisés"))
    ),
    aval = list(
      list(titre = "indicateur_r1_feu", lignes = "brut : haut = risque élevé", accent = TRUE),
      list(titre = "normalize_indicator()", lignes = c("score = 100 - valeur", "R1 à R5 (spec 048)")),
      list(titre = "create_family_index(\"R\")", lignes = c("famille_risque", "moyenne de R1 à R7")),
      list(titre = "compute_general_index()", lignes = "Fibonacci · confiance φ")
    ),
    notes = c(
      "La pente retombe sur 50 si son calcul échoue, sans avertissement — un tiers du score figé.",
      "Les deux modes ne mesurent pas la même chose : une exposition spatiale d'un côté, un aléa composite de l'autre.",
      "Le combustible de surface — herbacée, litière, rémanents — n'entre nulle part."
    ),
    legende = paste("Le mode dépend de l'installation, pas du terrain. Deux postes différents",
                    "rendent deux R1 différents sur le même massif : consigner le mode servi",
                    "avec la valeur.")
  ),

  R2 = list(
    code = "R2", fichier = "fiche-r2-tempete_fr.Rmd",
    titre = paste("Chaine de calcul de R2 : une exposition au vent, prise a l'ouest",
                  "par defaut quand l'API NASA POWER ne repond pas, multiplie un",
                  "terme de relief melant pente et rugosite, le tout module par la",
                  "hauteur dominante et l'essence quand un CHM est fourni."),
    liaison = "puis",
    entrees = list(
      list(titre = "MNT — obligatoire", lignes = "pente et TRI ; sans lui, NA"),
      list(titre = "get_nasapower_wind()", lignes = c("direction dominante",
                                                      "défaut 270° (ouest) en dur")),
      list(titre = "CHM ML (optionnel)", lignes = "H_dom et essence dominante", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Terme de relief", lignes = "0,6 × pente + 0,4 × TRI"),
      list(titre = "Exposition au vent", lignes = c("× exposition_vent × 100",
                                                    "microclima::windcoef() si présent")),
      list(titre = "Modulation canopée", lignes = c("f = (H_dom / h_ref) × essence",
                                                    "résineux 1,2 · feuillus 0,8"), tirets = TRUE)
    ),
    aval = list(
      list(titre = "indicateur_r2_tempete", lignes = "brut : haut = vulnérable", accent = TRUE),
      list(titre = "normalize_indicator()", lignes = c("score = 100 - valeur", "R1 à R5 (spec 048)")),
      list(titre = "create_family_index(\"R\")", lignes = c("famille_risque", "moyenne de R1 à R7")),
      list(titre = "compute_general_index()", lignes = "Fibonacci · confiance φ")
    ),
    notes = c(
      "270° en dur : sans réponse de NASA POWER, tout le massif est réputé exposé à l'ouest.",
      "microclima est optionnel, et son absence change le coefficient d'abri sans le dire.",
      "La modulation canopée est multiplicative et non bornée par le bas : un CHM bas efface la vulnérabilité."
    ),
    legende = paste("Un produit, pas une somme : chaque facteur peut annuler les autres. C'est",
                    "ce qui rend R2 sensible à des entrées optionnelles — direction du vent,",
                    "coefficient d'abri, hauteur de canopée.")
  ),

  R3 = list(
    code = "R3", fichier = "fiche-r3-secheresse_fr.Rmd",
    titre = paste("Chaine de calcul de R3 : un bilan hydrique BILJOU court-circuite",
                  "tout le reste quand il est fourni ; sinon le risque melange un",
                  "terme climatique tire du SPEI — calcule en un seul point pour",
                  "tout le projet, et remplace par 0,5 s'il echoue — et un terme",
                  "topographique d'exposition, pente et TWI."),
    entrees = list(
      list(titre = "Bilan hydrique BILJOU", lignes = "argument biljou", vers = 1),
      list(titre = "SPEI-3", lignes = c("un seul point : centroïde",
                                        "de l'union des unités"), vers = 2),
      list(titre = "MNT — exposition, pente, TWI", lignes = "terme topographique", vers = 2),
      list(titre = "Produit neige (optionnel)", lignes = "snow_relief_strength = 0,3", tirets = TRUE, vers = 2)
    ),
    chemins = list(
      list(titre = "Chemin BILJOU", lignes = c(".r3_biljou_stress()", "écrêté [0, 100]")),
      list(titre = "Climat + topographie", lignes = c("climat = (-SPEI + 2)/4",
                                                      "topo = 0,4 asp + 0,3 pente",
                                                      "       + 0,3 twi",
                                                      "(0,6 clim + 0,4 topo) × 100"))
    ),
    aval = list(
      list(titre = "indicateur_r3_secheresse", lignes = "brut : haut = risque élevé", accent = TRUE),
      list(titre = "normalize_indicator()", lignes = c("score = 100 - valeur", "R1 à R5 (spec 048)")),
      list(titre = "create_family_index(\"R\")", lignes = c("famille_risque", "moyenne de R1 à R7")),
      list(titre = "compute_general_index()", lignes = "Fibonacci · confiance φ")
    ),
    notes = c(
      "La composante climatique retombe sur 0,5 en dur quand le SPEI échoue : 60 % du score devient une constante.",
      "Le SPEI est calculé au centroïde de l'union : toutes les unités partagent le même climat.",
      "Le chemin BILJOU court-circuite le reste — deux projets ne se comparent pas s'ils n'ont pas pris le même."
    ),
    legende = paste("Deux chemins, deux natures. BILJOU produit un bilan hydrique par unité ;",
                    "le chemin par défaut mélange un climat unique pour tout le projet et une",
                    "topographie locale — seul le second terme distingue les unités.")
  ),

  R4 = list(
    code = "R4", fichier = "fiche-r4-abroutissement_fr.Rmd",
    titre = paste("Chaine de calcul de R4 : quatre composantes a poids figes dans le",
                  "code — appetence de l'essence dominante, vulnerabilite du",
                  "peuplement, effet de lisiere, densite de gibier departementale —",
                  "produisent une pression de gibier que la normalisation retourne",
                  "ensuite en score favorable."),
    liaison = "+",
    entrees = list(
      list(titre = "BD Forêt — essence dominante", lignes = "get_species_palatability()", vers = 1),
      list(titre = "Stade et structure", lignes = "vulnérabilité du peuplement", vers = 2),
      list(titre = "Géométrie et voisinage", lignes = "effet de lisière", vers = 3),
      list(titre = "Tableaux de chasse (hunting)", lignes = "maille départementale", vers = 4)
    ),
    chemins = list(
      list(titre = "Appétence — 0,35", lignes = "essence dominante adulte"),
      list(titre = "Vulnérabilité — 0,30", lignes = "stade et structure"),
      list(titre = "Effet de lisière — 0,20", lignes = "géométrie et voisinage"),
      list(titre = "Densité de gibier — 0,15", lignes = "tableaux départementaux")
    ),
    aval = list(
      list(titre = "indicateur_r4_abroutissement", lignes = "brut : haut = forte pression", accent = TRUE),
      list(titre = "normalize_indicator()", lignes = c("score = 100 - valeur", "R1 à R5 (spec 048)")),
      list(titre = "create_family_index(\"R\")", lignes = c("famille_risque", "moyenne de R1 à R7")),
      list(titre = "compute_general_index()", lignes = "Fibonacci · confiance φ")
    ),
    notes = c(
      "La densité de gibier est départementale : toutes les unités d'un même département partagent ce terme.",
      "L'appétence porte sur l'essence dominante adulte, pas sur ce que le gibier broute réellement en régénération.",
      "Les poids sont figés dans le code : aucun argument ne les expose."
    ),
    legende = paste("Quatre composantes, deux échelles. Deux d'entre elles décrivent l'unité,",
                    "les deux autres un contexte départemental ou de voisinage — R4 discrimine",
                    "donc moins finement que sa formule ne le suggère.")
  ),
  R5 = list(
    code = "R5", fichier = "fiche-r5-deperissement_fr.Rmd",
    titre = paste("Chaine de calcul de R5 : deux pipelines de detection — FORDEAD",
                  "pour les resineux, RECONFORT pour les feuillus — livrent des",
                  "clusters d'alerte dont seules les classes fortes sont retenues,",
                  "ponderees par la confiance calibree sur le rapport ONF/DSF 2024,",
                  "puis rapportees a la surface de l'UGF."),
    liaison = "puis",
    entrees = list(
      list(titre = "FORDEAD — résineux", lignes = c("CRSWIR + modèle harmonique",
                                                    "épicéa, sapin pectiné")),
      list(titre = "RECONFORT — feuillus", lignes = "chêne et autres feuillus"),
      list(titre = "Fraction d'essence cible", lignes = c("min_resineux = min_feuillus = 0,3",
                                                          "sinon skipped_no_resineux"), tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Garde-fou G1", lignes = c("include_low_classes = FALSE",
                                              "seules 3-forte et 4-sol-nu")),
      list(titre = "Intersection des clusters", lignes = "centroïdes × UGF"),
      list(titre = "Somme pondérée", lignes = c("Σ poids × aire / surface UGF",
                                                "plafonné à 1, × 100"))
    ),
    aval = list(
      list(titre = "indicateur_r5_deperissement", lignes = "brut : haut = dépérissement", accent = TRUE),
      list(titre = "normalize_indicator()", lignes = c("score = 100 - valeur", "R1 à R5 (spec 048)")),
      list(titre = "create_family_index(\"R\")", lignes = c("famille_risque", "moyenne de R1 à R7")),
      list(titre = "compute_general_index()", lignes = "Fibonacci · confiance φ")
    ),
    notes = c(
      "Poids 0,10 / 0,30 / 0,82 / 0,70 : calibrés sur 397 relevés terrain (ONF/DSF 2024), pas choisis.",
      "Détection précoce médiocre — 60 % des stades précoces manqués ; confusion mécanique de 25 à 41 %.",
      "NA ne veut pas dire sain : trois causes distinctes se cachent derrière (r5_status les distingue).",
      "Le seuil de 30 % d'essence cible exclut les peuplements mélangés du calcul."
    ),
    legende = paste("Une chaîne dont chaque maille est calibrée sur du terrain. Le garde-fou G1",
                    "écarte les deux classes faibles parce qu'elles portent la moitié des faux",
                    "positifs — c'est un choix de justesse, payé en sensibilité.")
  ),

  R6 = list(
    code = "R6", fichier = "fiche-r6-sensibilite_fr.Rmd",
    titre = paste("Chaine de calcul de R6 : le meme peuplement est simule sous une",
                  "annee caniculaire et sous une annee moyenne, canopee tenue fixe,",
                  "et l'ecart de temperature et de deficit de vapeur mesure sa",
                  "sensibilite ; contrairement a R1-R5, le score n'est pas inverse."),
    liaison = "puis",
    entrees = list(
      list(titre = "microclimate_run() ×2", lignes = c("année caniculaire",
                                                       "année moyenne, canopée figée")),
      list(titre = "microclimate_detect_years()", lignes = "années choisies sur la série E-OBS"),
      list(titre = "Chaîne microclimat non lancée", lignes = "R6 = NA", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Deux écarts", lignes = c("dT   = Tmax(can.) - Tmax(moy.)",
                                             "dVPD = VPD(can.) - VPD(moy.)")),
      list(titre = "Standardisation", lignes = c("dT / 8  et  dVPD / 2",
                                                 "R6 = 100 - standardisation"))
    ),
    aval = list(
      list(titre = "indicateur_r6_sensibilite", lignes = "haut = peu sensible", accent = TRUE),
      list(titre = "normalize_indicator()", lignes = c("passthrough écrêté",
                                                       "PAS d'inversion, contra R1–R5")),
      list(titre = "create_family_index(\"R\")", lignes = c("famille_risque", "moyenne de R1 à R7")),
      list(titre = "compute_general_index()", lignes = "Fibonacci · confiance φ")
    ),
    notes = c(
      "R6 n'est pas inversé alors que R1 à R5 le sont : il est déjà orienté « haut = bon » à la source.",
      "Piège historique : c'est le sensibilite_score 0–100 qu'il faut injecter, jamais le z-score de reGénération (spec 038).",
      "Le choix des deux années détermine tout : une « caniculaire » mal choisie aplatit l'écart."
    ),
    legende = paste("Une différence entre deux simulations, pas un état. La canopée est tenue",
                    "fixe pour que l'écart mesure le climat seul — ce que R6 dit, c'est ce que",
                    "le peuplement encaisserait, pas ce qu'il a subi.")
  ),

  R7 = list(
    code = "R7", fichier = "fiche-r7-gel_fr.Rmd",
    titre = paste("Chaine de calcul de R7 : dans une fenetre de debourrement fixee",
                  "par convention entre les jours 100 et 180, les jours ou la",
                  "temperature minimale passe sous zero sont comptes, puis rapportes",
                  "a un plafond de huit jours ; sans dates portees par le raster,",
                  "la fonction abandonne au lieu de deviner."),
    liaison = "puis",
    entrees = list(
      list(titre = "Raster tmin (SAFRAN, meteoland)", lignes = "dates via terra::time()"),
      list(titre = "Fenêtre de débourrement", lignes = c("budburst_doy = 100",
                                                         "window_end_doy = 180")),
      list(titre = "Raster sans dates", lignes = "abandon explicite, pas de valeur", tirets = TRUE)
    ),
    chemins = list(
      list(titre = "Comptage des gelées", lignes = c("Tmin < frost_threshold_c",
                                                     "défaut 0 °C, moyenne par an")),
      list(titre = "Mise à l'échelle", lignes = c("0 jour        -> 100",
                                                  "max_frost_days -> 0",
                                                  "défaut 8 jours"))
    ),
    aval = list(
      list(titre = "indicateur_r7_gel", lignes = "haut = peu de gel", accent = TRUE),
      list(titre = "normalize_indicator()", lignes = c("passthrough écrêté", "PAS d'inversion")),
      list(titre = "create_family_index(\"R\")", lignes = c("famille_risque", "moyenne de R1 à R7")),
      list(titre = "compute_general_index()", lignes = "Fibonacci · confiance φ")
    ),
    notes = c(
      "Le débourrement est une constante, pas une phénologie : la même fenêtre pour toutes les essences et toutes les altitudes.",
      "Le gel tardif est un phénomène de fond de vallon — sa maille utile est le micro-relief, pas la maille SAFRAN.",
      "Le seuil de 0 °C sous-estime le dégât : les jeunes pousses gèlent avant que l'air n'atteigne zéro."
    ),
    legende = paste("Un comptage de jours dans une fenêtre conventionnelle. Les deux bornes —",
                    "la fenêtre et le seuil de 0 °C — sont des conventions : elles fixent ce que",
                    "R7 appelle « gel tardif » bien plus que le climat local.")
  )
)
