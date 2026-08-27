INDICATOR_FAMILIES <- list(
  C = list(
    code = "C",
    name_fr = "Carbone & Vitalit\u00e9",
    name_en = "Carbon & Vitality",
    description_fr = "Stockage de carbone et vitalit\u00e9 de la v\u00e9g\u00e9tation (biomasse, NDVI)",
    description_en = "Carbon storage and vegetation vitality (biomass, NDVI)",
    icon = "tree-fill",
    color = "#228B22",
    indicators = c("C1", "C2"),
    column_names = c("indicateur_c1_biomasse", "indicateur_c2_ndvi"),
    indicator_labels = list(
      C1 = list(fr = "Biomasse carbone (tC/ha)", en = "Carbon Biomass (tC/ha)"),
      C2 = list(fr = "NDVI - Vitalit\u00e9", en = "NDVI - Vitality")
    ),
    indicator_tooltips = list(
      C1 = list(
        fr = "Stock de carbone dans la biomasse a\u00e9rienne (troncs, branches, feuilles). Estim\u00e9 \u00e0 partir de donn\u00e9es LiDAR ou de mod\u00e8les forestiers. Valeurs typiques : 50-200 tC/ha.",
        en = "Carbon stock in above-ground biomass (trunks, branches, leaves). Estimated from LiDAR data or forest models. Typical values: 50-200 tC/ha."
      ),
      C2 = list(
        fr = "Indice de v\u00e9g\u00e9tation par diff\u00e9rence normalis\u00e9e (NDVI). Mesure la vitalit\u00e9 et l'activit\u00e9 photosynth\u00e9tique de la v\u00e9g\u00e9tation. Valeurs de 0 (sol nu) \u00e0 1 (v\u00e9g\u00e9tation dense).",
        en = "Normalized Difference Vegetation Index (NDVI). Measures vegetation vitality and photosynthetic activity. Values from 0 (bare soil) to 1 (dense vegetation)."
      )
    ),
    # Fiches longues (vignettes pkgdown) : une entree PAR indicateur qui en a
    # une, et DANS CHAQUE LANGUE ou elle existe. L'aval (nemetonshiny) lit
    # `doc_url` dans `indicator_labels()` pour decider s'il affiche un lien
    # « fiche » a cote de l'infobulle. Un indicateur sans fiche n'a pas de cle
    # ici et sort a NA : c'est la condition d'affichage, pas une erreur.
    #
    # C1 n'a qu'une fiche francaise a ce jour. Un appel en `lang = "en"` rend
    # donc l'URL francaise, et `doc_lang` vaut "fr" : l'interface peut le dire
    # au lecteur plutot que d'ouvrir du francais sans prevenir. Le jour ou
    # `fiche-c1-biomasse_en.Rmd` existe, il suffit d'ajouter `en = ...` ici.
    indicator_docs = list(
      C1 = list(fr = "articles/fiche-c1-biomasse_fr.html"),
      C2 = list(fr = "articles/fiche-c2-ndvi_fr.html")
    )
  ),
  B = list(
    code = "B",
    name_fr = "Biodiversit\u00e9",
    name_en = "Biodiversity",
    description_fr = "Protection r\u00e9glementaire, diversit\u00e9 structurale, connectivit\u00e9 \u00e9cologique et diversit\u00e9 spectrale",
    description_en = "Regulatory protection, structural diversity, ecological connectivity and spectral diversity",
    icon = "bug-fill",
    color = "#9932CC",
    indicators = c("B1", "B2", "B3", "B4"),
    column_names = c("indicateur_b1_protection", "indicateur_b2_structure", "indicateur_b3_connectivite", "indicateur_b4_div_spectrale"),
    indicator_labels = list(
      B1 = list(fr = "Protection biodiversit\u00e9", en = "Biodiversity Protection"),
      B2 = list(fr = "Diversit\u00e9 structurale", en = "Structural Diversity"),
      B3 = list(fr = "Connectivit\u00e9 \u00e9cologique", en = "Ecological Connectivity"),
      B4 = list(fr = "Diversit\u00e9 spectrale", en = "Spectral Diversity")
    ),
    indicator_tooltips = list(
      B1 = list(
        fr = "Niveau de protection r\u00e9glementaire (ZNIEFF, Natura 2000, R\u00e9serves). Score de 0 (aucune protection) \u00e0 100 (protection maximale).",
        en = "Level of regulatory protection (ZNIEFF, Natura 2000, Reserves). Score from 0 (no protection) to 100 (maximum protection)."
      ),
      B2 = list(
        fr = "Diversit\u00e9 des strates verticales et horizontales du peuplement. Bas\u00e9 sur l'h\u00e9t\u00e9rog\u00e9n\u00e9it\u00e9 des hauteurs et des essences.",
        en = "Diversity of vertical and horizontal stand structure. Based on height and species heterogeneity."
      ),
      B3 = list(
        fr = "Capacit\u00e9 de la parcelle \u00e0 servir de corridor \u00e9cologique. Mesure la continuit\u00e9 foresti\u00e8re et la proximit\u00e9 d'autres habitats naturels.",
        en = "Parcel's capacity to serve as an ecological corridor. Measures forest continuity and proximity to other natural habitats."
      ),
      B4 = list(
        fr = "Diversit\u00e9 spectrale (\u03b1) d\u00e9riv\u00e9e de Sentinel-2 : indice de Shannon des \u00ab spectral species \u00bb par fen\u00eatre de 100 m, moyenn\u00e9 sur l\u2019unit\u00e9. Le score atteint 100 pour l\u2019\u00e9quivalent de 10 spectral species \u00e9galement abondantes par hectare. Proxy \u00e0 valider terrain ; une futaie r\u00e9guli\u00e8re monosp\u00e9cifique l\u00e9gitime peut avoir un score bas.",
        en = "Spectral (\u03b1) diversity from Sentinel-2: Shannon index of spectral species over 100 m windows, averaged over the unit. The score reaches 100 for the equivalent of 10 equally abundant spectral species per hectare. Proxy pending field validation; a legitimate even-aged monospecific stand may score low."
      )
    ),
    indicator_docs = list(
      B1 = list(fr = "articles/fiche-b1-protection_fr.html"),
      B2 = list(fr = "articles/fiche-b2-structure_fr.html"),
      B3 = list(fr = "articles/fiche-b3-connectivite_fr.html"),
      B4 = list(fr = "articles/fiche-b4-diversite-spectrale_fr.html")
    )
  ),

  W = list(
    code = "W",
    name_fr = "Eau",
    name_en = "Water",
    description_fr = "R\u00e9seau hydrographique, zones humides, indice topographique d'humidit\u00e9 et d\u00e9ficit hydrique sous couvert",
    description_en = "Water network, wetlands, topographic wetness index and under-canopy water deficit",
    icon = "droplet-fill",
    color = "#1E90FF",
    indicators = c("W1", "W2", "W3", "W4"),
    column_names = c("indicateur_w1_reseau", "indicateur_w2_zones_humides", "indicateur_w3_humidite", "indicateur_w4_vpd"),
    indicator_labels = list(
      W1 = list(fr = "R\u00e9seau hydrographique", en = "Water Network"),
      W2 = list(fr = "Zones humides", en = "Wetlands"),
      W3 = list(fr = "Indice topographique d'humidit\u00e9", en = "Topographic Wetness Index"),
      W4 = list(fr = "D\u00e9ficit hydrique sous couvert", en = "Under-canopy water deficit")
    ),
    indicator_tooltips = list(
      W1 = list(
        fr = "Densit\u00e9 et proximit\u00e9 du r\u00e9seau hydrographique (cours d'eau, lacs). Impact sur la biodiversit\u00e9 aquatique et la r\u00e9gulation hydrique.",
        en = "Density and proximity of water network (streams, lakes). Impact on aquatic biodiversity and water regulation."
      ),
      W2 = list(
        fr = "Pr\u00e9sence et proximit\u00e9 de zones humides inventori\u00e9es. Milieux \u00e0 forte valeur \u00e9cologique pour la biodiversit\u00e9 et le stockage de carbone.",
        en = "Presence and proximity of inventoried wetlands. High ecological value habitats for biodiversity and carbon storage."
      ),
      W3 = list(
        fr = "Indice topographique d'humidit\u00e9 (TWI). Pr\u00e9dit l'accumulation d'eau selon la topographie. Valeurs \u00e9lev\u00e9es = zones potentiellement humides.",
        en = "Topographic Wetness Index (TWI). Predicts water accumulation based on topography. High values = potentially wet areas."
      ),
      W4 = list(
        fr = "D\u00e9ficit de pression de vapeur (VPD) estival sous couvert (microclimf, augment\u00e9 LiDAR). S\u00e9cheresse atmosph\u00e9rique ressentie par les semis. Score \u00e9lev\u00e9 = air plus humide.",
        en = "Summer vapour-pressure deficit (VPD) under the canopy (microclimf, LiDAR-augmented). Atmospheric dryness felt by seedlings. High score = moister air."
      )
    )
  ),
  A = list(
    code = "A",
    name_fr = "Air & Microclimat",
    name_en = "Air & Microclimate",
    description_fr = "Tampon forestier, qualit\u00e9 de l'air, microclimat sous couvert et rafra\u00eechissement urbain",
    description_en = "Forest buffer, air quality, under-canopy microclimate and urban cooling",
    icon = "wind",
    color = "#87CEEB",
    indicators = c("A1", "A2", "A3", "A4", "A5"),
    column_names = c("indicateur_a1_couverture", "indicateur_a2_qualite_air", "indicateur_a3_microclimat", "indicateur_a4_tamponnement", "indicateur_a5_rafraichissement"),
    indicator_labels = list(
      A1 = list(fr = "Tampon forestier", en = "Forest Buffer"),
      A2 = list(fr = "Qualit\u00e9 de l'air", en = "Air Quality"),
      A3 = list(fr = "Microclimat sous couvert", en = "Under-canopy microclimate"),
      A4 = list(fr = "Tamponnement canop\u00e9e", en = "Canopy buffering"),
      A5 = list(fr = "Rafra\u00eechissement urbain", en = "Urban cooling")
    ),
    indicator_tooltips = list(
      A1 = list(
        fr = "Couverture foresti\u00e8re dans un rayon de 500m. Mesure la capacit\u00e9 de la for\u00eat \u00e0 att\u00e9nuer les effets climatiques et filtrer l'air.",
        en = "Forest cover within 500m radius. Measures the forest's capacity to mitigate climate effects and filter air."
      ),
      A2 = list(
        fr = "Indice de qualit\u00e9 de l'air bas\u00e9 sur l'\u00e9loignement des sources de pollution et la densit\u00e9 foresti\u00e8re environnante.",
        en = "Air quality index based on distance from pollution sources and surrounding forest density."
      ),
      A3 = list(
        fr = "Temp\u00e9rature maximale estivale sous couvert (microclimf, augment\u00e9 LiDAR). Pilote la r\u00e9g\u00e9n\u00e9ration. Score \u00e9lev\u00e9 = plus frais. Fiable en relatif entre parcelles.",
        en = "Summer maximum temperature under the canopy (microclimf, LiDAR-augmented). Drives regeneration. High score = cooler. Reliable in relative ranking."
      ),
      A4 = list(
        fr = "Tamponnement thermique de la canop\u00e9e (\u00e9cart T\u00b0max d\u00e9couvert \u2212 sous couvert). Score \u00e9lev\u00e9 = microsite mieux prot\u00e9g\u00e9 de la chaleur.",
        en = "Canopy thermal buffering (T\u00b0max open minus under canopy). High score = microsite better shielded from heat."
      ),
      A5 = list(
        fr = "Rafra\u00eechissement urbain : fra\u00eecheur de surface (LST) de l'unit\u00e9 vs son environnement. Orient\u00e9 arbre en ville (LST disponible en m\u00e9tropole). Score \u00e9lev\u00e9 = plus frais que l'entour. NA hors couverture LST.",
        en = "Urban cooling: relative surface freshness (LST) of the unit vs its surroundings. Urban-tree oriented (LST available over metropolises). High score = cooler than surroundings. NA outside LST coverage."
      )
    )
  ),
  F = list(
    code = "F",
    name_fr = "Fertilit\u00e9 des Sols",
    name_en = "Soil Fertility",
    description_fr = "Fertilit\u00e9 des sols et risque d'\u00e9rosion",
    description_en = "Soil fertility and erosion risk",
    icon = "globe-americas",
    color = "#8B4513",
    indicators = c("F1", "F2"),
    # Décroisé en 0.182.0 (spec 049) : F1 = fertilité, F2 = érosion, comme le
    # disent le nom des deux fonctions, `.normalize_resolve_alias()` et
    # CLAUDE.md. Seule cette table disait l'inverse, et `column_names` était
    # croisé pour compenser — si bien que le MÊME code « F1 » désignait la
    # fertilité par le résolveur d'alias et l'érosion par cette table.
    column_names = c("indicateur_f1_fertilite", "indicateur_f2_erosion"),
    indicator_labels = list(
      F1 = list(fr = "Fertilit\u00e9 des sols", en = "Soil Fertility"),
      F2 = list(fr = "Risque d'\u00e9rosion", en = "Erosion Risk")
    ),
    indicator_tooltips = list(
      F2 = list(
        fr = "R\u00e9sistance \u00e0 l'\u00e9rosion des sols, d\u00e9riv\u00e9e de la topographie (indice d'humidit\u00e9 TWI, pente) et de la texture. Score \u00e9lev\u00e9 = faible risque.",
        en = "Soil erosion resistance, from topography (TWI wetness index, slope) and texture. High score = low risk."
      ),
      F1 = list(
        fr = "Potentiel de fertilit\u00e9 des sols bas\u00e9 sur les caract\u00e9ristiques p\u00e9dologiques (texture, profondeur, mati\u00e8re organique).",
        en = "Soil fertility potential based on pedological characteristics (texture, depth, organic matter)."
      )
    )
  ),
  L = list(
    code = "L",
    name_fr = "Paysage",
    name_en = "Landscape",
    description_fr = "Sylvosph\u00e8re (effet lisi\u00e8re), fragmentation paysag\u00e8re et h\u00e9t\u00e9rog\u00e9n\u00e9it\u00e9 spectrale",
    description_en = "Sylvosphere (edge effect), landscape fragmentation and spectral heterogeneity",
    icon = "image-fill",
    color = "#32CD32",
    indicators = c("L1", "L2", "L3"),
    column_names = c("indicateur_l1_effet_lisiere", "indicateur_l2_morcellement", "indicateur_l3_het_spectrale"),
    indicator_labels = list(
      L1 = list(fr = "Sylvosph\u00e8re (effet lisi\u00e8re)", en = "Sylvosphere (Edge Effect)"),
      L2 = list(fr = "Fragmentation paysag\u00e8re", en = "Landscape Fragmentation"),
      L3 = list(fr = "H\u00e9t\u00e9rog\u00e9n\u00e9it\u00e9 spectrale", en = "Spectral Heterogeneity")
    ),
    indicator_tooltips = list(
      L1 = list(
        fr = "Proportion de la parcelle sous influence des lisi\u00e8res (sylvosph\u00e8re). Les lisi\u00e8res favorisent certaines esp\u00e8ces mais fragmentent l'habitat int\u00e9rieur.",
        en = "Proportion of parcel under edge influence (sylvosphere). Edges favor some species but fragment interior habitat."
      ),
      L2 = list(
        fr = "Niveau de fragmentation du paysage forestier environnant. Bas\u00e9 sur la taille et la connectivit\u00e9 des massifs forestiers proches.",
        en = "Fragmentation level of surrounding forest landscape. Based on size and connectivity of nearby forest patches."
      ),
      L3 = list(
        fr = "H\u00e9t\u00e9rog\u00e9n\u00e9it\u00e9 spectrale (\u03b2) du paysage d\u00e9riv\u00e9e de Sentinel-2 : dispersion des fen\u00eatres de l\u2019unit\u00e9 dans l\u2019ordination (PCoA) de la dissimilarit\u00e9 Bray-Curtis entre \u00ab spectral species \u00bb. Mesure la diversit\u00e9 de la mosa\u00efque (compl\u00e9mentaire de L2, morcellement g\u00e9om\u00e9trique). NA sous 3 fen\u00eatres couvertes. Proxy \u00e0 valider terrain.",
        en = "Spectral (\u03b2) landscape heterogeneity from Sentinel-2: dispersion of the unit\u2019s windows in the PCoA ordination of the Bray-Curtis dissimilarity between spectral species. Measures mosaic diversity (complementary to L2, geometric fragmentation). NA below 3 covered windows. Proxy pending field validation."
      )
    )
  ),
  T = list(
    code = "T",
    name_fr = "Dynamique Temporelle",
    name_en = "Temporal Dynamics",
    description_fr = "Anciennet\u00e9 foresti\u00e8re, taux de changement et pression de coupe rase",
    description_en = "Forest age, change rate and clear-cut pressure",
    icon = "clock-fill",
    color = "#FFD700",
    indicators = c("T1", "T2", "T3"),
    column_names = c("indicateur_t1_anciennete", "indicateur_t2_changement", "indicateur_t3_coupes_rases"),
    indicator_labels = list(
      T1 = list(fr = "Anciennet\u00e9 foresti\u00e8re", en = "Forest Age"),
      T2 = list(fr = "Taux de changement", en = "Change Rate"),
      T3 = list(fr = "Coupes rases", en = "Clear-cuts")
    ),
    indicator_tooltips = list(
      T1 = list(
        fr = "Anciennet\u00e9 de l'\u00e9tat bois\u00e9 depuis les cartes de Cassini (XVIIIe si\u00e8cle). Les for\u00eats anciennes abritent une biodiversit\u00e9 sp\u00e9cifique.",
        en = "Age of wooded state since Cassini maps (18th century). Ancient forests harbor specific biodiversity."
      ),
      T2 = list(
        fr = "Taux de changement de la couverture foresti\u00e8re sur les 30 derni\u00e8res ann\u00e9es. Valeurs positives = extension, n\u00e9gatives = r\u00e9gression.",
        en = "Rate of forest cover change over the last 30 years. Positive values = expansion, negative = regression."
      ),
      T3 = list(
        fr = "Pression de coupe rase (produit SUFOSAT, radar Sentinel-1). Fraction r\u00e9cente coup\u00e9e \u00e0 blanc, pond\u00e9r\u00e9e par r\u00e9cence. Sens invers\u00e9 : plus de coupe = indice plus bas.",
        en = "Clear-cut pressure (SUFOSAT product, Sentinel-1 radar). Recency-weighted recently clear-cut fraction. Inverted sense: more clear-cutting = lower score."
      )
    )
  ),
  R = list(
    code = "R",
    name_fr = "Risques & R\u00e9silience",
    name_en = "Risks & Resilience",
    description_fr = "Risques feu, temp\u00eate, s\u00e9cheresse, abroutissement, d\u00e9p\u00e9rissement, sensibilit\u00e9 microclimatique et gel tardif",
    description_en = "Fire, storm, drought, browsing, dieback, microclimate sensitivity and late-frost risks",
    icon = "exclamation-triangle-fill",
    color = "#DC143C",
    indicators = c("R1", "R2", "R3", "R4", "R5", "R6", "R7"),
    column_names = c("indicateur_r1_feu", "indicateur_r2_tempete", "indicateur_r3_secheresse", "indicateur_r4_abroutissement", "indicateur_r5_deperissement", "indicateur_r6_sensibilite", "indicateur_r7_gel"),
    indicator_labels = list(
      R1 = list(fr = "Risque incendie", en = "Fire Risk"),
      R2 = list(fr = "Risque temp\u00eate", en = "Storm Risk"),
      R3 = list(fr = "Risque s\u00e9cheresse", en = "Drought Risk"),
      R4 = list(fr = "Risque abroutissement", en = "Browsing Risk"),
      R5 = list(fr = "D\u00e9p\u00e9rissement (FORDEAD)", en = "Dieback (FORDEAD)"),
      R6 = list(fr = "Sensibilit\u00e9 microclimatique", en = "Microclimate sensitivity"),
      R7 = list(fr = "Risque de gel tardif", en = "Late-frost Risk")
    ),
    indicator_tooltips = list(
      R1 = list(
        fr = "Susceptibilit\u00e9 au feu bas\u00e9e sur le climat, la v\u00e9g\u00e9tation inflammable et l'historique des incendies. Score \u00e9lev\u00e9 = faible risque.",
        en = "Fire susceptibility based on climate, flammable vegetation and fire history. High score = low risk."
      ),
      R2 = list(
        fr = "Vuln\u00e9rabilit\u00e9 aux temp\u00eates bas\u00e9e sur l'exposition, la hauteur des arbres et les vents dominants. Score \u00e9lev\u00e9 = faible risque.",
        en = "Storm vulnerability based on exposure, tree height and prevailing winds. High score = low risk."
      ),
      R3 = list(
        fr = "Sensibilit\u00e9 \u00e0 la s\u00e9cheresse (indice SPEI). Bas\u00e9 sur le bilan hydrique et les projections climatiques. Score \u00e9lev\u00e9 = faible risque.",
        en = "Drought sensitivity (SPEI index). Based on water balance and climate projections. High score = low risk."
      ),
      R4 = list(
        fr = "Pression de la faune sauvage (cervid\u00e9s) sur la r\u00e9g\u00e9n\u00e9ration foresti\u00e8re. Bas\u00e9 sur les donn\u00e9es cyn\u00e9g\u00e9tiques. Score \u00e9lev\u00e9 = faible pression.",
        en = "Wildlife pressure (deer) on forest regeneration. Based on hunting data. High score = low pressure."
      ),
      R5 = list(
        fr = "D\u00e9p\u00e9rissement d\u00e9tect\u00e9 par FORDEAD (r\u00e9sineux) ou RECONFORT (feuillus) sur Sentinel-2 / CRSWIR, pond\u00e9r\u00e9 par les taux de bonne d\u00e9tection ONF/DSF 2024. NA hors zone de validit\u00e9 ou hors essence cibl\u00e9e. Score \u00e9lev\u00e9 = faible d\u00e9p\u00e9rissement (bon \u00e9tat sanitaire).",
        en = "Dieback detected by FORDEAD (conifers) or RECONFORT (broadleaves) on Sentinel-2 / CRSWIR, weighted by ONF/DSF 2024 detection accuracy. NA outside the validity zone or for non-targeted species. High score = low dieback (good forest health)."
      ),
      R6 = list(
        fr = "Sensibilité du microsite à une année chaude (Δ stress entre un été canicule et un été moyen, canopée figée). Microclimf, augmenté LiDAR. Score élevé = peu sensible (plus résilient). Fiable en relatif entre parcelles.",
        en = "Microsite sensitivity to a hot year (stress change between a heatwave and an average summer, canopy fixed). Microclimf, LiDAR-augmented. High score = low sensitivity (more resilient). Reliable in relative ranking."
      ),
      R7 = list(
        fr = "Risque de gel tardif : fréquence des gelées printanières après débourrement (Tmin < seuil), déterminant de l'échec de régénération (chêne, hêtre, douglas). Série Tmin downscalée meteoland/SAFRAN. NA sans donnée Tmin. Score élevé = faible risque (peu de gel).",
        en = "Late-frost risk: frequency of spring frosts after budburst (Tmin below threshold), a driver of regeneration failure (oak, beech, Douglas fir). meteoland/SAFRAN-downscaled Tmin series. NA without Tmin data. High score = low risk (few frosts)."
      )
    )
  ),
  S = list(
    code = "S",
    name_fr = "Social & R\u00e9cr\u00e9atif",
    name_en = "Social & Recreational",
    description_fr = "Distance aux routes et aux b\u00e2timents, proximit\u00e9 de la population",
    description_en = "Distance to roads and buildings, population proximity",
    icon = "people-fill",
    color = "#FF69B4",
    indicators = c("S1", "S2", "S3"),
    column_names = c("indicateur_s1_routes", "indicateur_s2_bati", "indicateur_s3_population"),
    indicator_labels = list(
      S1 = list(fr = "Distance aux routes", en = "Road Distance"),
      S2 = list(fr = "Distance aux b\u00e2timents", en = "Building Distance"),
      # « Proximite population » reste juste pour une densite de voisinage et
      # tient sur un axe de radar ; seul le tooltip disait faux.
      S3 = list(fr = "Proximit\u00e9 population", en = "Population Proximity")
    ),
    indicator_tooltips = list(
      S1 = list(
        fr = "Distance moyenne aux routes (BD TOPO). Une distance faible facilite l'acc\u00e8s mais peut augmenter les perturbations.",
        en = "Average distance to roads (BD TOPO). Low distance facilitates access but may increase disturbance."
      ),
      S2 = list(
        fr = "Distance moyenne aux b\u00e2timents (BD TOPO). Indicateur de proximit\u00e9 urbaine et de pression anthropique potentielle.",
        en = "Average distance to buildings (BD TOPO). Indicator of urban proximity and potential human pressure."
      ),
      S3 = list(
        # v0.189.1 : deux erreurs, dont une anterieure au changement de
        # grandeur. S3 ne porte pas un effectif mais une DENSITE (v0.189.0),
        # et son rayon de reference est 5 km, pas 10 — le code utilisait deja
        # `pop_5km` quand le tooltip annoncait 10 km. L'app lit ce texte tel
        # quel depuis `INDICATOR_FAMILIES` : le corriger la-bas creerait une
        # seconde verite sur une donnee qui n'en a qu'une.
        fr = "Densit\u00e9 de population dans un rayon de 5 km (hab/km\u00b2, \u00e9chelle logarithmique). Mesure le potentiel d'usage r\u00e9cr\u00e9atif et la pression sociale sur la for\u00eat.",
        en = "Population density within a 5 km radius (inhab/km\u00b2, log scale). Measures recreational use potential and social pressure on the forest."
      )
    )
  ),
  P = list(
    code = "P",
    name_fr = "Production",
    name_en = "Production",
    description_fr = "Volume de bois, productivit\u00e9 de la station et qualit\u00e9 du bois",
    description_en = "Timber volume, site productivity and timber quality",
    icon = "box-seam-fill",
    color = "#006400",
    indicators = c("P1", "P2", "P3"),
    column_names = c("indicateur_p1_volume", "indicateur_p2_station", "indicateur_p3_qualite_bois"),
    indicator_labels = list(
      P1 = list(fr = "Volume de bois (m\u00b3/ha)", en = "Timber Volume (m\u00b3/ha)"),
      P2 = list(fr = "Productivit\u00e9", en = "Productivity"),
      P3 = list(fr = "Qualit\u00e9 du bois", en = "Timber Quality")
    ),
    indicator_tooltips = list(
      P1 = list(
        fr = "Volume de bois sur pied estim\u00e9 (m\u00b3/ha). Calcul\u00e9 \u00e0 partir de donn\u00e9es LiDAR ou de tarifs de cubage. Valeurs typiques : 100-400 m\u00b3/ha.",
        en = "Estimated standing timber volume (m\u00b3/ha). Calculated from LiDAR data or volume tables. Typical values: 100-400 m\u00b3/ha."
      ),
      P2 = list(
        fr = "Classe de fertilit\u00e9 de la station foresti\u00e8re. Bas\u00e9e sur le sol, le climat et la croissance potentielle des arbres.",
        en = "Forest site fertility class. Based on soil, climate and potential tree growth."
      ),
      P3 = list(
        fr = "Qualit\u00e9 potentielle du bois bas\u00e9e sur les essences pr\u00e9sentes et les conditions de croissance.",
        en = "Potential timber quality based on species present and growing conditions."
      )
    )
  ),
  E = list(
    code = "E",
    name_fr = "\u00c9nergie & Climat",
    name_en = "Energy & Climate",
    description_fr = "Potentiel bois-\u00e9nergie et \u00e9vitement de CO2",
    description_en = "Wood energy potential and CO2 avoidance",
    icon = "lightning-fill",
    color = "#FF8C00",
    indicators = c("E1", "E2"),
    column_names = c("indicateur_e1_bois_energie", "indicateur_e2_evitement"),
    indicator_labels = list(
      E1 = list(fr = "Bois-\u00e9nergie", en = "Wood Energy"),
      E2 = list(fr = "\u00c9vitement CO2", en = "CO2 Avoidance")
    ),
    indicator_tooltips = list(
      E1 = list(
        fr = "Potentiel de production de bois-\u00e9nergie (MWh/ha/an). Bas\u00e9 sur la biomasse disponible et l'accessibilit\u00e9.",
        en = "Wood energy production potential (MWh/ha/year). Based on available biomass and accessibility."
      ),
      E2 = list(
        fr = "\u00c9missions de CO2 \u00e9vit\u00e9es par substitution aux \u00e9nergies fossiles (tCO2/ha/an). Contribution \u00e0 la transition \u00e9nerg\u00e9tique.",
        en = "CO2 emissions avoided by substituting fossil fuels (tCO2/ha/year). Contribution to energy transition."
      )
    )
  ),
  N = list(
    code = "N",
    name_fr = "Naturalit\u00e9",
    name_en = "Naturalness",
    description_fr = "\u00c9loignement des infrastructures, continuit\u00e9 foresti\u00e8re et score de naturalit\u00e9",
    description_en = "Infrastructure remoteness, forest continuity and naturalness score",
    icon = "flower1",
    color = "#2E8B57",
    indicators = c("N1", "N2", "N3"),
    column_names = c("indicateur_n1_distance", "indicateur_n2_continuite", "indicateur_n3_naturalite"),
    indicator_labels = list(
      N1 = list(fr = "Distance infrastructures", en = "Infrastructure Distance"),
      N2 = list(fr = "Continuit\u00e9 foresti\u00e8re", en = "Forest Continuity"),
      N3 = list(fr = "Score de naturalit\u00e9", en = "Naturalness Score")
    ),
    indicator_tooltips = list(
      N1 = list(
        fr = "\u00c9loignement des infrastructures humaines (routes, b\u00e2timents). Une grande distance indique un environnement plus naturel.",
        en = "Distance from human infrastructure (roads, buildings). Greater distance indicates more natural environment."
      ),
      N2 = list(
        fr = "Continuit\u00e9 spatio-temporelle du couvert forestier. Les for\u00eats continues depuis longtemps ont une plus grande naturalit\u00e9.",
        en = "Spatio-temporal continuity of forest cover. Forests continuous for longer have greater naturalness."
      ),
      N3 = list(
        fr = "Score composite de naturalit\u00e9 int\u00e9grant structure, continuit\u00e9, \u00e9loignement et perturbations anthropiques.",
        en = "Composite naturalness score integrating structure, continuity, remoteness and human disturbance."
      )
    )
  )
)


