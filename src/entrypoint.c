/*
 * Point d'entree de la bibliotheque partagee de nemeton.
 *
 * Avec Rust (NEMETON_RUST, pose par src/Makevars quand le noyau a ete
 * compile), l'enregistrement des routines est relaye au crate : sans ce relais
 * l'editeur de liens retirerait la bibliotheque statique. Sans Rust, on
 * n'enregistre aucune routine et le paquet tourne sur ses replis en R pur
 * (ADR 0003 de nemetonplateforme).
 */
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#ifdef NEMETON_RUST

void R_init_nemeton_extendr(void *dll);
void register_extendr_panic_hook(void);

void R_init_nemeton(DllInfo *dll) {
    register_extendr_panic_hook();
    R_init_nemeton_extendr(dll);
}

#else

void R_init_nemeton(DllInfo *dll) {
    R_registerRoutines(dll, NULL, NULL, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}

#endif
