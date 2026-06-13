#!/usr/bin/env bash
# fill_corpus_prod.sh — complète le corpus RAG prod SANS FRESH (incrémental).
# Saute les docs déjà ingérés (par titre) et n'ajoute que les manquants —
# utile après un build partiel (ex. rate-limit Mistral sur quelques docs).
# Lancer via :  ! bash ~/dev/nemeton/data-raw/fill_corpus_prod.sh
set -euo pipefail
cd "$(dirname "$0")/.."

url=$(grep -E '^NEMETON_DB_URL=' .Renviron | head -1 | cut -d= -f2- | tr -d '"'"'"'')
if [ -z "$url" ]; then echo "NEMETON_DB_URL introuvable dans .Renviron" >&2; exit 1; fi
export NEMETON_KNOWLEDGE_DB_URL="$url"
# PAS de NEMETON_CORPUS_FRESH : build idempotent, ne touche pas l'existant.
echo "Cible corpus (incrémental) : $NEMETON_KNOWLEDGE_DB_URL"
Rscript data-raw/build_knowledge_corpus.R