#' Get all indicator family codes
#'
#' @return Character vector of family codes
#' @noRd
get_family_codes <- function() {
  names(INDICATOR_FAMILIES)
}


#' Get family configuration
#'
#' @param code Character. Family code (e.g., "C", "B", "W")
#' @return List with family configuration, or NULL if not found
#' @noRd
get_family_config <- function(code) {
  INDICATOR_FAMILIES[[toupper(code)]]
}


#' Get all indicator codes
#'
#' @return Character vector of all indicator codes
#' @noRd
get_all_indicator_codes <- function() {
  unlist(lapply(INDICATOR_FAMILIES, function(f) f$indicators), use.names = FALSE)
}


#' Get all indicator column names
#'
#' @return Character vector of all long-form column names
#' @noRd
get_all_column_names <- function() {
  unlist(lapply(INDICATOR_FAMILIES, function(f) f$column_names), use.names = FALSE)
}


#' Subset INDICATOR_FAMILIES by code
#'
#' @param codes Character vector of family codes, or NULL for all 12.
#' @return Named list of family configurations.
#' @noRd
.select_families <- function(codes = NULL) {
  if (is.null(codes)) {
    return(INDICATOR_FAMILIES)
  }
  if (!is.character(codes)) {
    stop("`codes` must be a character vector of family codes, or NULL.",
      call. = FALSE
    )
  }
  codes <- toupper(codes)
  unknown <- setdiff(codes, names(INDICATOR_FAMILIES))
  if (length(unknown) > 0) {
    stop(
      "Unknown family code(s): ", paste(unknown, collapse = ", "),
      ". Valid codes: ", paste(names(INDICATOR_FAMILIES), collapse = " "), ".",
      call. = FALSE
    )
  }
  INDICATOR_FAMILIES[codes]
}


