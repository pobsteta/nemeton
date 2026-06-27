# nemeton-authored glue (not vendored from RECONFORT). MIT, with the rest
# of the nemeton R package. Driven by R/reconfort_ingest.R.
#
# One GEODES search for a tile + date range, persisting every matching STAC
# item to its own JSON file and a manifest. This lets the R driver download
# the archives ONE AT A TIME (reloading each item's JSON, no re-search), so
# it can extract+crop+delete each scene before fetching the next — keeping
# peak disk near a single archive instead of the whole tile (spec 021,
# crop-at-ingestion).
#
from argparse import RawTextHelpFormatter
import argparse
import json
import os
from pygeodes import Geodes, Config
from pygeodes.utils.datetime_utils import complete_datetime_from_str
from utils.utils import load_config_variable

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="List (do not download) the Sentinel-2 L2A items matching a "
                    "tile + date range on GEODES, writing one STAC JSON per item "
                    "plus a manifest.json for the R driver.",
        formatter_class=RawTextHelpFormatter,
    )
    parser.add_argument(
        "-config_file", dest="config_file", required=True,
        help="Same cfg as run_geodes_download.py, plus a 'manifest_dir' key "
             "(where the per-item JSONs and manifest.json are written).",
    )
    args = parser.parse_args()

    dict_config = load_config_variable(args.config_file)
    print("list of user variables")
    print(dict_config)

    manifest_dir = dict_config["manifest_dir"]
    os.makedirs(manifest_dir, exist_ok=True)

    conf = Config.from_file(dict_config["path_to_cfg_geodes_account"])
    geodes = Geodes(conf=conf)

    query = {
        "grid:code": {"in": dict_config["tile"]},
        "start_datetime": {"gte": complete_datetime_from_str(dict_config["start"])},
        "end_datetime": {"lte": complete_datetime_from_str(dict_config["end"])},
    }

    items, _df = geodes.search_items(
        query=query, get_all=True,
        collections=[dict_config["s2_collection"]], quiet=True)

    manifest = []
    for idx, item in enumerate(items):
        d = item.to_dict()
        item_id = d.get("id", "item_%05d" % idx)
        # Filesystem-safe key from the item id (URN contains ':').
        safe = "".join(c if (c.isalnum() or c in "-_.") else "_" for c in item_id)
        json_path = os.path.join(manifest_dir, "%05d_%s.json" % (idx, safe))
        with open(json_path, "w") as fh:
            json.dump(d, fh)
        try:
            dt = str(item.get_datetime())
        except Exception:
            dt = d.get("properties", {}).get("datetime")
        try:
            filesize = int(item.filesize)
        except Exception:
            filesize = None
        manifest.append({
            "idx": idx,
            "item_id": item_id,
            "datetime": dt,
            "filesize": filesize,
            "json": json_path,
        })

    manifest_path = os.path.join(manifest_dir, "manifest.json")
    with open(manifest_path, "w") as fh:
        json.dump(manifest, fh, indent=1)
    print("wrote", len(manifest), "items to", manifest_path)
