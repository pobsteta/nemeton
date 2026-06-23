# Vendored from RECONFORT (fl.mouret/reconfort, main 25198c9).
# License: Apache-2.0 (see inst/NOTICE). Driven by run_map_production_reconfort.py.
#
import argparse
import os
import sys
from string import Template


def generate_cfg(label_year, S2_year, out_dir_cfg, out_dir_files, S2_path, ground_truth_path, list_tiles, number_of_chunks, v_model, scheduler_type):

    if v_model == 'v3'or v_model == 'v3_chestnut' or v_model == 'v3_pine':
        sdate = '0101'
        edate = '1029'
    elif v_model == 'v3_early_may':
        sdate = '0101'
        edate = '0531'
    else:
        raise ValueError("Wrong model and/or model not implemented. Choose : v3 or v3_early_may")

    # for the TREX HPC, you need to specifiy your account (i.e., related to your project)
    if scheduler_type == "Slurm":
        slurm_txt = "slurm:{account:'reconfort'}"
    else:
        slurm_txt = ""

    with open(out_dir_cfg + 'config_Labels_classif_part1_' + label_year +'_year_' + S2_year + '_2y_nov.cfg', 'w') as f:
        d = {'label_year': label_year, 
             'S2_year': S2_year, 
             'out_dir_files': out_dir_files, 
             'S2_path': S2_path, 
             'ground_truth_path': ground_truth_path,
             'list_tiles': list_tiles,
             'number_of_chunks': number_of_chunks,
             'slurm_txt': slurm_txt,
             'S2_start': str(int(S2_year)-1) + sdate, 'S2_end': S2_year + edate}  # dictionary with label year / S2 year
        s = Template("""chain :
{
    output_path : '$out_dir_files/iota2_results_classif_labels-$label_year-S2_$S2_year/'
    remove_output_path : True
    check_inputs : False
    list_tile : $list_tiles
    data_field : 'dep_cor'
    s2_path : '$S2_path/$S2_year/'
    ground_truth : '$ground_truth_path'
    spatial_resolution : 10
    color_table : 'iota2/colorFile.txt'
    nomenclature_path : 'iota2/nomenclature.txt'
    first_step : 'init'
    last_step : 'learning'
    proj : 'EPSG:2154'
}

Sentinel_2 :
{
    start_date : '$S2_start'
    end_date : '$S2_end'
    keep_bands : []
}

                
arg_train :
{
    runs : 1
    classifier : 'sharkrf'
    otb_classifier_options : {'classifier.sharkrf.nodesize': 25}
    features_from_raw_dates : False
    features : []
    split_ground_truth : False
    sample_selection :
        {
            sampler : 'periodic'
            strategy : 'percent'
            'strategy.percent.p' : 0.1
        }
}

arg_classification:
{
    enable_probability_map:True
    generate_final_probability_map:True  
}

sensors_data_interpolation :
{
  auto_date : False
}



#scikit_models_parameters:
#{
#    model_type: "RandomForestClassifier"
#    n_estimators: 10
#    class_weight: 'balanced'
#    max_depth : 15
#    n_jobs : -1
#}

external_features:
{
    module:"iota2/external_features/custom_index.py"
    functions: "get_crswir get_crre"
    concat_mode: False
}

builders:
{
    builders_class_name: ["I2Classification"]  # nemeton: iota2 class is I2Classification (CamelCase), not the module name
}

python_data_managing:
{
    chunk_size_mode:"split_number"
    number_of_chunks: $number_of_chunks
}

$slurm_txt
                
task_retry_limits:
{
    allowed_retry : 1
    maximum_ram : 20.0
    maximum_cpu : 24
}
        """)
        s = s.safe_substitute(d)
        f.write(s)


# def main():
#     parser = argparse.ArgumentParser(description="This function allow you to"
#                                                  " generate a cfg file base on label year"
#                                                  " and S2 data year"
#                                      )

#     parser.add_argument("-label_year",
#                         dest="label_year",
#                         help="Year of the labeled samples",
#                         required=True)
#     parser.add_argument("-S2_year",
#                         dest="S2_year",
#                         help="Year of the S2 images",
#                         required=True)

#     parser.add_argument("-out_dir_cfg",
#                         dest="out_dir_cfg",
#                         help="Out dir to save cfg file",
#                         required=True)

#     parser.add_argument("-out_dir_files",
#                         dest="out_dir",
#                         help="Out dir to save produced file",
#                         required=True)

#     parser.add_argument("-S2_path",
#                         dest="S2_path",
#                         help="Path to S2 data",
#                         required=True)

#     parser.add_argument("-ground_truth_path",
#                         dest="ground_truth_path",
#                         help="Path to ground_truth",
#                         required=True)

#     args = parser.parse_args()

#     generate_cfg(args.label_year, args.S2_year, args.out_dir_cfg, args.out_dir_files, args.S2_path, args.ground_truth_path)


# if __name__ == '__main__':
#     sys.exit(main())