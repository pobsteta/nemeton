# Vendored verbatim from RECONFORT (fl.mouret/reconfort, main 25198c9).
# License: Apache-2.0 (see inst/NOTICE). Driven by R/reconfort_ingest.R.
#
from argparse import RawTextHelpFormatter
import argparse
from utils.utils import load_config_variable
import glob
import zipfile
import os
import rasterio
from rasterio.warp import calculate_default_transform, reproject, Resampling
import shutil
import tempfile


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="This routine download S2 images using the theia_download package "
                    "(see https://github.com/olivierhagolle/theia_download )",
        formatter_class=RawTextHelpFormatter
    )
    parser.add_argument(
        "-config_file",
        dest="config_file",
        help=
        "Config file with mandatory variables for theia_download\n"
        "You can create an account here : You can create a theia account https://www.theia-land.fr \n"
        "EXAMPLE OF CFG FILE: \n \n"
        "tile='T31TCJ' # tile to be downloaded \n"
        "path_to_cfg_theia_account='/media/florian/config_theia.cfg' # theia account information \n"
        "start='2018-10-15'  # Start date \n"
        "end='2018-12-15'  # End date' \n"
        "zip_path='/data/S2_data/zip/T31UEQ' # path to download the data \n"
        "out_dir='/data/S2_data/2022/T31UEQ' # path to extract the data \n"
        ,
        required=True
    )
    args = parser.parse_args()
    config_file = args.config_file

    dict_config = load_config_variable(config_file)
    print('list of user variables')
    print(dict_config)

    list_S2_zipfiles = glob.glob(dict_config['zip_path'] + "/SENTINEL*D.zip")
    list_S2_folder = []

    if not os.path.exists(dict_config['out_dir']):
        os.makedirs(dict_config['out_dir'])

    for S2_zip in list_S2_zipfiles:
        print("extracting", S2_zip)
        temp_zip = zipfile.ZipFile(S2_zip)
        temp_zip.extractall(dict_config['out_dir'])  # command to extract zip in specified folder

        # to save space, we remove all SRE file which are not used:
        new_list_S2_folders = glob.glob(dict_config['out_dir'] + '/*/')  # with /*/ we select only the folders !
        new_folder = set(new_list_S2_folders) - set(list_S2_folder)
        for S2_img in new_folder:
            list_SRE_img = glob.glob(S2_img + '*SRE_*' + '.tif')
            for SRE_img in list_SRE_img:
                os.remove(SRE_img)

        list_S2_folder = new_list_S2_folders

    # reproject images to Lambert-93

    # Set the target EPSG code for Lambert-93
    # TARGET_EPSG = 2154
    #
    # # Directory containing Sentinel-2 TIFF images
    # # input_dir = glob.glob(dict_config['out_dir'] + '/*/')
    # #
    # # # List all TIFF files in the input directory
    # # tiff_files = [f for f in os.listdir(input_dir) if f.endswith(".tif")]
    #
    # tiff_files = glob.glob(dict_config['out_dir'] + '/*/*.tif')
    # tiff_files_mask = glob.glob(dict_config['out_dir'] + '/*/*/*.tif')
    #
    # tiff_files = tiff_files + tiff_files_mask
    #
    # for tiff_file in tiff_files:
    #
    #     # Open the input TIFF image
    #     with rasterio.open(tiff_file) as src:
    #         num_bands = src.count
    #         # Get the transform, width, and height for the output image
    #         transform, width, height = calculate_default_transform(
    #             src.crs, f"EPSG:{TARGET_EPSG}", src.width, src.height, *src.bounds
    #         )
    #
    #         # Create a temporary file to hold the reprojected data
    #         with tempfile.NamedTemporaryFile(delete=False, suffix=".tif") as temp_file:
    #             temp_file_path = temp_file.name
    #             # Write the reprojected data to the temporary file
    #             with rasterio.open(
    #                     temp_file_path,
    #                     "w",
    #                     driver="GTiff",
    #                     crs=f"EPSG:{TARGET_EPSG}",
    #                     transform=transform,
    #                     count=num_bands,  # Specify the band count
    #                     width=width,
    #                     height=height,
    #                     dtype=src.dtypes[0],  # Use the same data type as the source image
    #             ) as temp_dst:
    #                 for i in range(1, src.count + 1):
    #                     reproject(
    #                         source=rasterio.band(src, i),
    #                         destination=rasterio.band(temp_dst, i),
    #                         src_transform=src.transform,
    #                         src_crs=src.crs,
    #                         dst_transform=transform,
    #                         dst_crs=f"EPSG:{TARGET_EPSG}",
    #                         resampling=Resampling.nearest,
    #                     )
    #
    #     # Replace the original file with the reprojected data
    #     shutil.move(temp_file_path, tiff_file)
    #
    #     print(f"Reprojected and saved inplace: {tiff_file}")
