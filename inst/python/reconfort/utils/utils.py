def load_config_variable(path_to_cfg):
    data = {}
    with open(path_to_cfg, "r") as file:
        # Read each line and evaluate it to create dictionary entries
        for line in file:
            key, value = line.strip().split("=")
            data[key] = eval(value)
    return data
