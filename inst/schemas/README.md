# Schéma `deperis-v1` (copie)

Copie **non éditable à la main** de `docs/formats/deperis-v1.schema.json` du dépôt
[pobsteta/ramulus](https://github.com/pobsteta/ramulus), source unique du format d'échange `deperis.gpkg`
(ADR 0003 de Ramulus, § 7 ; mission 061 de nemetonplateforme).

- Copié depuis `origin/main` de Ramulus au commit `fb5739a99eac7bd3329fd6929509e7d1fd72ba1e` ; dernier commit de
  Ramulus qui touche le schéma ou les cas communs : `91f6d94573622eb2dfefea6df494e5fe9c8a1ff0` (2026-10-29).
- Mise à jour : à chaque version du format, par une session nemeton, **sur brief de Ramulus**. On recopie le fichier
  tel quel, on change l'empreinte ci-dessous et le commit d'origine ; jamais d'édition à la main.
- Le test `tests/testthat/test-deperis.R` recalcule l'empreinte SHA-256 et échoue si elle diffère.
- nemeton lit dans ce schéma, à l'exécution, les 19 essences et leur type, l'abaque et le catalogue des motifs ;
  `importer_deperis()` valide l'instantané du fichier contre ses règles (interpréteur JSON Schema minimal, interne).

| fichier | sha256 |
|---|---|
| `deperis-v1.schema.json` | `ac3f778d023008ed59ab1f05a1a70a260107c664cdc204e3b9593ad3081c8827` |
