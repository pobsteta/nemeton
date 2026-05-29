# Spec 009.1 — Corpus de connaissances forestières (spec fille de 009)

**Version** : 0.1.0 (draft)
**Date**    : 2026-05-29
**Statut**  : Draft — à valider.
**Auteur**  : Pascal Obstétar (via Claude)
**Parent**  : `specs/009-rag-perspectives-ia/` (E7 RAG). Spec 009 §1.4
renvoie explicitement la *curation manuelle du corpus* à cette spec
fille 009.1, et §3.4 en pose l'amorce (20-30 documents +
`knowledge_corpus_v1.csv` + `data-raw/build_knowledge_corpus.R`).
**Cible** : livrable **données + pipeline d'ingestion**, indépendant
d'une version de code. Doit être prêt **avant** que le RAG (spec 009)
ait quelque chose à interroger.

---

## 1. Pourquoi une spec dédiée

Spec 009 décrit la *machinerie* RAG (schéma `knowledge_document` /
`knowledge_chunk`, `vector(3072)`, ivfflat cosine, `retrieve_knowledge()`,
citations). Mais **un RAG ne vaut que son corpus**. Un corpus mal
curé, mal licencié ou hors-sujet rend le RAG inutile voire nuisible
(citations fausses, hallucinations « sourcées »). Cette spec traite
le **vrai prérequis** : *quels documents, sous quelle licence, comment
les sourcer, les découper, les enrichir en métadonnées, les versionner
et les gouverner.*

C'est **moitié travail non-technique** (analyse juridique des licences,
identification des sources canoniques) et moitié pipeline reproductible.

## 2. Principe directeur — « moins mais sûr »

Mieux vaut **30 documents de licence claire et de qualité vérifiée**
qu'un corpus volumineux mais juridiquement flou. Chaque chunk cité
dans une perspective IA est une **affirmation publique sourcée** :
la traçabilité et la licence priment sur le volume.

Règles dures :

1. **Licence explicite obligatoire** par document. Pas de licence
   identifiée ⇒ pas d'ingestion (ou lien-seul, cf. §5).
2. **Provenance traçable** par chunk jusqu'à la page/section du
   document source.
3. **Pas de PII**, pas de données personnelles dans le corpus.
4. **Versionnage figé** : un corpus est taggé (`corpus_v1`), comme la
   calibration FORDEAD figée de spec 008.

## 3. Classes de licence et politique d'ingestion

| Classe licence | Exemples | Politique |
|---|---|---|
| **Domaine public / loi** | Code forestier (Légifrance), directives UE (EUR-Lex) | ✅ Ingestion intégrale du texte |
| **Licence ouverte (OGL / Etalab / CC-BY)** | Données IGN, guides ministère, rapports publics ONF/DSF sous LO | ✅ Ingestion intégrale, attribution dans `knowledge_document.license` |
| **CC-BY-NC / CC-BY-SA** | Certains guides CNPF/IDF | 🟨 Ingestion possible si usage non-commercial respecté (Néméton = projet personnel non commercial — à confirmer au cas par cas). Attribution + share-alike notés. |
| **Copyright tous droits réservés** | Papiers scientifiques sous paywall (Elsevier, Springer) | ❌ Pas d'ingestion du PDF. **Lien-seul** : on stocke le titre + DOI + abstract (souvent libre) en `knowledge_document` SANS chunks de corps. Le RAG peut citer la référence mais ne récupère pas le texte intégral. |
| **Autorisation explicite** | Courbes Duplat & Tran-Ha 1997 (M. Tran-Ha, avril 2026, déjà obtenue pour spec 005) | ✅ Ingestion avec mention de l'autorisation dans `license` + `inst/NOTICE` |

**Décision à acter (D1)** : Néméton est un projet **personnel non
commercial** (cf. CLAUDE.md). Est-ce qu'on s'autorise les corpus
CC-BY-NC ? Le risque : si Néméton devient un jour un service, il
faudrait re-purger. Proposition : **oui pour le NC en V1, avec un
flag `license_commercial_ok` par document** pour pouvoir filtrer si
le statut change.

## 4. Corpus V1 — liste cible avec analyse de licence

