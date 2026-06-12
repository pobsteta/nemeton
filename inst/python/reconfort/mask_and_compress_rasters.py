# Vendored from RECONFORT (fl.mouret/reconfort, main 25198c9).
# License: Apache-2.0 (see inst/NOTICE). Driven by run_map_production_reconfort.py.
#
from rasterio.windows import from_bounds
import rasterio
import os
from utils.utils import load_config_variable
import numpy as np

def mask_rasters(src, src_mask, out_dir, selected_dtype):

    if selected_dtype == 'uint8':
        dtype = rasterio.uint8
    elif selected_dtype == 'int16':
        dtype = rasterio.int16
    else:
        raise ValueError('Wrong dtype, should be "uint8" or "int16"')

    map = rasterio.open(src)
    mask = rasterio.open(src_mask)

    n_bands = map.count
    data_map = map.read()
    window = rasterio.windows.from_bounds(*map.bounds, transform=mask.transform)
    data_mask = mask.read(1, window=window, boundless=True)
    data_map[:, data_mask == 0] = 0
    print('compressing', src)
    # Register GDAL format drivers and configuration options with a
    # context manager.
    with rasterio.Env():
        # Write an array as a raster band to a new 8-bit file. For
        # the new file's profile, we start with the profile of the source
        profile = map.profile
        # And then change the band count to 1, set the
        profile.update(
            dtype=dtype,
            count=n_bands,
            compress='lzw')
        with rasterio.open(out_dir, 'w', **profile) as dst:
            # dst.write(data_mask.astype(dtype), 1)
            for i in range(n_bands):
                dst.write(data_map[i, :, :], i + 1)


def compute_continuous_score(src, out_dir, selected_dtype):

    if selected_dtype == 'uint8':
        dtype = rasterio.uint8
    elif selected_dtype == 'int16':
        dtype = rasterio.int16
    else:
        raise ValueError('Wrong dtype, should be "uint8" or "int16"')

    map = rasterio.open(src)

    n_bands = 1
    data_map = map.read()
    # window = rasterio.windows.from_bounds(*map.bounds, transform=mask.transform)

    # assuming a 3 bands raster score = (1001 - sum probas each class) / 30
    # the score range between 1 (healthy) and 100 (very declining)
    # values = 0 is no data

    sum_proba = - data_map[0, :, :] + data_map[1, :, :] + 2 * data_map[2, :, :]

    continuous_score = 1001 + sum_proba
    continuous_score = continuous_score / 30
    continuous_score = np.where(continuous_score == 0, 1, continuous_score)
    continuous_score[sum_proba == 0] = 0
    # continuous_score = data_mask * continuous_score

    # Register GDAL format drivers and configuration options with a
    # context manager.
    with rasterio.Env():
        # Write an array as a raster band to a new 8-bit file. For
        # the new file's profile, we start with the profile of the source
        profile = map.profile
        # And then change the band count to 1, set the
        profile.update(
            dtype=dtype,
            count=n_bands,
            compress='lzw')

        print('ok')
        with rasterio.open(out_dir, 'w', **profile) as dst:
            # dst.write(data_mask.astype(dtype), 1)
            for i in range(n_bands):
                dst.write(continuous_score, 1)


if __name__ == "__main__":

    new_root = os.path.dirname(os.path.abspath(__file__))
    os.chdir(new_root)
    print('root of the project', new_root)

    # SOME INTERNAL VARIABLES
    label_year = "2020"  # not used, only for generating the cfg files
    # we used some random points, 1 of each class per tile, to be able to use iota2.
    ground_truth_path = 'iota2/vector_db/random_points.shp'
    # ///
    out_dir_files = new_root + '/results'

    # SOME USER VARIABLES - see config_file.cfg
    dict_config = load_config_variable('config_file.cfg')
    print('list of user variables')
    print(dict_config)

    v_model = dict_config['v_model']
    path_model = new_root + '/models/' + v_model + '/'
    S2_year = dict_config["S2_year"]
    S2_path = dict_config["S2_path"]
    list_tiles = dict_config['list_tiles']
    n_chunks = dict_config['number_of_chunks']

    dir_final_classif = out_dir_files + '/iota2_results_classif_labels-' + label_year + '-S2_' + S2_year + '/final/'

    # mask classif map
    src = dir_final_classif + 'Classif_Seed_0.tif'
    if len(dict_config['path_to_binary_mask']) < 4:
        print('Using available deciduous tree mask from OSO')
        src_mask = 'masks/mask_oso_deciduous_compress.tif'
    else:
        print('Using custom mask')
        src_mask = dict_config['path_to_binary_mask']
    out_dir = dir_final_classif + 'Final_Classif_masked_' + S2_year + '.tif'
    mask_rasters(src, src_mask, out_dir, 'uint8')

    # mask proba maps
    src = dir_final_classif + 'ProbabilityMap_seed_0.tif'
    src_mask = 'masks/mask_oso_deciduous_compress.tif'
    out_dir = dir_final_classif + 'Final_Proba_map_masked' + S2_year + '.tif'
    mask_rasters(src, src_mask, out_dir, 'int16')

    # mask proba maps and compute continues score
    src = dir_final_classif + 'Final_Proba_map_masked' + S2_year + '.tif'
    out_dir = dir_final_classif + 'Final_continuous_score_masked' + S2_year + '.tif'
    compute_continuous_score(src, out_dir, 'int16')