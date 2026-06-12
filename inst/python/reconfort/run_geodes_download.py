# Vendored verbatim from RECONFORT (fl.mouret/reconfort, main 25198c9).
# License: Apache-2.0 (see inst/NOTICE). Driven by R/reconfort_ingest.R.
#
from pygeodes import Geodes
from pygeodes import Config
from pygeodes.utils.datetime_utils import complete_datetime_from_str
from argparse import RawTextHelpFormatter
import argparse
from utils.utils import load_config_variable

if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="This routine download S2 images using the geodes package "
                    "(see  https://cnes.github.io/pyGeodes/index.html)",
        formatter_class=RawTextHelpFormatter
    )
    parser.add_argument(
        "-config_file",
        dest="config_file",
        help=
        "Config file with mandatory variables for theia_download\n"
        "You can create an account here : You can create a geodes account https://geodes-portal.cnes.fr/ \n"
        "EXAMPLE OF CFG FILE: \n \n"
        "tile='31TCJ' # tile to be downloaded, try with or without initial T: T31TCJ or 31TCJ\n"
        "path_to_cfg_geodes_account='~/PROGRAMS/RECONFORT_src/reconfort/pygeodes-config.json' # gepdes account information \n"
        "s2_collection = 'MUSCATE_SENTINEL2_SENTINEL2_L2A' #Sentinel 2 images Level 2 \n"
        "start='2018-10-15'  # Start date \n"
        "end='2018-12-15'  # End date' \n"
        "zip_path='/data/S2_data/zip/year/' # path to download the data \n"
        "out_dir='/data/S2_data/extracted/year/' # path to download the data \n"
        ,
        required=True
    )
    args = parser.parse_args()
    config_file = args.config_file

    dict_config = load_config_variable(config_file)
    print('list of user variables')
    print(dict_config)

    conf = Config.from_file(dict_config['path_to_cfg_geodes_account'])
    geodes = Geodes(conf=conf)

    #Example:
    #s2_collection = "MUSCATE_SENTINEL2_SENTINEL2_L2A"
    #start_date="2024-11-05"
    #end_date="2024-11-10"
    # "grid:code": {"in": ["31TCJ", "T31TCJ"]},

    query = {
        "grid:code": {"in": dict_config['tile']},
        "start_datetime": {"gte": complete_datetime_from_str(dict_config['start'])},
        "end_datetime": {"lte": complete_datetime_from_str(dict_config['end'])},
    }

    items, df = geodes.search_items(query=query, get_all=True, collections=[dict_config['s2_collection']])

    for item in items:
        try:
            geodes.download_item_archive(item)

        except:
            print("Error downloading image")

