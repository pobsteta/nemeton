# ============================================================
# nemeton - logo hex avec image centrale
# Compatible CRAN + pkgdown + README
# ============================================================

pkg <- "nemeton"

# ---- Dépendances
needed <- c("hexSticker", "magick", "svglite")
to_install <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install)

suppressPackageStartupMessages({
  library(hexSticker)
  library(magick)
})

# ---- Dossiers standards
dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("inst/hexsticker", recursive = TRUE, showWarnings = FALSE)

# ---- Image source (TON IMAGE)
img_path <- "/home/pascal/Images/nemeton03.png"

if (!file.exists(img_path)) {
  stop("Image centrale introuvable : ", img_path)
}

# ---- Lecture + préparation image
# - fond transparent
# - légère amélioration du contraste
img <- image_read(img_path) |>
  image_convert("png") |>
  image_resize("800 x 600") |> 
  image_trim() |>
  image_background("none") |>
  image_contrast(sharpen = 1)

# ---- Paramètres graphiques (sobres et lisibles)
bg_fill    <- "#688577"   # fond hex
hex_border <- "#688577"   # contour
txt_col    <- "#E9E6DC"   # texte

# ---- Export PNG (principal)
png_path <- "man/figures/logo.png"

hexSticker::sticker(
  subplot   = img,
  package   = pkg,
  p_color   = txt_col,
  p_size    = 22,
  p_y       = 0.45,
  
  s_x       = 1.00,
  s_y       = 1.10,
  s_width   = 1.5,
  s_height  = 1.5,
  
  h_fill    = bg_fill,
  h_color   = hex_border,
  h_size    = 1.2,
  
  spotlight = TRUE,
  l_x       = 1.00,
  l_y       = 1.02,
  l_alpha   = 0.12,
  
  filename  = png_path
)

# ---- Copie interne (archive)
file.copy(png_path, "inst/hexsticker/nemeton.png", overwrite = TRUE)

# ---- Export SVG (vectoriel)
svg_path <- "man/figures/logo.svg"

hexSticker::sticker(
  subplot   = img,        # ton PNG transparent
  package   = "nemeton",
  
  # TEXTE (beaucoup plus petit en SVG)
  p_color   = txt_col,
  p_size    = 8,         # ↓ CRUCIAL
  p_y       = 0.45,
  
  # IMAGE CENTRALE (plus grande)
  s_x       = 1.00,
  s_y       = 0.92,
  s_width   = 1.5,     
  s_height  = 1.5,       
  
  # HEXAGONE
  h_fill    = bg_fill,
  h_color   = hex_border,
  h_size    = 1.2,
  
  # Éclairage
  spotlight = TRUE,
  l_x       = 1.00,
  l_y       = 1.02,
  l_alpha   = 0.10,
  
  filename  = "man/figures/logo.svg"
)

file.copy(svg_path, "inst/hexsticker/nemeton.svg", overwrite = TRUE)

message("Logo nemeton généré avec image centrale ✔")