#' Indicator family table
#'
#' @description
#' Public, stable view of the 12 indicator families of the Nemeton framework.
#' This is the canonical source for family codes, display names and the
#' indicators each family aggregates. Downstream packages (notably
#' `nemetonshiny`) should read it instead of re-declaring the list, so that
#' renaming a family in the core propagates instead of silently diverging.
#'
#' The function is pure (no I/O, no state), and therefore safe to call from a
#' `future` worker.
#'
#' @section Column pairing:
#' `indicators` and `column_names` are always the same length and are paired
#' **by position**: `column_names[[i]]` is the column produced for
#' `indicators[[i]]`. Do **not** derive one from the other by string
#' manipulation: **one** family still carries a legacy naming swap, where the
#' short code and the column slug disagree.
#' \itemize{
#'   \item `F1` is `indicateur_f2_erosion` and `F2` is `indicateur_f1_fertilite`.
#' }
#' The labels follow the short code **and** the values the paired column
#' carries, so `labels[["F1"]]` describes erosion — consistent with the paired
#' column, not with the column's own slug.
#'
#' Family L was in the same state until 0.176.0, for a reason worth
#' remembering: a column is named after the function that fills it
#' (`compute_indicator()` looks the function up by the indicator name), and
#' both L functions were named after the *other* one's metric. The functions
#' were renamed rather than the labels swapped — see spec 045 and
#' [migrer_colonnes_l()]. `indicateur_l2_fragmentation` and
#' `indicateur_l1_sylvosphere` are **retired slugs**: they are never reused, so
#' that a dataset written before the rename cannot be silently reinterpreted.
#'
#' @section Colors:
#' `color` carries the *semantic* palette of the core (forest green for carbon,
#' water blue for the water family). It is deliberately not the palette used by
#' the Shiny application, which applies viridis for colorblind accessibility.
#' Consumers who need an accessible palette should ignore this column.
#'
#' @param codes Character vector of family codes (case-insensitive), or `NULL`
#'   (default) for all 12 families in canonical order
#'   `C B W A F L T R S P E N`. When supplied, rows are returned in the order
#'   given.
#' @section Both languages, always:
#' Every translatable field is returned in **both** languages, in dedicated
#' `_fr` / `_en` columns. `lang` only selects which of them is copied into the
#' convenience columns `name`, `description`, `labels` and `tooltips`. A caller
#' that switches language at runtime — or that needs a fallback when one
#' language is missing — never has to call the function twice.
#'
#' @param lang Character. Language copied into the convenience columns `name`,
#'   `description`, `labels` and `tooltips`: `"fr"` (default) or `"en"`. The
#'   `_fr` / `_en` columns are returned regardless.
#'
#' @return A `data.frame` with one row per family and the columns:
#'   \describe{
#'     \item{code}{Family code (`"C"`, `"B"`, ...).}
#'     \item{family_column}{Name of the family score column produced by
#'       [create_family_index()] (`"famille_carbone"`, ...). See
#'       [get_famille_col()].}
#'     \item{name}{Family name in `lang`.}
#'     \item{name_fr, name_en}{Family name in both languages.}
#'     \item{description}{One-line description of the family in `lang`.}
#'     \item{description_fr, description_en}{Description in both languages.}
#'     \item{icon}{Bootstrap icon name.}
#'     \item{color}{Semantic hex color (see *Colors*).}
#'     \item{indicators}{List column: character vector of indicator codes
#'       (`"C1"`, `"C2"`, ...).}
#'     \item{column_names}{List column: character vector of the produced column
#'       names, paired by position with `indicators`.}
#'     \item{labels}{List column: named character vector of indicator labels in
#'       `lang`, named by indicator code.}
#'     \item{labels_fr, labels_en}{Same, in each language.}
#'     \item{tooltips}{List column: named character vector of indicator
#'       tooltips in `lang`, named by indicator code.}
#'     \item{tooltips_fr, tooltips_en}{Same, in each language.}
#'   }
#'
#' @seealso [indicator_labels()] for a long-format, one-row-per-indicator view.
#'
#' @examples
#' fams <- indicator_families()
#' fams$code
#' fams[fams$code == "C", "name"]
#'
#' # Loop over the families to build a menu
#' for (i in seq_len(nrow(fams))) {
#'   cat(sprintf("%s (%s)\n", fams$name[i], fams$code[i]))
#' }
#'
#' # A subset, in English
#' indicator_families(c("C", "W"), lang = "en")$name
#'
#' # Both languages are always there, whatever `lang`
#' fams$labels_en[[1]]
#'
#' # The family score column produced by create_family_index()
#' fams$family_column
#'
#' @export
indicator_families <- function(codes = NULL, lang = c("fr", "en")) {
  lang <- match.arg(lang)
  fams <- .select_families(codes)

  atomic_cols <- c(
    "code", "family_column", "name", "name_fr", "name_en",
    "description", "description_fr", "description_en", "icon", "color"
  )
  list_cols <- c(
    "indicators", "column_names",
    "labels", "labels_fr", "labels_en",
    "tooltips", "tooltips_fr", "tooltips_en"
  )

  if (length(fams) == 0) {
    empty <- data.frame(
      stats::setNames(rep(list(character(0)), length(atomic_cols)), atomic_cols),
      stringsAsFactors = FALSE
    )
    for (col in list_cols) empty[[col]] <- list()
    return(empty)
  }

  chr <- function(field) {
    vapply(fams, function(f) as.character(f[[field]]), character(1),
      USE.NAMES = FALSE
    )
  }

  out <- data.frame(
    code = chr("code"),
    family_column = vapply(fams, function(f) get_famille_col(f$code),
      character(1),
      USE.NAMES = FALSE
    ),
    name = chr(paste0("name_", lang)),
    name_fr = chr("name_fr"),
    name_en = chr("name_en"),
    description = chr(paste0("description_", lang)),
    description_fr = chr("description_fr"),
    description_en = chr("description_en"),
    icon = chr("icon"),
    color = chr("color"),
    stringsAsFactors = FALSE
  )

  out$indicators <- lapply(fams, function(f) as.character(f$indicators))
  out$column_names <- lapply(fams, function(f) as.character(f$column_names))
  for (lg in c("fr", "en")) {
    out[[paste0("labels_", lg)]] <-
      lapply(fams, .family_texts, field = "indicator_labels", lang = lg)
    out[[paste0("tooltips_", lg)]] <-
      lapply(fams, .family_texts, field = "indicator_tooltips", lang = lg)
  }
  out$labels <- out[[paste0("labels_", lang)]]
  out$tooltips <- out[[paste0("tooltips_", lang)]]

  # Colonnes-listes rangées dans l'ordre documenté, sans noms résiduels
  out <- out[, c(atomic_cols, list_cols)]
  for (col in list_cols) names(out[[col]]) <- NULL
  rownames(out) <- NULL

  out
}


