# inventaire_video_symbologie.R — symbologie QField de l'inventaire vidéo
# ---------------------------------------------------------------------------
# Même langage visuel que Marculus (ui/carte/CarteScreen.kt) et que la carte
# de Groma (carte/Couches.kt) : briefs groma du 2026-10-16 (§ 2 bis de
# l'annexe « plugin QField », complément « fonds et houppiers »). Copie de
# `qfield/symbologie.py` du dépôt groma, seul endroit des couleurs côté groma ;
# ici, seul endroit côté nemeton. Tailles en millimètres (QField les met à
# l'échelle de l'écran).

# Marculus, core/Referentiels.kt, COULEURS_ESSENCES_DEFAUT.
.IV_COULEURS <- list(
  chene = "#2a7fa6", hetre = "#5061b8", feuillu = "#7e8e9c",
  sapin = "#94304d", epicea = "#c2502f", resineux = "#ae9381",
  inconnue = "#888888",
  # Marculus, PALETTE_FONCIER et parcelle sans forêt.
  foncier = c("#1e88e5", "#43a047", "#f4511e", "#8e24aa", "#fdd835", "#00acc1",
              "#6d4c41", "#ec407a"),
  sans_foret = "#374742",
  houppier = "#2e7d32",
  # Groma, carte/Couches.kt.
  parcelle = "#ffd54f", centre = "#d500f9", cible = "#ff6f00", detection = "#f57c00",
  contour_placette = "#212121"
)

.IV_ETATS_PLACETTE <- list(
  a_faire = c("#ffffff", "\u00c0 faire"), provisoire = c("#f57c00", "Provisoire"),
  envoye = c("#1976d2", "Envoy\u00e9e"), definitif = c("#2e7d32", "D\u00e9finitive")
)

# Couleur Marculus d'une essence du référentiel essences_bdforet_v2.json.
.iv_groupe_essence <- function(code, bdforet) {
  if (startsWith(bdforet, "Ch\u00eanes")) return(.IV_COULEURS$chene)
  if (identical(bdforet, "H\u00eatre")) return(.IV_COULEURS$hetre)
  if (identical(code, "sapin_pectine")) return(.IV_COULEURS$sapin)
  if (identical(code, "epicea_commun")) return(.IV_COULEURS$epicea)
  if (bdforet %in% c("NC", "")) return(.IV_COULEURS$inconnue)
  if (bdforet %in% c("Ch\u00e2taignier", "Robinier", "Peuplier", "Feuillus")) {
    return(.IV_COULEURS$feuillu)
  }
  .IV_COULEURS$resineux
}

# "#rrggbb" -> "r,g,b,a" (format des couleurs dans le .qgs).
.iv_rgba <- function(hex, alpha = 255) {
  v <- grDevices::col2rgb(hex)[, 1]
  paste(c(v, alpha), collapse = ",")
}

.iv_options <- function(...) {
  o <- list(...)
  .xml_tag("Option", attrs = list(type = "Map"), children = vapply(names(o), function(k) {
    .xml_tag("Option", attrs = list(name = k, type = "QString", value = as.character(o[[k]])))
  }, character(1)))
}

# Propriété définie par une expression (taille d'un symbole).
.iv_dd_taille <- function(expression) {
  if (is.null(expression)) return("")
  .xml_tag("data_defined_properties", children = .xml_tag("Option", attrs = list(type = "Map"),
    children = c(
      .xml_tag("Option", attrs = list(name = "name", type = "QString", value = "")),
      .xml_tag("Option", attrs = list(name = "properties", type = "Map"),
        children = .xml_tag("Option", attrs = list(name = "size", type = "Map"), children = c(
          .xml_tag("Option", attrs = list(name = "active", type = "bool", value = "true")),
          .xml_tag("Option", attrs = list(name = "expression", type = "QString", value = expression)),
          .xml_tag("Option", attrs = list(name = "type", type = "int", value = "3"))
        ))),
      .xml_tag("Option", attrs = list(name = "type", type = "QString", value = "collection"))
    )))
}

.iv_symbole <- function(nom, type, couche_xml) {
  .xml_tag("symbol", attrs = list(type = type, name = nom, alpha = "1",
                                  clip_to_extent = "1", force_rhr = "0"),
           children = couche_xml)
}

