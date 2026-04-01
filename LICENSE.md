# Néméton — Licensing (ADR-006)

## Dual License Structure

This package uses a dual-license model as defined in ADR-006:

| Component | License | Scope |
|-----------|---------|-------|
| **Business logic** | MIT | Indicators, NDP, families, normalization, visualization |
| **Application** | EUPL v1.2 | Shiny modules, UI, server, services, LLM prompts |
| **Produced data** | CC-BY 4.0 | Indicator values, species maps, reports, exports |

## MIT — Business Logic

Reusable in any context (commercial, academic, institutional) without restriction.

**Files:** `R/indicators-*.R`, `R/ndp.R`, `R/family-system.R`, `R/normalization.R`, `R/visualization.R`, `R/nemeton-class.R`, `R/species-config.R`, `R/datasources.R`, `R/data*.R`, `R/analysis-*.R`

See [LICENSE-MIT.md](LICENSE-MIT.md) for full text.

## EUPL v1.2 — Application Layer

Copyleft: improvements to the application must be shared back. Available in 23 EU languages.

**Files:** `R/mod_*.R`, `R/app_*.R`, `R/service_*.R`, `R/run_app.R`, `R/llm_prompts.R`, `inst/quarto/`, `inst/experts/`, `inst/app/`, `inst/sql/`

See [LICENSE-EUPL.md](LICENSE-EUPL.md) for full text.

## CC-BY 4.0 — Produced Data

Attribution required. Compatible with Licence Ouverte 2.0 (Etalab).

**Scope:** All data produced by Néméton (indicator values, species classifications, GeoPackage exports, PDF reports).

See [LICENSE-DATA.md](LICENSE-DATA.md) for full text.

## Copyright

Copyright (c) 2026 Pascal Obstétar
