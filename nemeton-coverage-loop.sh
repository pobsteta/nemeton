#!/bin/bash
#══════════════════════════════════════════════════════════════════════════════
# nemeton-coverage-loop.sh
# Boucle autonome d'élévation de couverture pour pobsteta/nemeton
# Version PARALLÈLE — lance N agents Claude simultanément (un par fichier)
#
# Projet : Package R + Shiny — Analyse systémique de territoires forestiers
# Stack  : testthat (ed. 3) + shinytest2 (E2E Shiny) + covr
# Repo   : https://github.com/pobsteta/nemeton
# Version: 1.1.0 — agents parallèles + retry/lock/model
#══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

#──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION — Adaptez ces valeurs
#──────────────────────────────────────────────────────────────────────────────
TARGET_COVERAGE=80          # Taux cible (%)
MAX_ITERATIONS=20           # Sécurité anti-boucle infinie (chaque iter = N agents)
MAX_PARALLEL=5              # Nombre d'agents Claude en parallèle par itération
MAX_TURNS_PER_AGENT=50      # Tours Claude Code par agent
SLEEP_BETWEEN=10            # Pause (sec) entre itérations (rate-limiting)
PROJECT_DIR="$(pwd)"        # Racine du package (contient DESCRIPTION)
LOG_FILE="coverage-loop.log"
AGENT_LOG_DIR="coverage-agent-logs"
BRANCH_NAME="feat/auto-coverage-boost"
STAGNATION_COUNT=0          # Compteur de stagnation
MAX_STAGNATION=3            # Relance avec stratégie différente après N stagnations
LOCK_DIR="coverage-locks"   # Verrous pour éviter les conflits entre agents

#──────────────────────────────────────────────────────────────────────────────
# COULEURS
#──────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

