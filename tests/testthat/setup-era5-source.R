# Les tests existants simulent le chemin ERA5 classique (mcera5) : le défaut
# `timeseries` est écarté pour toute la suite ; les tests du chemin timeseries
# le demandent par argument (`source = "timeseries"`).
options(nemeton.era5_source = "classique")
