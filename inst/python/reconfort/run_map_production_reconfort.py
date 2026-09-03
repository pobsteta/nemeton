# Vendored from RECONFORT (fl.mouret/reconfort, main 25198c9).
# License: Apache-2.0 (see inst/NOTICE). Driven by R/reconfort_pipeline.R.
#
from utils.generate_cfg_file_classif_part1_sampling_2y_nov_test_1tile import generate_cfg as generate_cfg_part1
from utils.generate_cfg_file_classif_part2_classification_2y_nov_test_1tile import generate_cfg as generate_cfg_part2
import os
import shutil
import sys
import iota2.Iota2 as Iota2
import subprocess
from utils.utils import load_config_variable
from mask_and_compress_rasters import mask_rasters, compute_continuous_score
import argparse
from argparse import RawTextHelpFormatter

if __name__ == "__main__":

	parser = argparse.ArgumentParser(
		description="This routine produces a dieback map using a config .cfg file provided by the user",
		formatter_class=RawTextHelpFormatter
	)
	parser.add_argument(
		"-config_file",
		dest="config_file",
		help=
		"Config file with mandatory variables \n"
		"EXAMPLE OF CFG FILE: \n \n"
		"label='default_classif' # name used to identify your results"
		"S2_year='2022' # last year of the S2 data, 2 years needed, e.g., 2021 & 2022 \n"
		"S2_path='/media/florian/data/data_S2' \n"
		"number_of_chunks='200'  # images are processed in small chunk to save RAM \n"
		"list_tiles='T31UCP'  # eg, 'T31UDP T31TDN T30TYT' \n"
		"v_model='v3' # v3 or v3_early_may available, see folder models \n"
		"mask_final_maps='True' # True (mask the final maps according to a binary mask, e.g., oak / not oaks) \n"
		"path_to_binary_mask='' # If empty (''), we use OSO deciduous tree mask (2021) \n"
		"scheduler_type='LocalCluster' # Choose Slurm (or other) if you work on a HPC \n"
		"nb_parallel_tasks='1'"
		,
		required=True
	)
	args = parser.parse_args()
	config_file = args.config_file

	new_root = os.path.dirname(os.path.abspath(__file__))
	os.chdir(new_root)
	print('root of the project', new_root)
	
	# SOME INTERNAL VARIABLES
	# we used some random points, 1 of each class per tile, to be able to use iota2.
	ground_truth_path = 'iota2/vector_db/random_points.shp'
	# ///
	out_dir_files = new_root + '/results'

	# SOME USER VARIABLES - see config_file.cfg
	dict_config = load_config_variable(config_file)
	print('list of user variables')
	print(dict_config)

	v_model = dict_config['v_model']
	path_model = new_root + '/models/' + v_model + '/'
	S2_year = dict_config["S2_year"]
	S2_path = dict_config["S2_path"]
	list_tiles = dict_config['list_tiles']

	# add quote to avoid problems with iota2
	if list_tiles[0] != "'":
		list_tiles = "'" + list_tiles + "'"

	n_chunks = dict_config['number_of_chunks']

	try:
		scheduler_type = dict_config['scheduler_type']
	except:
		scheduler_type = 'localCluster'

	try:
		nb_parallel_tasks = dict_config['nb_parallel_tasks']
	except:
		nb_parallel_tasks = '1'

	label_year = dict_config['label']  # not used, only for generating the cfg files
	# /////////////////////////////////
	# IOTA2 FOR MAP PRODUCTION
	# create cfg file part 1 and part 2

	# if v_model == "v3_early_may":
	# 	raise ValueError("early model is not working yet, please use v3 for now")

	# PART 1 CFG
	generate_cfg_part1(
		label_year,
		S2_year,
		out_dir_cfg='generated_config_files/',
		out_dir_files=out_dir_files,
		S2_path=S2_path,
		ground_truth_path=ground_truth_path,
		list_tiles=list_tiles,
		number_of_chunks=n_chunks,
		v_model=v_model,
		scheduler_type=scheduler_type,
	)

	# PART 2 CFG
	generate_cfg_part2(
		label_year,
		S2_year,
		out_dir_cfg='generated_config_files/',
		out_dir_files=out_dir_files,
		S2_path=S2_path,
		ground_truth_path=ground_truth_path,
		list_tiles=list_tiles,
		number_of_chunks=n_chunks,
		v_model=v_model,
		scheduler_type=scheduler_type,
	)

	# nemeton: neither `subprocess.run` below checked its return code. An IOTA2
	# chain that died therefore went unnoticed here, the script carried on to the
	# masking step, and the first visible error was a missing
	# `final/Classif_Seed_0.tif` — a symptom three steps downstream of the cause.
	# Combined with the child's output going to /dev/null under a future worker,
	# that left a 20-hour run with no diagnosis at all (Couchey, 2026-09-03).
	def run_iota2(part, argv):
		completed = subprocess.run(argv)
		if completed.returncode != 0:
			print(
				f"ERROR: IOTA2 {part} exited with code {completed.returncode}. "
				"See IOTA2_tasks_status.txt and logs/ in the results dir.",
				file=sys.stderr,
			)
			sys.exit(completed.returncode)
		return completed

	# run iota2 part 1
	command_path = shutil.which('Iota2.py')
	print(command_path)
	run_iota2("part 1 (sampling)", [
		"python", command_path,
		'-config', 'generated_config_files/config_Labels_classif_part1_' + label_year + '_year_' + S2_year + '_2y_nov.cfg',
		'-config_ressources', 'iota2/config/iota2_resources.cfg',
		'-nb_parallel_tasks', nb_parallel_tasks,
		# '-starting_step', 0,
		'-ending_step', '7',
		'-restart',
		'-scheduler_type', scheduler_type
	])

	# run iota2 part 2
	# copy custom model in iota2 folder
	shutil.copy(
		path_model + '/model_1_seed_0.txt',
		out_dir_files + '/iota2_results_classif_labels-' + label_year + '-S2_' + S2_year + '/model/'
	)

	run_iota2("part 2 (classification)", [
		"python", command_path,
		'-config', 'generated_config_files/config_Labels_classif_part2_' + label_year + '_year_' + S2_year + '_2y_nov.cfg',
		'-config_ressources', 'iota2/config/iota2_resources.cfg',
		'-nb_parallel_tasks', nb_parallel_tasks,
		'-restart',
		'-scheduler_type', scheduler_type
	])

	# nemeton: a zero return code is not the same as a finished chain. IOTA2 can
	# stop on a partial task graph and still exit 0 — in which case `final/` is
	# empty and the masking below fails on a missing input, three steps away from
	# the cause. Say what is actually there instead.
	def require_final(path):
		if os.path.exists(path):
			return path
		final_dir = os.path.dirname(path)
		results_dir = os.path.dirname(final_dir.rstrip('/'))
		def listing(d):
			try:
				return ', '.join(sorted(os.listdir(d))) or '(empty)'
			except OSError:
				return '(absent)'
		print(
			f"ERROR: IOTA2 produced no {os.path.basename(path)}.\n"
			f"  final/: {listing(final_dir)}\n"
			f"  classif/: {listing(os.path.join(results_dir, 'classif'))}\n"
			"  The chain ended without assembling a final map — see "
			"IOTA2_tasks_status.txt and logs/ in the results dir.",
			file=sys.stderr,
		)
		sys.exit(3)

	if dict_config['mask_final_maps'] == 'True' or dict_config['mask_final_maps'] is True:
		dir_final_classif = out_dir_files + '/iota2_results_classif_labels-' + label_year + '-S2_' + S2_year + '/final/'
		# mask classif map
		src = require_final(dir_final_classif + 'Classif_Seed_0.tif')

		if len(dict_config['path_to_binary_mask']) < 4:
			print('Using available deciduous tree mask from OSO')
			src_mask = 'masks/mask_oso_deciduous_compress.tif'
		else:
			print('Using custom mask')
			src_mask = dict_config['path_to_binary_mask']
		out_dir = dir_final_classif + 'Final_Classif_masked_' + S2_year + '.tif'
		mask_rasters(src, src_mask, out_dir, 'uint8')

		# mask proba maps
		src = require_final(dir_final_classif + 'ProbabilityMap_seed_0.tif')
		src_mask = 'masks/mask_oso_deciduous_compress.tif'
		out_dir = dir_final_classif + 'Final_Proba_map_masked' + S2_year + '.tif'
		mask_rasters(src, src_mask, out_dir, 'int16')

		# mask proba maps and compute continues score
		src = dir_final_classif + 'Final_Proba_map_masked' + S2_year + '.tif'
		out_dir = dir_final_classif + 'Final_continuous_score_masked' + S2_year + '.tif'
		compute_continuous_score(src, out_dir, 'int16')

	else:
		# if no mask is used, we only compute the continuous score
		dir_final_classif = out_dir_files + '/iota2_results_classif_labels-' + label_year + '-S2_' + S2_year + '/final/'
		# mask classif map
		src = require_final(dir_final_classif + 'ProbabilityMap_seed_0.tif')
		out_dir = dir_final_classif + 'Final_continuous_score_masked' + S2_year + '.tif'
		compute_continuous_score(src, out_dir, 'int16')