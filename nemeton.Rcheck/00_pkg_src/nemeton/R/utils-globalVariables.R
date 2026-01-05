# Global variable declarations for R CMD check
# These are used in NSE contexts (ggplot2, dplyr) and are not actual globals

utils::globalVariables(c(
  # Variables used in ggplot2 aes()
  "x", "y", "x0", "y0", "x1", "y1",
  "value", "label", "angle", "radius", "text_angle",
  "difference", "indicator", "period", "unit_id",
  ".data"
))
