# nemeton-authored glue (not vendored from RECONFORT). MIT, with the rest
# of the nemeton R package. Driven by R/reconfort_ingest.R.
#
# Download ONE Sentinel-2 archive, reconstructed from the STAC JSON that
# list_s2_items.py persisted (no re-search). Writing the archive to an
# explicit -outfile lets the R driver place it on a scratch path it then
# extracts, crops to the AOI, and deletes — capping peak disk at ~one
# archive (spec 021, crop-at-ingestion).
#
from argparse import RawTextHelpFormatter
import argparse
import json
from pygeodes import Geodes, Config
from pygeodes.utils.stac import Item

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Download a single GEODES Sentinel-2 archive from its STAC "
                    "JSON (as written by list_s2_items.py).",
        formatter_class=RawTextHelpFormatter,
    )
    parser.add_argument("-account", dest="account", required=True,
                        help="pygeodes account config (api_key, download_dir).")
    parser.add_argument("-item_json", dest="item_json", required=True,
                        help="Path to the item's STAC JSON.")
    parser.add_argument("-outfile", dest="outfile", required=True,
                        help="Destination .zip path for the archive.")
    args = parser.parse_args()

    conf = Config.from_file(args.account)
    geodes = Geodes(conf=conf)

    with open(args.item_json) as fh:
        item = Item.from_dict(json.load(fh))

    geodes.download_item_archive(item, outfile=args.outfile)
    print("downloaded", args.outfile)
