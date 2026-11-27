//! Noyau Rust de nemeton (ADR 0003 de nemetonplateforme).
//!
//! Premier contenu : les indices CRswir et CRre de RECONFORT, calcules par
//! pixel. Les formules sont celles d'iota2 (`custom_index.py`, depot amont
//! framagit.org/fl.mouret/reconfort, Apache-2.0), reprises ici sous GPL-3 avec
//! citation de la source.
//!
//! Le paquet R reste utilisable sans ce crate : `R/reconfort_indices.R` porte
//! un repli en R pur qui doit rendre les memes valeurs (test d'egalite a 1e-12).

use extendr_api::prelude::*;

mod indices;

pub use indices::{cr_re_pixel, cr_swir_pixel};

/// CRswir par pixel : B11 / (B8A + (1610 - 865) * (B12 - B8A) / (2190 - 865)).
/// Les vecteurs ont la meme longueur ; un NA en entree donne un NA en sortie ;
/// un denominateur nul est remplace par 1.
/// @param b8a Bande B8A (865 nm).
/// @param b11 Bande B11 (1610 nm).
/// @param b12 Bande B12 (2190 nm).
/// @return Vecteur numerique de la longueur des bandes.
/// @noRd
#[extendr]
fn rust_cr_swir(b8a: &[f64], b11: &[f64], b12: &[f64]) -> extendr_api::Result<Vec<f64>> {
    if b8a.len() != b11.len() || b8a.len() != b12.len() {
        return Err(Error::Other(
            "b8a, b11 et b12 doivent avoir la meme longueur".into(),
        ));
    }
    Ok(b8a
        .iter()
        .zip(b11)
        .zip(b12)
        .map(|((&a, &b11), &b12)| {
            if a.is_nan() || b11.is_nan() || b12.is_nan() {
                f64::na()
            } else {
                cr_swir_pixel(a, b11, b12)
            }
        })
        .collect())
}

/// CRre par pixel : B5 / (B4 + (704 - 665) * (B6 - B4) / (741 - 665)).
/// Memes regles que `rust_cr_swir`.
/// @param b4 Bande B4 (665 nm).
/// @param b5 Bande B5 (704 nm).
/// @param b6 Bande B6 (741 nm).
/// @return Vecteur numerique de la longueur des bandes.
/// @noRd
#[extendr]
fn rust_cr_re(b4: &[f64], b5: &[f64], b6: &[f64]) -> extendr_api::Result<Vec<f64>> {
    if b4.len() != b5.len() || b4.len() != b6.len() {
        return Err(Error::Other(
            "b4, b5 et b6 doivent avoir la meme longueur".into(),
        ));
    }
    Ok(b4
        .iter()
        .zip(b5)
        .zip(b6)
        .map(|((&b4, &b5), &b6)| {
            if b4.is_nan() || b5.is_nan() || b6.is_nan() {
                f64::na()
            } else {
                cr_re_pixel(b4, b5, b6)
            }
        })
        .collect())
}

/// Votes d'une foret SharkRF (mission 095) : pour chaque ligne de `x` (matrice
/// n x nvar, colonne par colonne), un vote par arbre pour la classe de la
/// feuille atteinte. Representation compacte de `reconfort_sharkrf_lire()` :
/// index globaux 1-based, `attr` = -1 pour une feuille, `gauche` = classe
/// (0-based) pour une feuille. Descente : x[attr] <= seuil -> gauche, sinon droite.
/// @param attr Attribut de chaque noeud (0-based), -1 pour une feuille.
/// @param seuil Seuil de chaque noeud.
/// @param gauche Fils gauche (1-based) ou classe de la feuille.
/// @param droite Fils droit (1-based).
/// @param racines Racine (1-based) de chaque arbre.
/// @param x Matrice des caracteristiques, colonne par colonne.
/// @param n Nombre de lignes de `x`.
/// @param k Nombre de classes.
/// @return Matrice n x k des votes, colonne par colonne.
/// @noRd
#[extendr]
fn rust_sharkrf_votes(
    attr: &[i32],
    seuil: &[f64],
    gauche: &[i32],
    droite: &[i32],
    racines: &[i32],
    x: &[f64],
    n: i32,
    k: i32,
) -> extendr_api::Result<Vec<i32>> {
    let n = n as usize;
    let k = k as usize;
    if n == 0 || x.len() % n != 0 {
        return Err(Error::Other("x doit avoir n lignes".into()));
    }
    if attr.len() != seuil.len() || attr.len() != gauche.len() || attr.len() != droite.len() {
        return Err(Error::Other("vecteurs du modele de longueurs differentes".into()));
    }
    let nvar = x.len() / n;
    let mut votes = vec![0i32; n * k];
    for i in 0..n {
        for &r in racines {
            let mut nd = (r - 1) as usize;
            loop {
                let a = attr[nd];
                if a < 0 {
                    break;
                }
                let a = a as usize;
                if a >= nvar {
                    return Err(Error::Other("attribut hors de x".into()));
                }
                let v = x[i + n * a];
                let suivant = if v <= seuil[nd] { gauche[nd] } else { droite[nd] };
                nd = (suivant - 1) as usize;
            }
            let c = gauche[nd] as usize;
            if c >= k {
                return Err(Error::Other("classe hors du nombre de classes".into()));
            }
            votes[i + n * c] += 1;
        }
    }
    Ok(votes)
}

/// Version du crate (preuve que la chaine R <-> Rust fonctionne).
/// @noRd
#[extendr]
fn rust_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

extendr_module! {
    mod nemeton;
    fn rust_cr_swir;
    fn rust_cr_re;
    fn rust_version;
    fn rust_sharkrf_votes;
}