Reprend et précise §3.4 de spec 009. Pour chaque document : famille
d'indicateurs couverte, profil(s), licence présumée (**à vérifier
source par source — marqueur `to confirm` tant que non fait**, même
convention que `chm_opencanopy` / sources Theia).

| # | Document | Familles | Profils | Licence présumée | Ingestion |
|---|---|---|---|---|---|
| 1 | Bernard & Doridant 2024 — rapport ONF/DSF FORDEAD | R5 | onf, technicien, chercheur | LO Etalab (`to confirm`) | intégrale si LO |
| 2 | Mouret et al. 2022 — méthode FORDEAD (papier) | R5 | chercheur | copyright (`to confirm`) | lien-seul + abstract |
| 3 | Duplat & Tran-Ha 1997 — courbes hauteur dominante | P2 | gestionnaire, technicien | autorisation explicite (acquise spec 005) | intégrale |
| 4 | Forrester et al. 2017 — allométrie biomasse pan-EU | C1 | chercheur | CC-BY (`to confirm`) | intégrale si CC-BY |
| 5 | IGN — guide BD Forêt v2 + règles de regroupement | Toutes | tous | LO Etalab | intégrale |
| 6 | Larrieu et al. 2018 — IBP (indice biodiversité potentielle) | N1, N2, N3, B | naturaliste, gestionnaire | CC-BY (`to confirm`) | intégrale si CC-BY |
| 7 | Vallauri 2020 — forêts anciennes / naturalité | N, T1 | naturaliste, chercheur | copyright (`to confirm`) | lien-seul |
| 8 | IPCC 2019 — AFOLU / carbone forestier | C1, E2 | élu, chercheur, investisseur | usage libre IPCC | intégrale |
| 9 | CITEPA — inventaires GES France | E2, C1 | élu régional, investisseur | LO (`to confirm`) | intégrale si LO |
| 10 | Code forestier — articles L121-1, L122-2, … | S, P | tous | domaine public (Légifrance) | intégrale |
| 11 | Stratégie forêts UE — COM(2021) 572 | Toutes | élu, élu régional | EUR-Lex (réutilisation autorisée) | intégrale |
| 12 | Guides sylvicoles CNPF/CRPF régionaux (BFC en priorité) | P, C, R | propriétaire privé, gestionnaire coop | CC-BY-NC (`to confirm`) | selon D1 |
| 13 | RMT AFORCE — fiches adaptation changement climatique | R, C, T | tous | LO (`to confirm`) | intégrale si LO |
| 14 | Mercuriales bois (FNB, indicateurs filière) | P1, P3, E1 | industrie, bûcheron, investisseur | copyright FNB (`to confirm`) | lien-seul ou agrégats |

**~14 sources prioritaires V1** (vs 20-30 visées par spec 009 — on
démarre serré, on étend en 009.x). Au moins **6-8 ingérables
intégralement** (domaine public + LO + CC-BY + autorisation), le reste
en lien-seul.

## 5. Mode « lien-seul » (documents non redistribuables)

Pour les copyrights stricts (papiers paywall, mercuriales FNB), on
**n'ingère pas le corps** mais on stocke en `knowledge_document` :
titre, auteurs, année, DOI/URL, **abstract** (souvent en libre accès)
et métadonnées (familles, profils). `knowledge_chunk` ne contient
alors que l'abstract (1 chunk). Le RAG peut **citer la référence**
(« voir Mouret et al. 2022, doi:… ») sans en récupérer le texte
intégral. Évite tout problème de licence tout en gardant la
référence dans le radar du LLM.

Flag `knowledge_document.ingestion_mode` ∈ {`full`, `abstract_only`,
`link_only`} (extension du schéma spec 009 — à coordonner).

## 6. Manifest + pipeline d'ingestion

### 6.1 `inst/extdata/knowledge_corpus_v1.csv` (manifest déclaratif)

Colonnes :