# Pastille (marqueur simple) : couleur, taille (mm), contour, forme.
.iv_marqueur <- function(nom, couleur, taille = 3, contour = "#ffffff", forme = "circle",
                         largeur_contour = 0.5, taille_expr = NULL, alpha = 255) {
  .iv_symbole(nom, "marker", .xml_tag("layer",
    attrs = list(class = "SimpleMarker", enabled = "1", locked = "0", pass = "0"),
    children = c(
      .iv_options(color = .iv_rgba(couleur, alpha), outline_color = .iv_rgba(contour),
                  outline_width = largeur_contour, outline_width_unit = "MM",
                  name = forme, size = taille, size_unit = "MM"),
      .iv_dd_taille(taille_expr)
    )))
}

# Surface : contour (mm) et fond de la même couleur à `alpha` (0-255).
.iv_surface <- function(nom, couleur, epaisseur = 0.9, alpha = 0x33) {
  .iv_symbole(nom, "fill", .xml_tag("layer",
    attrs = list(class = "SimpleFill", enabled = "1", locked = "0", pass = "0"),
    children = .iv_options(color = .iv_rgba(couleur, alpha),
                           style = if (alpha == 0) "no" else "solid",
                           outline_color = .iv_rgba(couleur), outline_style = "solid",
                           outline_width = epaisseur, outline_width_unit = "MM")))
}

.iv_renderer_unique <- function(symbole) {
  .xml_tag("renderer-v2", attrs = list(type = "singleSymbol", forceraster = "0",
                                       symbollevels = "0", enableorderby = "0"),
           children = .xml_tag("symbols", children = symbole))
}

# `cats` : liste de list(valeur, libelle, symbole(nom)) ; valeur "" = toutes
# les autres valeurs (NULL compris).
.iv_renderer_categories <- function(champ, cats) {
  noms <- as.character(seq_along(cats) - 1L)
  .xml_tag("renderer-v2", attrs = list(type = "categorizedSymbol", attr = champ,
                                       forceraster = "0", symbollevels = "0",
                                       enableorderby = "0"),
    children = c(
      .xml_tag("categories", children = vapply(seq_along(cats), function(i) {
        .xml_tag("category", attrs = list(value = cats[[i]]$valeur, symbol = noms[i],
                                          label = cats[[i]]$libelle, render = "true"))
      }, character(1))),
      .xml_tag("symbols", children = vapply(seq_along(cats), function(i) {
        cats[[i]]$symbole(noms[i])
      }, character(1)))
    ))
}

# Étiquette sur expression, tampon blanc ; visible sous l'échelle 1/`echelle`.
.iv_etiquette <- function(expression, taille = 9, echelle = 0) {
  .xml_tag("labeling", attrs = list(type = "simple"),
    children = .xml_tag("settings", attrs = list(calloutType = "simple"), children = c(
      .xml_tag("text-style", attrs = list(fieldName = expression, isExpression = "1",
                                          fontSize = taille, fontSizeUnit = "Point",
                                          textColor = .iv_rgba("#212121"),
                                          fontFamily = "Sans Serif"),
               children = .xml_tag("text-buffer", attrs = list(
                 bufferDraw = "1", bufferSize = "1", bufferSizeUnits = "MM",
                 bufferColor = .iv_rgba("#ffffff")))),
      .xml_tag("placement", attrs = list(placement = "1", dist = "1")),
      .xml_tag("rendering", attrs = list(
        scaleVisibility = if (echelle > 0) "1" else "0",
        scaleMin = echelle, scaleMax = "0"))
    )))
}

