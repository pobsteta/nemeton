#!/usr/bin/env bash
# repair_iota2_env.sh — make a freshly-built RECONFORT conda env runnable.
#
# The `iota2` conda package (channels `iota2` + `iota2-deps`) ships two defects
# that break the RECONFORT chain out of the box on a current install:
#
#   #9  iota2 calls `pandas.to_datetime(..., infer_datetime_format=...)`, an
#       argument removed in pandas 3.0 — `mamba install iota2` pulls the latest
#       pandas (3.x), so I2TemporalLabel construction crashes. Pin pandas < 3.
#   #10 iota2's per-step launcher is shipped as the module
#       `iota2/task_launcher.py` but NOT exposed as a console script, while
#       `iota2_step.py` invokes it as a bare command `task_launcher.py`. The
#       dask workers then fail with `/bin/sh: task_launcher.py: not found`.
#       Add a thin executable wrapper on the env PATH.
#
# Idempotent. Run once after creating the env:
#   conda create -n nemeton-reconfort python=3.11 mamba
#   mamba install -n nemeton-reconfort iota2 -c iota2 -c iota2-deps
#   pip install pygeodes
#   bash repair_iota2_env.sh nemeton-reconfort
#
# Usage: repair_iota2_env.sh [ENV_NAME]   (default: nemeton-reconfort)
set -euo pipefail

ENV_NAME="${1:-${NEMETON_RECONFORT_ENV:-nemeton-reconfort}}"
CONDA="$(command -v conda || echo "$HOME/miniforge3/bin/conda")"
# The iota2 env prints an "**** OTB environment setup complete ****" banner on
# activation; strip it (and blank lines) from every captured `conda run` value.
clean() { grep -vE '^\*\*\*\*|^[[:space:]]*$' | tail -1; }
ENV_PREFIX="$("$CONDA" run -n "$ENV_NAME" python -c 'import sys,os;print(os.path.dirname(os.path.dirname(sys.executable)))' | clean)"

echo "[repair] env: $ENV_NAME ($ENV_PREFIX)"

# --- #9 pandas < 3 -------------------------------------------------------
PD_MAJOR="$("$CONDA" run -n "$ENV_NAME" python -c 'import pandas;print(pandas.__version__.split(".")[0])' 2>/dev/null | clean || echo 0)"
if [ "${PD_MAJOR:-0}" -ge 3 ]; then
  echo "[repair] pandas $PD_MAJOR.x → downgrading to <3 (#9)"
  MAMBA="$(command -v mamba || echo "$HOME/miniforge3/bin/mamba")"
  "$MAMBA" install -n "$ENV_NAME" -y -c conda-forge "pandas<3" >/dev/null
else
  echo "[repair] pandas already <3 (ok)"
fi

# --- #10 task_launcher.py on PATH ---------------------------------------
LAUNCHER_BIN="$ENV_PREFIX/bin/task_launcher.py"
LAUNCHER_MOD="$(find "$ENV_PREFIX"/lib/python*/site-packages/iota2 -maxdepth 1 -name task_launcher.py | head -1)"
if [ -x "$LAUNCHER_BIN" ]; then
  echo "[repair] task_launcher.py already on PATH (ok)"
elif [ -n "$LAUNCHER_MOD" ]; then
  echo "[repair] creating task_launcher.py wrapper in bin/ (#10)"
  cat > "$LAUNCHER_BIN" <<WRAP
#!/bin/sh
exec "$ENV_PREFIX/bin/python" "$LAUNCHER_MOD" "\$@"
WRAP
  chmod +x "$LAUNCHER_BIN"
else
  echo "[repair] WARNING: iota2/task_launcher.py not found — check the iota2 install" >&2
fi

echo "[repair] done."