#' Extract per-indicator texts of one family in a given language
#'
#' @param fam List. One entry of INDICATOR_FAMILIES.
#' @param field Character. "indicator_labels" or "indicator_tooltips".
#' @param lang Character. "fr" or "en".
#' @return Named character vector (names = indicator codes).
#' @noRd
.family_texts <- function(fam, field, lang) {
  texts <- fam[[field]]
  out <- vapply(fam$indicators, function(ic) {
    entry <- texts[[ic]]
    if (is.null(entry) || is.null(entry[[lang]])) NA_character_ else entry[[lang]]
  }, character(1), USE.NAMES = FALSE)
  names(out) <- fam$indicators
  out
}


# Base du site pkgdown, lue dans le champ URL du DESCRIPTION (premiere entree)
# pour qu'il n'existe qu'une seule source de verite. Le repli couvre le cas ou
# le package est charge par devtools::load_all() sans DESCRIPTION installe.
.doc_base_url <- function() {
  url <- tryCatch(utils::packageDescription("nemeton")$URL,
                  error = function(e) NULL)
  first <- if (!is.null(url) && !is.na(url)) {
    trimws(strsplit(url, ",", fixed = TRUE)[[1]][1])
  } else {
    NA_character_
  }
  if (is.na(first) || !nzchar(first)) first <- "https://pobsteta.github.io/nemeton/"
  sub("/?$", "/", first)
}

