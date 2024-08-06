import os
import json
import tqdm

DIRECTORY = "extractor_transformer/output_dir/transactions"

for file in tqdm.tqdm(os.listdir(DIRECTORY)):

    with open(os.path.join(DIRECTORY, file), "r") as f:

        for line in f.readlines():
            jobj = json.loads(line)

            num_write_modules = jobj['num_changes']['write_module']
            tx_version = jobj['tx_version']

            if num_write_modules != "0" and num_write_modules != 0:
                tqdm.tqdm.write(f"(file: {file}, tx_version:{tx_version})");

            