| Colonne | Type | Note |
|---|---|---|
| `doc_id` | chr | slug stable (`onf_dsf_fordead_2024`) |
| `title` | chr | titre complet |
| `authors` | chr | |
| `year` | int | |
| `source_url` | chr | URL canonique / DOI |
| `local_path` | chr | chemin du PDF téléchargé (si full) ou vide |
| `license` | chr | `public-domain` \| `OGL-Etalab` \| `CC-BY` \| `CC-BY-NC` \| `explicit-auth` \| `copyright` |
| `license_commercial_ok` | bool | cf. D1 |
| `ingestion_mode` | chr | `full` \| `abstract_only` \| `link_only` |
| `lang` | chr | `fr` \| `en` |
| `doc_type` | chr | `report` \| `paper` \| `guide` \| `law` \| `dataset_doc` |
| `family_codes` | chr | `R5` ou `R5,C1` (multi) |
| `profile_codes` | chr | `onf,technicien,chercheur` |
| `region_scope` | chr | `FR` \| `BFC` \| `EU` \| `vide` (national) |
| `essence_scope` | chr | `epicea,sapin` \| vide |
| `notes` | chr | provenance, réserve juridique |

Le manifest est **la source de vérité** ; il est versionné dans le
repo. Un document n'entre dans le corpus que s'il y figure.

### 6.2 `data-raw/build_knowledge_corpus.R` (pipeline reproductible)

1. Lit le manifest CSV.
2. Pour chaque ligne `ingestion_mode = full` : télécharge le PDF
   (`source_url` → `local_path`) si licence le permet ; sinon skip
   avec warn.
3. Parse le document (PDF via `pdftools`, MD/HTML via `xml2`/`rvest`).
4. Appelle `nemeton::ingest_knowledge_document(con, source, metadata,
   chunk_size, chunk_overlap)` (livré par spec 009) en boucle.
5. `abstract_only` / `link_only` : ingère seulement l'abstract (ou
   rien que les métadonnées) sans télécharger le corps.
6. **Idempotent** : re-run ne re-télécharge ni ne re-embedde les
   documents déjà ingérés (clé sur `doc_id` + hash du contenu).

Le script vit dans `data-raw/` (pas packagé) ; le manifest CSV vit
dans `inst/extdata/` (packagé, donc auditable par tout utilisateur).

## 7. Stratégie de chunking par type de document

Spec 009 fixe `chunk_size ≈ 512 tokens`, `overlap ≈ 64`. 009.1 précise
**la découpe sémantique selon le type** :

| `doc_type` | Stratégie de chunk | Métadonnée de provenance |
|---|---|---|
| `law` (Code forestier) | 1 chunk = 1 article (L121-1, …) | numéro d'article |
| `report` / `paper` | découpe par section + recouvrement 64 tokens, ne pas couper au milieu d'un tableau | n° de page + titre de section |
| `guide` | découpe par sous-chapitre | titre de chapitre |
| `dataset_doc` | découpe par rubrique | nom de rubrique |

Chaque chunk porte `source_locator` (page/article/section) pour que la
citation soit **précise** (« Bernard & Doridant 2024, p.42 », pas juste
« Bernard & Doridant 2024 »).

## 8. Enrichissement des métadonnées (filtrage hybride)

Le RAG de spec 009 filtre par `family_codes` et `profile_codes`. 009.1
ajoute (au niveau document, hérité par chunk) :
- `region_scope` — pour ne pas citer un guide CRPF Occitanie sur une
  forêt jurassienne
- `essence_scope` — pertinence essence (épicéa/sapin pour FORDEAD)
- `ndp_relevant` — certains documents ne valent que pour NDP élevé
  (inventaire terrain) vs NDP 0 (données publiques)

Le filtrage hybride (vector similarity + filtre métadonnée) est dans
`retrieve_knowledge()` (spec 009) ; 009.1 garantit que les métadonnées
existent et sont justes.

## 9. Gouvernance et mise à jour

- **Versionnage** : `corpus_v1` figé. Une modification du manifest
  (ajout/retrait de document) bump `corpus_v2` et nécessite un re-run
  du pipeline. La version du corpus est stockée en DB
  (`knowledge_document.corpus_version`) pour audit.
- **Qui ajoute** : ajout d'un document = PR avec (a) ligne manifest,
  (b) vérification de licence documentée dans `notes`, (c) re-run du
  pipeline. Pas d'ajout « sauvage » hors manifest.
- **Validation éditoriale** : un document scientifique contesté ou
  obsolète peut être retiré (ex. méthode dépassée). Traçabilité via
  git sur le manifest.
