# Petit NetCDF valide (2 x 2 x 48 pas horaires) : les caches ERA5 vérifient
# désormais que le fichier se relit (audit 1.0, v0.209.0), un file.create() vide
# ne passe plus.
.nc_ok <- function(path, v4 = FALSE) {
  skip_if_not_installed("ncdf4")
  x <- ncdf4::ncdim_def("longitude", "degrees_east", c(5.95, 6.05))
  y <- ncdf4::ncdim_def("latitude", "degrees_north", c(47.95, 48.05))
  t <- ncdf4::ncdim_def("time", "hours since 1900-01-01", 1:48, unlim = TRUE)
  v <- ncdf4::ncvar_def("t2m", "K", list(x, y, t), prec = "float")
  nc <- ncdf4::nc_create(path, list(v), force_v4 = v4)
  ncdf4::ncvar_put(nc, v, rep(285, 2 * 2 * 48))
  ncdf4::nc_close(nc)
  invisible(TRUE)
}
