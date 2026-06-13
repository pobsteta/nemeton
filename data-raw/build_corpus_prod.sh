#!/usr/bin/env bash
# build_corpus_prod.sh — rebuild FRESH du corpus RAG dans le pgvector PROD.
# Lancer via :  ! bash ~/dev/nemeton/data-raw/build_corpus_prod.sh
# (commande courte = pas de coupure de ligne au collage)
#
# Pointe NEMETON_KNOWLEDGE_DB_URL sur la prod (NEMETON_DB_URL de .Renviron)
# DE FACON EXPLICITE — le build n'a aucun fallback auto vers la prod.
# FRESH=TRUE : efface le corpus existant puis réingère le manifest courant.
# MISTRAL_API_KEY est lu par R depuis .Renviron.
set -euo pipefail
cd "$(dirname "$0")/.."

url=$(grep -E '^NEMETON_DB_URL=' .Renviron | head -1 | cut -d= -f2- | tr -d '"'"'"'')
if [ -z "$url" ]; then
  echo "NEMETON_DB_URL introuvable dans .Renviron" >&2
  exit 1
fi
export NEMETON_KNOWLEDGE_DB_URL="$url"
export NEMETON_CORPUS_FRESH=TRUE
echo "Cible corpus : $NEMETON_KNOWLEDGE_DB_URL"
Rscript data-raw/build_knowledge_corpus.R