# Resout UNE entree `indicator_docs` pour une langue demandee.
#
# L'entree est une liste nommee par langue : `list(fr = "...", en = "...")`.
# Quand la langue demandee n'a pas de page mais que l'autre en a une, c'est
# l'AUTRE qui est rendue : une fiche dans la mauvaise langue vaut mieux que
# pas de fiche du tout. Le deuxieme element du retour dit laquelle, pour que
# l'interface puisse le signaler au lecteur au lieu d'ouvrir du francais sans
# prevenir.
#
# Retourne c(href, lang), les deux NA quand aucune page n'existe.
.resolve_doc_entry <- function(entry, lang) {
  none <- c(NA_character_, NA_character_)
  if (is.null(entry) || !is.list(entry)) return(none)
  for (l in c(lang, setdiff(c("fr", "en"), lang))) {
    href <- entry[[l]]
    if (is.null(href)) next
    href <- as.character(href)[1]
    if (is.na(href) || !nzchar(href)) next
    return(c(href, l))
  }
  none
}

# URLs absolues des fiches d'une famille pour une langue, et langue reellement
# servie. `indicator_docs` porte des hrefs RELATIFS au site pkgdown ; une
# entree deja absolue (http/https) est laissee telle quelle, pour qu'une fiche
# hebergee ailleurs reste possible sans changer l'API.
#
# Retourne une liste de deux vecteurs de longueur length(fam$indicators).
.family_docs <- function(fam, lang, base = .doc_base_url()) {
  docs <- fam$indicator_docs
  # Le test d'appartenance, plutot que `docs[[ic]]` : la famille peut n'avoir
  # aucune fiche (`docs` NULL), et `[[` sur un nom absent n'a pas le meme
  # comportement selon le type du conteneur.
  known <- if (is.null(docs)) character(0) else names(docs)
  resolved <- lapply(fam$indicators, function(ic) {
    if (!ic %in% known) return(c(NA_character_, NA_character_))
    hit <- .resolve_doc_entry(docs[[ic]], lang)
    if (is.na(hit[1])) return(hit)
    href <- if (grepl("^https?://", hit[1])) {
      hit[1]
    } else {
      paste0(base, sub("^/", "", hit[1]))
    }
    c(href, hit[2])
  })
  list(
    url = vapply(resolved, function(x) x[1], character(1), USE.NAMES = FALSE),
    lang = vapply(resolved, function(x) x[2], character(1), USE.NAMES = FALSE)
  )
}