- **Réévaluation licences** : si Néméton change de statut
  (personnel → service), re-filtrer sur `license_commercial_ok`.

## 10. Décisions actées (2026-05-29, via AskUserQuestion)

| # | Décision | Choix acté |
|---|---|---|
| **D1** | Corpus CC-BY-NC en V1 ? | ✅ **Oui**, avec flag `license_commercial_ok = FALSE` par document pour purge/re-filtrage si Néméton change de statut commercial. Débloque les guides CNPF/CRPF régionaux (forte valeur métier). |
| **D2** | FR-only ou FR+EN ? | ✅ **FR + EN dès V1**. Les papiers méthode (Mouret 2022, Forrester 2017, Larrieu 2018, IPCC) sont en EN ; le RAG multilingue de spec 009 gère la requête cross-langue + citation dans la langue source. |
| **D3** | Stockage des PDF ? | ✅ **Hors repo, gitignoré** : `data-raw/knowledge_pdfs/` dans `.gitignore`. Le manifest CSV (packagé, versionné) suffit à reconstituer le corpus via le pipeline. Pas de PDF dans git (poids + redistribution). |
| **D4** | Taille V1 ? | ✅ **8-14 documents, ingérables d'abord** : prioriser les 6-8 full-ingestion (domaine public + LO + CC-BY + autorisation), le reste en lien-seul. Valide la chaîne complète sans noyer la curation. Extension en 009.x. |
| **D5** | Vérification juridique des `to confirm` ? | ✅ **Mode de travail acté** : Claude produit l'analyse de licence par document (présomption + où vérifier la source canonique), **l'utilisateur (Pascal) tranche le statut juridique source par source**. Claude ne décide jamais du juridique. Tant qu'une licence n'est pas tranchée, le document reste marqueur `to confirm` et **n'est pas ingéré** (ou en lien-seul). |

## 11. Livrables 009.1

| Livrable | Emplacement | Type |
|---|---|---|
| Manifest corpus V1 | `inst/extdata/knowledge_corpus_v1.csv` | données (packagé) |
| Pipeline d'ingestion | `data-raw/build_knowledge_corpus.R` | script (non packagé) |
| Analyse de licence par document | colonne `license` + `notes` du manifest | doc |
| Mise à jour `inst/NOTICE` | attributions (Tran-Ha, IGN, ONF, IPCC…) | doc |
| Extension schéma (si retenue) : `ingestion_mode`, `corpus_version`, `license_commercial_ok` | à coordonner avec migration spec 009 `0004_knowledge_base` | schéma DB |

## 12. Dépendances et séquencement

```
009.1 (corpus)              009 (RAG machinery)
   │                            │
   ├─ manifest CSV ─────────────┤  (le pipeline 009.1 appelle
   ├─ build pipeline ───────────┤   ingest_knowledge_document() de 009)
   │                            │
   └────────────┬───────────────┘
                ▼
        Corpus embeddé dans pgvector
                │
                ▼
        retrieve_knowledge() utilisable
                │
                ▼
        Perspectives IA sourcées (app)
```

**Ordre de réalisation recommandé** :
1. Valider 009 (machinery) + 009.1 (corpus) — paperwork.
2. Coder 009 : migration `0004_knowledge_base`, `embed_text()`,
   `ingest_knowledge_document()`, `retrieve_knowledge()`,
   `format_citations()`. (Le RAG peut être codé et testé sur un
   corpus jouet de 2-3 docs.)
3. Exécuter 009.1 : vérifier les licences, remplir le manifest,
   sourcer les PDF ingérables, lancer le pipeline → corpus réel.
4. App : injecter les chunks dans le prompt + UI citations.

Le code 009 peut donc avancer en parallèle de la curation 009.1 (sur
corpus jouet), mais la **valeur** n'arrive qu'avec le corpus réel.

## 13. Hors scope 009.1

- **Scraping automatisé** de sites forestiers (CNPF, etc.) — manuel
  et curé en V1.
- **Flux temps réel** (mercuriales bois live) — V2.
- **OCR de documents scannés** — on ne prend que des PDF texte.
- **Traduction automatique** du corpus — on garde la langue source,
  le RAG multilingue de spec 009 gère la requête cross-langue.