# Style (renderer, labeling) d'une couche, NULL pour les autres.
# `forets` : noms des forêts de `ugf`, triés (une couleur par forêt).
.iv_style_couche <- function(couche, forets = character(0)) {
  switch(couche,
    arbres = {
      ess <- .iv_essences()
      taille <- 'scale_linear(coalesce("dbh_cm", 7.5), 7.5, 80, 2.4, 6.4)'
      cats <- lapply(seq_len(nrow(ess)), function(i) {
        col <- .iv_groupe_essence(ess$code[i], ess$bdforet[i])
        list(valeur = ess$code[i], libelle = ess$libelle[i],
             symbole = function(n) .iv_marqueur(n, col, taille_expr = taille))
      })
      cats <- c(cats, list(list(valeur = "", libelle = "Essence \u00e0 saisir",
        symbole = function(n) .iv_marqueur(n, .IV_COULEURS$inconnue, taille_expr = taille))))
      list(renderer = .iv_renderer_categories("essence_arbre", cats),
           labeling = .iv_etiquette("\"tree_id\" || ' \u2013 ' || format_number(\"dbh_cm\", 0)",
                                    8, 1000))
    },
    ugf = {
      cats <- lapply(seq_along(forets), function(i) {
        col <- .IV_COULEURS$foncier[(i - 1L) %% length(.IV_COULEURS$foncier) + 1L]
        list(valeur = forets[i], libelle = forets[i],
             symbole = function(n) .iv_surface(n, col, 0.9, 0x33))
      })
      cats <- c(cats, list(list(valeur = "", libelle = "Sans for\u00eat",
        symbole = function(n) .iv_surface(n, .IV_COULEURS$sans_foret, 0.9, 0x33))))
      list(renderer = .iv_renderer_categories("foret", cats),
           labeling = .iv_etiquette("coalesce(\"parcelle_onf\", \"libelle\", \"ug_id\")", 10))
    },
    parcelles = list(renderer = .iv_renderer_unique(.iv_surface("0", .IV_COULEURS$parcelle, 0.4, 0x22)),
                     labeling = .iv_etiquette("\"section\" || ' ' || \"numero\"", 7, 5000)),
    placettes = {
      taille <- "if(\"type\" = 'Over', 2.4, 3.5)"
      cats <- lapply(names(.IV_ETATS_PLACETTE), function(k) {
        e <- .IV_ETATS_PLACETTE[[k]]
        list(valeur = k, libelle = e[2], symbole = function(n) {
          .iv_marqueur(n, e[1], 3.5, .IV_COULEURS$contour_placette, taille_expr = taille)
        })
      })
      cats <- c(cats, list(list(valeur = "", libelle = "\u00c0 faire", symbole = function(n) {
        .iv_marqueur(n, "#ffffff", 3.5, .IV_COULEURS$contour_placette, taille_expr = taille)
      })))
      list(renderer = .iv_renderer_categories("etat_traitement", cats),
           labeling = .iv_etiquette("\"plot_id\"", 9, 25000))
    },
    centres_mesures = list(renderer = .iv_renderer_unique(
      .iv_marqueur("0", .IV_COULEURS$centre, 3.5, .IV_COULEURS$centre, "cross2", 0.6))),
    cibles = list(renderer = .iv_renderer_unique(
      .iv_marqueur("0", .IV_COULEURS$cible, 2.6, .IV_COULEURS$contour_placette, "square")),
      labeling = .iv_etiquette("\"id_cible\"", 8, 1000)),
    detections = list(renderer = .iv_renderer_unique(
      .iv_marqueur("0", "#000000", 4, .IV_COULEURS$detection, "circle", 0.4, alpha = 0))),
    houppiers = list(renderer = .iv_renderer_unique(.iv_surface("0", .IV_COULEURS$houppier, 0.4, 0))),
    NULL)
}

# Couches masquées par défaut (Marculus : des milliers de houppiers).
.IV_MASQUEES <- "houppiers"

# URI XYZ d'une couche WMTS de la Géoplateforme (grille PM_0_19, sans
# GetCapabilities, trop lourd : il bloque l'ouverture du projet).
.iv_tuiles_ign <- function(couche, style, format) {
  url <- paste0("https://data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=",
                couche, "&STYLE=", gsub(" ", "%20", style, fixed = TRUE), "&FORMAT=", format,
                "&TILEMATRIXSET=PM_0_19&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}")
  paste0("type=xyz&url=", utils::URLencode(url, reserved = TRUE, repeated = TRUE), "&zmin=0&zmax=19")
}

# Fonds de carte, du haut vers le bas, sous toutes les couches du projet.
.iv_fonds <- function() {
  ign <- "\u00a9 IGN G\u00e9oplateforme, Licence Ouverte Etalab 2.0"
  list(
    list(nom = "Cadastre IGN", visible = FALSE, attribution = "cadastre \u00a9 IGN",
         source = .iv_tuiles_ign("CADASTRALPARCELS.PARCELLAIRE_EXPRESS", "PCI vecteur", "image/png")),
    list(nom = "Plan IGN", visible = TRUE, attribution = ign,
         source = .iv_tuiles_ign("GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2", "normal", "image/png")),
    list(nom = "Ortho IGN", visible = FALSE, attribution = ign,
         source = .iv_tuiles_ign("ORTHOIMAGERY.ORTHOPHOTOS", "normal", "image/jpeg")),
    list(nom = "OpenStreetMap", visible = FALSE, attribution = "\u00a9 contributeurs OpenStreetMap",
         source = paste0("type=xyz&url=",
                         utils::URLencode("https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                          reserved = TRUE), "&zmin=0&zmax=19"))
  )
}
