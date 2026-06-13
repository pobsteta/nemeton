#!/usr/bin/env bash
# ocr_biljou_scans.sh — OCR des 4 PDF BILJOU scannés (sans couche texte) vers
# du markdown ingérable en texte intégral par le corpus RAG.
#
# Ces 4 papiers (Bréda 1993/2002/2008, Granier 1996) ne sont disponibles
# librement QUE sous forme scannée (BILJOU) — payants ailleurs (Wiley/NRC/T&F),
# HAL Cloudflare. `pdftools::pdf_text` renvoie 0 caractère → OCR obligatoire.
#
# Sortie : data-raw/references/biljou/ocr/<doc_id>.md (gitignorés — texte de
# papiers copyright, pas dans le repo public ; alimentent le pgvector privé).
# Le manifest pointe `local_path` sur ces .md (ingest_strategy = full).
#
# Prérequis (sans root) : tesseract via conda-forge + poppler-utils (pdftoppm).
#   mamba create -y -n ocr -c conda-forge tesseract   # embarque fra+eng
#
# Usage : bash data-raw/ocr_biljou_scans.sh
set -euo pipefail
cd "$(dirname "$0")/.."

T="$HOME/miniforge3/envs/ocr/bin/tesseract"
[ -x "$T" ] || { echo "tesseract absent : mamba create -y -n ocr -c conda-forge tesseract" >&2; exit 1; }
command -v pdftoppm >/dev/null || { echo "pdftoppm absent (poppler-utils)" >&2; exit 1; }

declare -A MAP=(
  [Breda_1992_Can.J.For.Res.pdf]=breda_1993_water_transfer_oak
  [Granier1996_GCB.pdf]=granier_1996_sapflow
  [Breda_2002_LaHouilleBlanche.pdf]=breda_2002_reservoir_sols
  [SEC2008_Marion_final.pdf]=breda_2008_pompe_biologique
)
mkdir -p data-raw/references/biljou/ocr
for pdf in "${!MAP[@]}"; do
  doc=${MAP[$pdf]}; src="data-raw/references/biljou/$pdf"
  out="data-raw/references/biljou/ocr/${doc}.md"
  [ -f "$src" ] || { echo "ABSENT $pdf (cf. data-raw/references/README.md)"; continue; }
  tmp=$(mktemp -d); pdftoppm -png -r 300 "$src" "$tmp/p" 2>/dev/null
  : > "$out"
  for img in "$tmp"/p-*.png; do "$T" "$img" stdout -l fra+eng 2>/dev/null >> "$out"; echo >> "$out"; done
  rm -rf "$tmp"
  echo "$doc : $(wc -w < "$out") mots"
done
echo "→ ré-ingestion : bash data-raw/fill_corpus_prod.sh (après suppression des 4 docs ref en base)"