#' Indicator table (long format)
#'
#' @description
#' One row per indicator, flattening [indicator_families()]. Useful to build a
#' label lookup keyed by indicator code or by column name, without re-declaring
#' the strings downstream.
#'
#' Rows follow the canonical family order, and within a family the declaration
#' order of the indicators. `column_name` is the column paired with `code` —
#' see the *Column pairing* section of [indicator_families()] for the two
#' families where the short code and the column slug disagree.
#'
#' As in [indicator_families()], both languages are always returned: `lang`
#' only selects which one is copied into the convenience columns `label` and
#' `tooltip`.
#'
#' @param codes Character vector of family codes (case-insensitive), or `NULL`
#'   (default) for all 12 families.
#' @param lang Character. Language copied into `label` and `tooltip`: `"fr"`
#'   (default) or `"en"`. The `_fr` / `_en` columns are returned regardless.
#'
#' @return A `data.frame` with columns `family` (family code), `family_column`
#'   (family score column), `code` (indicator code), `column_name`, `label`,
#'   `label_fr`, `label_en`, `tooltip`, `tooltip_fr`, `tooltip_en`, `doc_url`,
#'   `doc_url_fr`, `doc_url_en` and `doc_lang`.
#'
#' @section Indicator fact sheets (`doc_url`):
#' Some indicators have a long-form fact sheet published as a pkgdown article
#' (C1 today). `doc_url` carries its absolute URL, and is `NA` for every
#' indicator without one — that `NA` is the condition a UI tests before
#' offering a "read the fact sheet" link next to the tooltip, not an error.
#' The base of the URL is the first entry of the package `URL` field, so the
#' site address is declared once, in `DESCRIPTION`.
#'
#' A fact sheet is declared per language. When the requested language has no
#' page but the other one does, that other page is returned rather than `NA`:
#' a fact sheet in the wrong language beats no fact sheet. `doc_lang` names
#' the language actually served, so an interface can say so instead of opening
#' French without warning — today `indicator_labels(lang = "en")` returns the
#' French C1 page with `doc_lang == "fr"`. Compare `doc_lang` with the
#' language you asked for; do not assume they match.
#'
#' @seealso [indicator_families()]
#'
#' @examples
#' ind <- indicator_labels()
#' head(ind)
#'
#' # Lookup table: column name -> label
#' stats::setNames(ind$label, ind$column_name)[["indicateur_c1_biomasse"]]
#'
#' # Bilingual lookup, without a second call
#' stats::setNames(ind$label_en, ind$code)[["C1"]]
#'
#' # Indicators that have a fact sheet, and where to read it
#' ind[!is.na(ind$doc_url), c("code", "doc_url", "doc_lang")]
#'
#' # A fact sheet served in a language other than the one requested
#' en <- indicator_labels(lang = "en")
#' en[!is.na(en$doc_lang) & en$doc_lang != "en", c("code", "doc_lang")]
#'
#' @export
indicator_labels <- function(codes = NULL, lang = c("fr", "en")) {
  lang <- match.arg(lang)
  fams <- .select_families(codes)

  cols <- c(
    "family", "family_column", "code", "column_name",
    "label", "label_fr", "label_en",
    "tooltip", "tooltip_fr", "tooltip_en",
    "doc_url", "doc_url_fr", "doc_url_en", "doc_lang"
  )

  if (length(fams) == 0) {
    return(data.frame(
      stats::setNames(rep(list(character(0)), length(cols)), cols),
      stringsAsFactors = FALSE
    ))
  }

  # Une seule lecture du DESCRIPTION par appel, pas une par famille.
  doc_base <- .doc_base_url()

  rows <- lapply(fams, function(f) {
    n <- length(f$indicators)
    out <- data.frame(
      family = rep(as.character(f$code), n),
      family_column = rep(get_famille_col(f$code), n),
      code = as.character(f$indicators),
      column_name = as.character(f$column_names),
      label_fr = unname(.family_texts(f, "indicator_labels", "fr")),
      label_en = unname(.family_texts(f, "indicator_labels", "en")),
      tooltip_fr = unname(.family_texts(f, "indicator_tooltips", "fr")),
      tooltip_en = unname(.family_texts(f, "indicator_tooltips", "en")),
      stringsAsFactors = FALSE
    )
    # Les deux langues sont resolues une fois ; `doc_url` / `doc_lang` sont
    # la vue de celle qui a ete demandee.
    docs_fr <- .family_docs(f, "fr", base = doc_base)
    docs_en <- .family_docs(f, "en", base = doc_base)
    docs <- if (lang == "fr") docs_fr else docs_en
    out$doc_url <- docs$url
    out$doc_lang <- docs$lang
    out$doc_url_fr <- docs_fr$url
    out$doc_url_en <- docs_en$url
    out$label <- out[[paste0("label_", lang)]]
    out$tooltip <- out[[paste0("tooltip_", lang)]]
    out[, cols]
  })

  out <- do.call(rbind, c(rows, list(make.row.names = FALSE)))
  rownames(out) <- NULL
  out
}


#' Get column-to-family mapping
#'
#' @description
#' Returns a named character vector mapping column names to family codes.
#' Supports both short codes (C1, B2) and long-form names (indicateur_c1_biomasse).
#'
#' @return Named character vector (names = column names, values = family codes)
#' @noRd
get_column_family_map <- function() {
  result <- character(0)
  for (fam in INDICATOR_FAMILIES) {
    # Map long-form column_names to family code
    if (!is.null(fam$column_names)) {
      names_vec <- rep(fam$code, length(fam$column_names))
      names(names_vec) <- fam$column_names
      result <- c(result, names_vec)
    }
    # Map short indicators to family code
    names_vec2 <- rep(fam$code, length(fam$indicators))
    names(names_vec2) <- fam$indicators
    result <- c(result, names_vec2)
  }
  result
}


