# Spec 044 — Extraits OSM `.pbf` pour le traitement batch de massif

**Version** : 0.1.0 (cadrage)
**Date**    : 2026-08-13
**Statut**  : **Ouverte, non implémentée. Décision à Pascal.** Ouverte en
application du §6 de `specs/BRIEF-osm-overpass-unification.md`, qui range
explicitement cette piste **hors** du lot d'unification Overpass et demande de
ne pas la coder dans ce lot.
**Auteur**  : Pascal Obstétar (via Claude), d'après le §6 du brief d'unification.
**Cible**   : à trancher — `foretaccess` (probable, cf. D2) ; **pas** `nemeton`.
**Amont**   : `foretaccess::osm_overpass()` + ADR-010 (`foretaccess/docs/adr/`),
livrés le 2026-08-13 (`foretaccess@3c7b386`).

---

## 1. Pourquoi cette spec existe

Le lot d'unification a produit **un transport Overpass unique** et borné. Il
reste que le choix d'Overpass est adapté à un régime précis, et à un seul :

> Overpass doit rester réservé aux **petites AOI interactives** — exactement le
> cas `nemetonshiny`.
> — `BRIEF-osm-overpass-unification.md` §6

Dès que la cible devient **le massif entier en traitement batch**, ni Overpass
ni le tuilage ne sont le bon outil, pour trois raisons qui sont des propriétés
du protocole, pas des défauts d'implémentation :

1. **Le quota est par requête.** Un batch qui balaie un massif multiplie les
   appels là où un extrait se télécharge une fois.
2. **Overpass ne porte pas de date.** Deux exécutions à un mois d'écart donnent
   des résultats différents sans trace — c'est déjà le constat du §4.2 du brief,
   que la provenance horodatée du client atténue *a posteriori* sans le résoudre
   *a priori*. Un extrait Geofabrik, lui, **est** daté par construction.
3. **Le filtrage local est gratuit.** Sur un extrait, `highway`, `landuse` et
   `building` sortent de la même lecture, sans requête supplémentaire.

## 2. Ce que cette spec ne fait pas

- **Elle ne remplace pas Overpass.** Le chemin interactif reste
  `foretaccess::osm_overpass()` / `acquire_desserte_osm()`. Toute proposition qui
  retirerait le chemin Overpass est hors sujet.
- **Elle ne touche pas au cœur `nemeton`.** Aucun code `R/` de ce repo n'appelle
  OSM (vérifié le 2026-08-13 : seuls les tutoriels le font, et le §5.4 du brief
  les déroge explicitement — note ajoutée dans les trois chunks concernés).
- **Elle ne touche pas aux fonds de carte** (`leaflet`, `maptiles`), au même
  titre que le garde-fou §9 du brief d'unification.

## 3. Décisions à trancher (préalables à tout code)

| # | Décision | Éléments connus au 2026-08-13 |
|---|---|---|
| **D1** | **Le régime batch est-il un besoin réel, et pour quel usage ?** | À ce jour aucun consommateur identifié : `nemetonshiny` est interactif par nature, et les indicateurs cœur ne consomment pas OSM. **Si la réponse est « pas encore », cette spec doit rester ouverte et non implémentée** — c'est le résultat attendu par défaut. |
| **D2** | **Où vit le lecteur d'extraits ?** | `foretaccess` porte déjà le transport canonique et le cache/provenance (ADR-010). L'y ajouter éviterait un second dépôt ; mais un lecteur `.pbf` n'a rien de commun avec un client HTTP, et le mélanger brouillerait le rôle du paquet. |
| **D3** | **`osmextract` ou GDAL directement ?** | `osmextract` **n'est pas installé** ici (vérifié). Le **driver OSM de GDAL est présent** via `sf` (vérifié), et le lot d'unification lit déjà l'XML Overpass par `sf::st_read(layer = "lines")`. Un chemin `.pbf` par GDAL n'ajouterait donc **aucune dépendance** ; `osmextract` apporterait en revanche la résolution d'URL Geofabrik et un cache, qu'il faudrait sinon écrire. |
| **D4** | **Quelle granularité d'extrait, et où le stocker ?** | Un extrait régional pèse un ordre de grandeur au-dessus des AOI habituelles. À arbitrer avec l'ADR-002 (rasters/gros fichiers hors PostgreSQL, S3 pour le volumineux) : un `.pbf` n'est ni un raster ni une donnée de travail, son rangement n'est pas tranché. |
| **D5** | **Politique de réacquisition.** | Un extrait daté qui ne périme jamais est un piège symétrique de celui du §4.2 : la reproductibilité devient de l'obsolescence silencieuse. Il faut une règle explicite (âge maximal ? réacquisition sur demande seulement ?). |

**Aucune de ces décisions n'est prise.** D1 conditionne toutes les autres.

## 4. Si D1 est tranchée positivement — critères d'acceptation

À n'utiliser que le jour où un consommateur batch existe réellement :

1. Le chemin `.pbf` **coexiste** avec le chemin Overpass sans le remplacer, et le
   choix entre les deux est explicite chez l'appelant (pas d'heuristique
   implicite sur la taille de l'AOI, qui rendrait le comportement imprévisible).
2. La provenance porte la **date de l'extrait** en plus de la date de lecture —
   ce sont deux informations distinctes, et c'est tout l'intérêt de la piste.
3. Aucun test ne télécharge d'extrait : fixture `.pbf` minimale versionnée, ou
   mock du lecteur (même exigence que le §7 du brief d'unification).
4. Le nombre de requêtes réseau ne **monte** nulle part (garde-fou §9 du brief).

## 5. Références

- `specs/BRIEF-osm-overpass-unification.md` — §6 (cette piste), §4.2 (le manque
  d'horodatage qui la motive), §9 (garde-fous applicables).
- `foretaccess/docs/adr/ADR-010-client-overpass.md` — décision D1 du lot
  d'unification (transport canonique dans `foretaccess`, exporté).
- `foretaccess::osm_overpass()`, `foretaccess::osm_provenance()` — le chemin
  interactif, livré.
- ADR-002 (stockage) — pour D4.
