# Vendored from RECONFORT (see ../PATCHES.md), modified by nemeton:
# load_config_variable() no longer eval()s the cfg values (code injection
# through any value written in the cfg). Values are parsed as JSON (format
# written by nemeton's .reconfort_write_cfg), with a fallback to
# ast.literal_eval for hand-written upstream cfg files using Python literals.
import ast
import json


def _parse_value(raw):
    # JSON d'abord (format écrit par nemeton), puis littéral Python inerte
    # (cfg amont écrits à la main) ; jamais eval().
    try:
        return json.loads(raw)
    except ValueError:
        return ast.literal_eval(raw)


def load_config_variable(path_to_cfg):
    data = {}
    with open(path_to_cfg, "r") as file:
        # Read each line and parse it (no code evaluation) into the dictionary
        for line in file:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, value = line.split("=", 1)
            data[key.strip()] = _parse_value(value.strip())
    return data
