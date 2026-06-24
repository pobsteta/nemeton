# ------------------------------------------------------------------
# Vendored from RECONFORT (https://framagit.org/fl.mouret/reconfort,
# main 25198c9), file iota2/external_features/custom_index.py.
# License: Apache-2.0 (see inst/NOTICE). Verbatim — do not edit here;
# re-vendor from upstream if it changes.
#
# IOTA2 `external_features` hooks computing the two RECONFORT
# continuum-removal indices on the gap-filled Sentinel-2 series:
#   CRswir = B11 / [ B8A + (1610-865)*(B12-B8A)/(2190-865) ]   (water)
#   CRre   = B5  / [ B4  + ( 704-665)*(B6 -B4 )/( 741-665) ]   (chlorophyll)
# ------------------------------------------------------------------
import numpy as np

# nemeton: l'iota2 récent exige des labels I2Label/I2TemporalLabel (plus des
# chaînes). Les features CRswir/CRre sont temporelles (une par date interpolée),
# d'où I2TemporalLabel(sensor_name, feat_name, date). Le CALCUL est inchangé —
# seul le labelling change ; l'ordre des colonnes (par date) est préservé, donc
# le vecteur de features vu par le modèle sharkrf v3 est identique.
from iota2.learning.utils import I2TemporalLabel

def get_crswir(self):
    """
    compute the CRswir indice
    """

    num = self.get_interpolated_Sentinel2_B11()

    den = self.get_interpolated_Sentinel2_B8A() + (1610 - 865) * (
                (self.get_interpolated_Sentinel2_B12() - self.get_interpolated_Sentinel2_B8A()) / (2190 - 865))
    den = np.where(den == 0, 1, den)

    coef = num / den

    labels = [
        I2TemporalLabel(sensor_name="sentinel2", feat_name="CRswir", date=date)
        for date in self.interpolated_dates["Sentinel2"]
    ]

    return coef, labels


def get_crre(self):
    """
    compute the CRre indice
    """
    # coef = self.get_interpolated_Sentinel2_B5() / (
    #         1.1 + self.get_interpolated_Sentinel2_B4() + (704 - 665) * (
    #         (self.get_interpolated_Sentinel2_B6() - self.get_interpolated_Sentinel2_B4()) / (741 - 665)))

    num = self.get_interpolated_Sentinel2_B5()

    den = self.get_interpolated_Sentinel2_B4() + (704 - 665) * (
            (self.get_interpolated_Sentinel2_B6() - self.get_interpolated_Sentinel2_B4()) / (741 - 665))
    den = np.where(den == 0, 1, den)

    coef = num / den

    labels = [
        I2TemporalLabel(sensor_name="sentinel2", feat_name="CRre", date=date)
        for date in self.interpolated_dates["Sentinel2"]
    ]
    return coef, labels