log()  { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
ok()   { echo -e "${GREEN}✅ $*${NC}"; }
fail() { echo -e "${RED}❌ $*${NC}"; }

#──────────────────────────────────────────────────────────────────────────────
# VÉRIFICATIONS PRÉALABLES
#──────────────────────────────────────────────────────────────────────────────
log "Vérifications préalables..."

if ! command -v claude &> /dev/null; then
    fail "Claude Code CLI non trouvé."
    echo "   npm install -g @anthropic-ai/claude-code"
    exit 1
fi

if ! command -v Rscript &> /dev/null; then
    fail "Rscript non trouvé."
    exit 1
fi

if [ ! -f "$PROJECT_DIR/DESCRIPTION" ]; then
    fail "Pas de DESCRIPTION dans $PROJECT_DIR"
    echo "   Ce script doit être lancé depuis la racine du package nemeton."
    exit 1
fi

# Vérifier Chrome/Chromium (requis par shinytest2 via chromote)
CHROME_OK=false
for cmd in google-chrome chromium-browser chromium; do
    if command -v "$cmd" &> /dev/null; then
        CHROME_OK=true
        ok "Navigateur détecté : $cmd"
        break
    fi
done
if [ "$CHROME_OK" = false ]; then
    warn "Chrome/Chromium non détecté — shinytest2 en a besoin pour les tests E2E."
    echo "   Pour installer : sudo apt-get install -y chromium-browser"
fi

# Branche git dédiée
if git rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
        log "Création de la branche $BRANCH_NAME..."
        git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"
    fi
    ok "Branche : $BRANCH_NAME"
else
    warn "Pas de dépôt git — les changements ne seront pas versionnés."
fi

# Répertoire de logs des agents
mkdir -p "$AGENT_LOG_DIR"

# Répertoire de verrous (évite les conflits entre agents sur le même fichier de test)
mkdir -p "$LOCK_DIR"
rm -f "$LOCK_DIR"/*.lock 2>/dev/null

#──────────────────────────────────────────────────────────────────────────────
# INSTALLATION DES DÉPENDANCES DE TEST
#──────────────────────────────────────────────────────────────────────────────
setup_test_deps() {
    log "Vérification des dépendances de test..."
    Rscript -e '
        needed <- c("testthat", "covr", "shinytest2", "chromote",
                     "devtools", "withr", "shiny")
        missing <- needed[!needed %in% installed.packages()[,"Package"]]
        if (length(missing) > 0) {
            cat("📦 Installation :", paste(missing, collapse=", "), "\n")
            install.packages(missing, repos="https://cloud.r-project.org", quiet=TRUE)
        }
        cat("✅ Packages de test OK\n")
    '

    # Créer setup-shinytest2.R si absent
    if [ -d "$PROJECT_DIR/tests/testthat" ] && [ ! -f "$PROJECT_DIR/tests/testthat/setup-shinytest2.R" ]; then
        log "Création de setup-shinytest2.R..."
        cat > "$PROJECT_DIR/tests/testthat/setup-shinytest2.R" << 'EOF'
# Setup shinytest2 pour les tests E2E de l'app Shiny nemeton
library(shinytest2)
EOF
        if git rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
            git add tests/testthat/setup-shinytest2.R 2>/dev/null || true
            git commit -m "chore: add shinytest2 setup file" 2>/dev/null || true
        fi
    fi

    ok "Infrastructure de test prête"
}

#──────────────────────────────────────────────────────────────────────────────
# FONCTIONS DE MESURE DE COUVERTURE
#──────────────────────────────────────────────────────────────────────────────
get_coverage() {
    Rscript -e '
        suppressMessages(library(covr))
        tryCatch({
            cov <- package_coverage(quiet = TRUE)
            cat(sprintf("%.1f", percent_coverage(cov)))
        }, error = function(e) {
            cat("0.0")
        })
    ' 2>/dev/null
}

get_coverage_details() {
    Rscript -e '
        suppressMessages(library(covr))
        tryCatch({
            cov <- package_coverage(quiet = TRUE)
            df <- as.data.frame(cov)
            agg <- aggregate(
                cbind(hit = as.integer(df$value > 0), total = rep(1L, nrow(df))),
                by = list(filename = df$filename), FUN = sum
            )
            agg$pct <- agg$hit / agg$total * 100
            agg <- agg[order(agg$pct), ]
            for (i in seq_len(nrow(agg))) {
                cat(sprintf("  %5.1f%%  %s\n", agg$pct[i], agg$filename[i]))
            }
        }, error = function(e) {
            cat("  Erreur calcul couverture : ", e$message, "\n")
        })
    ' 2>/dev/null
}

# Retourne les N fichiers avec le meilleur ROI (non couverts * taille)
# Format: filename|pct|uncovered_lines  (un par ligne, trié par ROI décroissant)
get_top_uncovered_files() {
    local n="${1:-5}"
    Rscript -e "
        suppressMessages(library(covr))
        tryCatch({
            cov <- package_coverage(quiet = TRUE)
            df <- as.data.frame(cov)
            agg <- aggregate(
                cbind(hit = as.integer(df\$value > 0), total = rep(1L, nrow(df))),
                by = list(filename = df\$filename), FUN = sum
            )
            agg\$pct <- agg\$hit / agg\$total * 100
            agg\$uncovered <- agg\$total - agg\$hit
            # ROI = nombre de lignes non couvertes (max d'impact potentiel)
            agg <- agg[order(-agg\$uncovered), ]
            # Exclure les fichiers déjà à 100%
            agg <- agg[agg\$pct < 100, ]
            n <- min(${n}, nrow(agg))
            if (n > 0) {
                for (i in seq_len(n)) {
                    cat(sprintf('%s|%.1f|%d\n', agg\$filename[i], agg\$pct[i], agg\$uncovered[i]))
                }
            }
        }, error = function(e) {
            cat('')
        })
    " 2>/dev/null
}

# Lignes non couvertes pour UN fichier spécifique
get_zero_coverage_for_file() {
    local target_file="$1"
    Rscript -e "
        suppressMessages(library(covr))
        tryCatch({
            cov <- package_coverage(quiet = TRUE)
            zc <- zero_coverage(cov)
            zc <- zc[zc\$filename == '${target_file}', ]
            if (nrow(zc) > 0) {
                zc <- head(zc, 40)
                for (i in seq_len(nrow(zc))) {
                    cat(sprintf('  L%d: %s\n', zc\$line[i], trimws(zc\$value[i])))
                }
            } else {
                cat('  Toutes les lignes sont couvertes !\n')
            }
        }, error = function(e) {
            cat('  Impossible de calculer zero_coverage\n')
        })
    " 2>/dev/null
}

# Détecter si un fichier contient du code Shiny
is_shiny_file() {
    local file="$1"
    Rscript -e "
        content <- paste(readLines('${file}', warn = FALSE), collapse = '\n')
        is_shiny <- grepl(
            '(moduleServer|renderPlot|renderTable|renderText|renderUI|observeEvent|reactive\\\\(|reactiveVal|shinyApp|fluidPage|navbarPage)',
            content
        )
        cat(ifelse(is_shiny, 'yes', 'no'))
    " 2>/dev/null
}

get_coverage_details_full() {
    Rscript -e '
        suppressMessages(library(covr))
        tryCatch({
            cov <- package_coverage(quiet = TRUE)
            df <- as.data.frame(cov)
            agg <- aggregate(
                cbind(hit = as.integer(df$value > 0), total = rep(1L, nrow(df))),
                by = list(filename = df$filename), FUN = sum
            )
            agg$pct <- agg$hit / agg$total * 100
            agg <- agg[order(agg$pct), ]
            for (i in seq_len(nrow(agg))) {
                cat(sprintf("  %5.1f%%  (%3d/%3d lignes)  %s\n",
                    agg$pct[i], agg$hit[i], agg$total[i], agg$filename[i]))
            }
        }, error = function(e) {
            cat("  Erreur calcul couverture : ", e$message, "\n")
        })
    ' 2>/dev/null
}

#──────────────────────────────────────────────────────────────────────────────
# CONSTRUCTION DU PROMPT PAR AGENT (spécialisé pour UN fichier)
#──────────────────────────────────────────────────────────────────────────────
build_agent_prompt() {
    local target_file="$1"      # ex: R/indicators.R
    local target_basename="$2"  # ex: indicators
    local file_pct="$3"         # ex: 12.5
    local uncovered="$4"        # ex: 87
    local is_shiny="$5"         # yes ou no
    local current_cov="$6"      # couverture globale actuelle
    local all_details="$7"      # couverture par fichier (contexte)

    # Lignes non couvertes pour ce fichier
    local zero_lines
    zero_lines=$(get_zero_coverage_for_file "$target_file")

    # Type de test selon Shiny ou non
    local test_strategy
    if [ "$is_shiny" = "yes" ]; then
        test_strategy="
### Type : MODULE SHINY — DOUBLE APPROCHE

**PRIORITÉ 1 : testServer() (contribue à covr)**
Fichier cible : tests/testthat/test-${target_basename}-server.R
\`\`\`r
test_that(\"mod_xxx_server computes correctly\", {
  testServer(mod_xxx_server, args = list(
    data = reactive(massif_demo_units)
  ), {
    session\\\$setInputs(param1 = \"valeur1\")
    expect_true(!is.null(output\\\$mon_plot))
  })
})
\`\`\`

**PRIORITÉ 2 : shinytest2 AppDriver (E2E, complémentaire)**
Fichier cible : tests/testthat/test-${target_basename}-e2e.R
\`\`\`r
test_that(\"mod_xxx fonctionne en E2E\", {
  skip_on_cran()
  skip_if_not_installed(\"shinytest2\")
  skip_if_not(shinytest2::has_chromote(), \"Chrome/Chromium requis\")
  app <- AppDriver\\\$new(...)
  on.exit(app\\\$stop(), add = TRUE)
  ...
})
\`\`\`"
    else
        test_strategy="
### Type : FICHIER R CLASSIQUE (calcul, utilitaire, normalisation, indicateur)
Fichier cible : tests/testthat/test-${target_basename}.R
- test_that() avec description claire
- Happy path + edge cases + erreurs attendues + NA/NULL
- expect_equal(), expect_error(), expect_warning(), expect_true(), expect_s3_class()
- Pour les fonctions spatiales, crée des objets sf minimaux
- Utilise data(massif_demo_units, package = \"nemeton\") comme fixture quand pertinent"
    fi

    cat <<PROMPT_EOF
Tu es un ingénieur QA expert en R et Shiny, spécialisé dans testthat (edition 3) et shinytest2.
Tu travailles sur le package R "nemeton" — analyse systémique de territoires forestiers.

Le package contient :
- 12 familles d'indicateurs forestiers (C, B, W, A, F, L, T, R, S, P, E, N)
- Des fonctions de calcul, normalisation, Pareto, clustering, trade-offs
- Des visualisations (radar 12-axes, cartes, corrélations)
- Une application Shiny interactive avec modules
- Dépendances spatiales : sf, terra, ggplot2
- Données intégrées : massif_demo_units (20 parcelles, 12 familles)

## Couverture globale actuelle : ${current_cov}%

## Couverture par fichier :
${all_details}

## ═══════════════════════════════════════════════════════
## TA MISSION UNIQUE : COUVRIR ${target_file}
## Couverture actuelle de CE fichier : ${file_pct}%
## Lignes non couvertes : ${uncovered}
## ═══════════════════════════════════════════════════════

## Lignes non couvertes dans ${target_file} :
${zero_lines}
${test_strategy}

## PROCÉDURE STRICTE

### 1. LIS le code source
\`\`\`bash
cat ${target_file}
\`\`\`
Identifie TOUTES les fonctions, leurs paramètres, branches (if/else, switch, tryCatch).

### 2. LIS les tests existants s'il y en a
\`\`\`bash
ls tests/testthat/test-${target_basename}* 2>/dev/null || echo "Pas de tests existants"
\`\`\`
Si des tests existent, AJOUTE ce qui manque plutôt que de tout réécrire.

### 3. ÉCRIS les tests
Cible les lignes non couvertes listées ci-dessus.
Chaque test_that() doit vérifier un comportement réel.

### 4. LANCE UNIQUEMENT tes tests
\`\`\`bash
Rscript -e 'testthat::test_file("tests/testthat/test-${target_basename}.R")'
\`\`\`
Si des tests échouent, corrige-les. Relance jusqu'à ce qu'ils passent.

### 5. VÉRIFIE la non-régression complète
\`\`\`bash
Rscript -e 'devtools::test()'
\`\`\`
TOUS les tests existants doivent passer.

### 6. NE COMMITE PAS — le script principal s'en charge.

## ⛔ RÈGLES STRICTES
1. NE MODIFIE JAMAIS R/, inst/, man/, data/, src/, NAMESPACE
2. DESCRIPTION : modifiable UNIQUEMENT pour ajouter dans Suggests
3. Pas de tests triviaux (expect_true(TRUE)) — chaque test vérifie un comportement réel
4. Tu ne cibles QUE le fichier ${target_file} — ne touche PAS aux tests d'autres fichiers
5. Fichier(s) de test autorisé(s) : tests/testthat/test-${target_basename}*.R
6. Pour les modules Shiny : testServer() en PRIORITÉ (contribue à covr)
7. TOUJOURS on.exit(app\$stop(), add = TRUE) après chaque AppDriver\$new()
8. TOUJOURS skip_on_cran() + skip_if_not_installed("shinytest2") + skip_if_not(has_chromote())
9. Utilise withr::with_tempdir() pour les fichiers temporaires
10. Utilise testthat::local_mocked_bindings() pour mocker les dépendances externes
PROMPT_EOF
}

#──────────────────────────────────────────────────────────────────────────────
# LANCEMENT D'UN AGENT EN ARRIÈRE-PLAN
#──────────────────────────────────────────────────────────────────────────────
launch_agent() {
    local agent_id="$1"
    local prompt="$2"
    local model="${3:-sonnet}"
    local test_basename="${4:-}"
    local agent_log="${AGENT_LOG_DIR}/agent-${agent_id}.log"
    local session_id="nemeton-cov-${agent_id}"
    local lock_file=""

    # Verrouillage par fichier de test (skip si déjà verrouillé par un autre agent)
    if [ -n "$test_basename" ]; then
        lock_file="${LOCK_DIR}/${test_basename}.lock"
        if [ -f "$lock_file" ]; then
            echo -e "  ${YELLOW}🔒 Agent #${agent_id} skip — ${test_basename} déjà verrouillé${NC}"
            return 0
        fi
        echo "$$" > "$lock_file"
    fi

    # Libérer le verrou en fin d'exécution (même en cas d'erreur)
    cleanup_lock() {
        if [ -n "$lock_file" ] && [ -f "$lock_file" ]; then
            rm -f "$lock_file"
        fi
    }
    trap cleanup_lock RETURN

    echo -e "  ${MAGENTA}🤖 Agent #${agent_id}${NC} [${model}] lancé → log: ${agent_log}"

    claude -p "$prompt" \
        --model "$model" \
        --session-id "$session_id" \
        --dangerously-skip-permissions \
        --max-turns "$MAX_TURNS_PER_AGENT" \
        --output-format json \
        > "$agent_log" 2>&1

    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "  ${GREEN}🤖 Agent #${agent_id} terminé avec succès${NC}"
    else
        echo -e "  ${YELLOW}🔄 Agent #${agent_id} échoué (code ${exit_code}) — retry avec --resume...${NC}"
        claude --resume "$session_id" \
            -p "L'exécution précédente a échoué. Continue la mission : corrige les erreurs dans les tests et assure-toi qu'ils passent tous." \
            --model "$model" \
            --dangerously-skip-permissions \
            --max-turns "$MAX_TURNS_PER_AGENT" \
            --output-format json \
            >> "$agent_log" 2>&1

        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo -e "  ${GREEN}🤖 Agent #${agent_id} réussi après retry${NC}"
        else
            echo -e "  ${RED}🤖 Agent #${agent_id} échoué même après retry (code ${exit_code})${NC}"
        fi
    fi
    return $exit_code
}

#──────────────────────────────────────────────────────────────────────────────
# LANCEMENT
#──────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  🌳 NEMETON — Couverture autonome PARALLÈLE (${MAX_PARALLEL} agents)${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo ""

setup_test_deps

# Mesure initiale
log "Mesure de la couverture initiale (peut prendre quelques minutes)..."
current=$(get_coverage)

echo ""
echo -e "  🎯 Objectif             : ${GREEN}${TARGET_COVERAGE}%${NC}"
echo -e "  📊 Couverture actuelle  : ${YELLOW}${current}%${NC}"
echo -e "  🤖 Agents parallèles   : ${CYAN}${MAX_PARALLEL}${NC}"
echo -e "  📁 Projet               : $PROJECT_DIR"
echo -e "  📋 Log principal        : $LOG_FILE"
echo -e "  📂 Logs agents          : $AGENT_LOG_DIR/"
echo ""

echo "$(date '+%Y-%m-%d %H:%M:%S') | DÉBUT | Cible: ${TARGET_COVERAGE}% | Actuel: ${current}% | Agents: ${MAX_PARALLEL}" >> "$LOG_FILE"

iteration=0

while (( $(echo "$current < $TARGET_COVERAGE" | bc -l) )); do
    iteration=$((iteration + 1))

    if [ $iteration -gt $MAX_ITERATIONS ]; then
        warn "Limite de $MAX_ITERATIONS itérations atteinte."
        break
    fi

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  📍 Itération ${CYAN}$iteration${NC} / $MAX_ITERATIONS"
    echo -e "  📊 Couverture : ${YELLOW}${current}%${NC} → cible ${GREEN}${TARGET_COVERAGE}%${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # ── Phase 1 : Collecter les métriques ────────────────────────────────────
    log "Phase 1 : Analyse de la couverture..."
    details=$(get_coverage_details_full)
    echo "$details"
    echo ""

    # ── Phase 2 : Sélectionner les fichiers cibles ──────────────────────────
    log "Phase 2 : Sélection des ${MAX_PARALLEL} fichiers à meilleur ROI..."

    top_files=$(get_top_uncovered_files "$MAX_PARALLEL")

    if [ -z "$top_files" ]; then
        ok "Tous les fichiers sont couverts !"
        break
    fi

    # Afficher les cibles
    agent_count=0
    while IFS='|' read -r fname fpct funcov; do
        agent_count=$((agent_count + 1))
        echo -e "  ${MAGENTA}[$agent_count]${NC} ${fname} — ${fpct}% couvert, ${funcov} lignes non couvertes"
    done <<< "$top_files"
    echo ""

    # ── Phase 3 : Lancer les agents en parallèle ────────────────────────────
    log "Phase 3 : Lancement de ${agent_count} agents Claude en parallèle..."
    echo ""

    declare -a AGENT_PIDS=()
    declare -a AGENT_FILES=()
    agent_idx=0

    while IFS='|' read -r fname fpct funcov; do
        agent_idx=$((agent_idx + 1))

        # Extraire le basename sans extension ni répertoire
        # fname = "R/indicators.R" → basename = "indicators"
        local_basename=$(basename "$fname" .R)

        # Déterminer si c'est un fichier Shiny
        shiny_status=$(is_shiny_file "$fname")

        # Sélection du modèle : sonnet pour Shiny (complexe), haiku pour R pur
        if [ "$shiny_status" = "yes" ]; then
            agent_model="sonnet"
        else
            agent_model="haiku"
        fi

        # Construire le prompt spécialisé
        prompt=$(build_agent_prompt "$fname" "$local_basename" "$fpct" "$funcov" "$shiny_status" "$current" "$details")

        # Lancer l'agent en background
        launch_agent "${iteration}-${agent_idx}-${local_basename}" "$prompt" "$agent_model" "$local_basename" &
        AGENT_PIDS+=($!)
        AGENT_FILES+=("$fname")

    done <<< "$top_files"

    # ── Phase 4 : Attendre tous les agents ───────────────────────────────────
    log "Phase 4 : Attente des ${#AGENT_PIDS[@]} agents..."
    echo ""

    success_count=0
    fail_count=0
    for i in "${!AGENT_PIDS[@]}"; do
        pid=${AGENT_PIDS[$i]}
        fname=${AGENT_FILES[$i]}
        if wait "$pid"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
            warn "Agent pour ${fname} a échoué"
        fi
    done

    echo ""
    ok "${success_count} agents réussis, ${fail_count} échoués"

    # ── Phase 5 : Consolidation (tests + commit) ────────────────────────────
    log "Phase 5 : Vérification globale des tests..."

    test_result=0
    Rscript -e 'devtools::test()' 2>&1 | tail -20 || test_result=$?

    if [ $test_result -ne 0 ]; then
        warn "Des tests échouent après la phase parallèle — lancement d'un agent de réparation..."

        # Agent de réparation : corrige les conflits/erreurs
        REPAIR_PROMPT=$(cat <<REPAIR_EOF
Tu es un ingénieur QA expert en R. Des agents parallèles ont écrit des tests pour le package "nemeton"
mais certains tests échouent.

## TA MISSION : Corriger les tests qui échouent

### 1. Lance les tests pour voir les erreurs
\`\`\`bash
Rscript -e 'devtools::test()'
\`\`\`

### 2. Corrige les fichiers de test qui échouent
- Ne corrige QUE les fichiers dans tests/testthat/
- NE MODIFIE JAMAIS R/, inst/, man/, data/, src/, NAMESPACE
- Si un test est incorrect, corrige-le ou supprime-le
- Vérifie que TOUS les tests passent après correction

### 3. NE COMMITE PAS — le script s'en charge.
REPAIR_EOF
)
        claude -p "$REPAIR_PROMPT" \
            --model sonnet \
            --dangerously-skip-permissions \
            --max-turns 30 \
            --output-format json \
            > "${AGENT_LOG_DIR}/repair-iter-${iteration}.log" 2>&1 || {
                warn "Agent de réparation a échoué"
            }
    fi

    # ── Phase 6 : Mesure et commit ──────────────────────────────────────────
    log "Phase 6 : Mesure de la couverture post-itération..."
    new_coverage=$(get_coverage)
    delta=$(echo "$new_coverage - $current" | bc -l 2>/dev/null || echo "0")

    echo ""
    echo -e "  📊 Résultat itération $iteration (${agent_count} agents) :"
    echo -e "     Avant  : ${YELLOW}${current}%${NC}"
    echo -e "     Après  : ${GREEN}${new_coverage}%${NC}"
    echo -e "     Delta  : ${delta}%"

    echo "$(date '+%Y-%m-%d %H:%M:%S') | Iter $iteration | ${agent_count} agents | ${current}% → ${new_coverage}% (Δ${delta}%)" >> "$LOG_FILE"

    # Commit groupé si progression
    if git rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
        changed_files=$(git diff --name-only tests/ 2>/dev/null || true)
        new_files=$(git ls-files --others --exclude-standard tests/ 2>/dev/null || true)
        if [ -n "$changed_files" ] || [ -n "$new_files" ]; then
            git add tests/
            # Lister les fichiers ciblés pour le message de commit
            targets_list=$(echo "$top_files" | cut -d'|' -f1 | xargs -I{} basename {} .R | paste -sd ', ')
            git commit -m "test: add coverage for ${targets_list} — ${current}% → ${new_coverage}% (${agent_count} parallel agents)" || true
            ok "Commit effectué"
        fi
    fi

    # Détection de stagnation
    if (( $(echo "${delta#-} <= 0.5" | bc -l) )); then
        STAGNATION_COUNT=$((STAGNATION_COUNT + 1))
        warn "Stagnation $STAGNATION_COUNT/$MAX_STAGNATION (delta ${delta}%)"
        if [ $STAGNATION_COUNT -ge $MAX_STAGNATION ]; then
            log "Stagnation prolongée — augmentation du nombre d'agents à $((MAX_PARALLEL + 2))"
            MAX_PARALLEL=$((MAX_PARALLEL + 2))
            STAGNATION_COUNT=0
        fi
    else
        STAGNATION_COUNT=0
        ok "Progression de ${delta}% !"
    fi

    current="$new_coverage"
    sleep "$SLEEP_BETWEEN"
done

#──────────────────────────────────────────────────────────────────────────────
# RÉSUMÉ FINAL
#──────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
if (( $(echo "$current >= $TARGET_COVERAGE" | bc -l) )); then
    echo -e "  ${GREEN}🎉 OBJECTIF ATTEINT !${NC}"
else
    echo -e "  ${YELLOW}⚠️  Objectif non atteint après $iteration itérations${NC}"
fi
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  📊 Couverture finale : ${GREEN}${current}%${NC}"
echo -e "  🎯 Objectif          : ${TARGET_COVERAGE}%"
echo -e "  🔄 Itérations        : $iteration"
echo -e "  🤖 Mode              : parallèle (${MAX_PARALLEL} agents/iter)"
echo -e "  🌿 Branche           : $BRANCH_NAME"
echo ""
echo "  📋 Couverture finale par fichier :"
get_coverage_details_full
echo ""
echo "  📂 Logs des agents : ${AGENT_LOG_DIR}/"
echo ""
echo "  👉 Prochaines étapes :"
echo "     1. Reviewez les tests :"
echo "        git diff main..${BRANCH_NAME} --stat"
echo "        Rscript -e 'devtools::test()'"
echo "     2. Vérifiez la qualité :"
echo "        Rscript -e 'covr::report(covr::package_coverage())'"
echo "     3. Mergez si satisfait :"
echo "        git checkout main && git merge ${BRANCH_NAME}"
echo ""
echo "$(date '+%Y-%m-%d %H:%M:%S') | FIN | ${current}% | $iteration itérations | mode parallèle" >> "$LOG_FILE"
