//! Indices spectraux RECONFORT, un pixel a la fois (fonctions pures, sans R).

/// Longueurs d'onde (nm) des bandes Sentinel-2 utilisees par iota2.
const L_B4: f64 = 665.0;
const L_B5: f64 = 704.0;
const L_B6: f64 = 741.0;
const L_B8A: f64 = 865.0;
const L_B11: f64 = 1610.0;
const L_B12: f64 = 2190.0;

/// Denominateur nul -> 1 (comme `custom_index.py`). Un NaN reste un NaN : les
/// NA de R sont des NaN en f64 et doivent se propager.
#[inline]
fn denominateur(d: f64) -> f64 {
    if d == 0.0 {
        1.0
    } else {
        d
    }
}

/// CRswir = B11 / (B8A + (1610 - 865) * (B12 - B8A) / (2190 - 865)).
pub fn cr_swir_pixel(b8a: f64, b11: f64, b12: f64) -> f64 {
    let d = b8a + (L_B11 - L_B8A) * (b12 - b8a) / (L_B12 - L_B8A);
    b11 / denominateur(d)
}

/// CRre = B5 / (B4 + (704 - 665) * (B6 - B4) / (741 - 665)).
pub fn cr_re_pixel(b4: f64, b5: f64, b6: f64) -> f64 {
    let d = b4 + (L_B5 - L_B4) * (b6 - b4) / (L_B6 - L_B4);
    b5 / denominateur(d)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn proche(a: f64, b: f64) -> bool {
        (a - b).abs() < 1e-12
    }

    #[test]
    fn cr_swir_valeur_ecrite_a_la_main() {
        // B8A=0.4, B12=0.2, B11=0.3 :
        // d = 0.4 + 745 * (0.2 - 0.4) / 1325 = 0.4 - 149/1325 = 0.4 - 0.112452830...
        let d = 0.4 + 745.0 * (-0.2) / 1325.0;
        assert!(proche(cr_swir_pixel(0.4, 0.3, 0.2), 0.3 / d));
        // forme decimale ecrite a la main : 0.3 / 0.28754716981...
        assert!((cr_swir_pixel(0.4, 0.3, 0.2) - 1.04331).abs() < 1e-4);
    }

    #[test]
    fn cr_swir_bandes_egales_donne_le_rapport() {
        // B12 = B8A -> d = B8A, CRswir = B11 / B8A.
        assert!(proche(cr_swir_pixel(0.5, 0.25, 0.5), 0.5));
    }

    #[test]
    fn cr_re_valeur_ecrite_a_la_main() {
        // B4=0.1, B6=0.4, B5=0.2 : d = 0.1 + 39 * 0.3 / 76 = 0.1 + 0.153947368...
        assert!(proche(cr_re_pixel(0.1, 0.2, 0.4), 0.2 / (0.1 + 11.7 / 76.0)));
        assert!((cr_re_pixel(0.1, 0.2, 0.4) - 0.78757).abs() < 1e-4);
    }

    #[test]
    fn denominateur_nul_remplace_par_un() {
        // B8A = 0 et B12 = 0 -> d = 0 -> CRswir = B11 / 1.
        assert!(proche(cr_swir_pixel(0.0, 0.3, 0.0), 0.3));
        assert!(proche(cr_re_pixel(0.0, 0.2, 0.0), 0.2));
        // d s'annule sans que les bandes soient nulles (valeurs hors
        // reflectance, mais exactes) : B4 + 39*(B6-B4)/76 = 0 pour B4 = 39,
        // B6 = -37 ; B8A + 745*(B12-B8A)/1325 = 0 pour B8A = 745, B12 = -580.
        assert!(proche(cr_re_pixel(39.0, 5.0, -37.0), 5.0));
        assert!(proche(cr_swir_pixel(745.0, 7.0, -580.0), 7.0));
    }

    #[test]
    fn na_se_propage() {
        assert!(cr_swir_pixel(f64::NAN, 0.3, 0.2).is_nan());
        assert!(cr_swir_pixel(0.4, f64::NAN, 0.2).is_nan());
        assert!(cr_swir_pixel(0.4, 0.3, f64::NAN).is_nan());
        assert!(cr_re_pixel(0.1, f64::NAN, 0.4).is_nan());
        assert!(cr_re_pixel(f64::NAN, 0.2, 0.4).is_nan());
    }
}
