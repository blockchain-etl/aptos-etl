''' This file allows taking the BQ Schema Jsons and convert it to a CSV. '''
from __future__ import annotations
from typing import Union, Any, TextIO, cast, Optional
from json import load as jsonload


VALID_MODES = frozenset(("REPEATED", "REQUIRED", "NULLABLE"))
VALID_TYPES = frozenset(("BIGNUMERIC", "BOOL", "BYTES", "DATE", "DATETIME", \
                         "FLOAT64", "GEOGRAPHY", "INT64", "INTERVAL", "JSON", 
                         "NUMERIC", "STRING", "STRUCT", "TIME", "TIMESTAMP"))

def add_field(csv_io:TextIO, \
              field:dict[str,Union[str,int,float,dict[str,Any],list[Any]]],\
              name_prefix:Optional[str]=None) -> None:
    ''' Adds a field to the csv '''

    # Verify given a dict for field
    if not isinstance(field, dict):
        raise TypeError('Field must be a dict')
    
    # Try to extract the important values
    try:
        name, dtype, mode = field['name'], field['type'], field['mode']
    except KeyError as key_err:
        raise KeyError(f"Expected fields to have `name`, `type`, and `mode` fields: {field:r}") from key_err
    
    # Add the name prefix (if provided)
    if name_prefix is not None:
        name = f"{name_prefix}.{name}"

    # validate stuff
    if cast(str,mode).lower() not in VALID_MODES:
        raise ValueError(f'Invalid field mode: \"{mode}\" for {name}')
    elif cast(str, dtype).lower() not in VALID_TYPES:
        raise ValueError(f'Invalid field type: \"{dtype}\" for {name}')
    
    # Description is optional, postprocess it if necessary
    try:
        desc = "\"" + cast(str,field['description']).replace('\"', '\"\"') + "\""
    except KeyError:
        desc = ""
    # Go ahead and write it out
    csv_io.write(f"{name},{dtype},{mode},{desc}\n")

    # If nested records, go deeper with appended name prefix
    if 'fields' in field:
        # iterate through the subfields
        for subfield in cast(list[dict[str,Any]], field['fields']):
            add_field(csv_io, subfield, name_prefix=cast(str,name))

def convert_schema(json_io:TextIO, csv_io:TextIO) -> None:
    ''' Converts the schema jsons to CSVs '''
    # Load in the json
    rootfields = jsonload(json_io)

    # Verify we have a list
    if not isinstance(rootfields, list):
        raise ValueError("Json was read in correctly, however we expected a "\
                        +"list as the top layer of the json")
    
    # Write the headers
    csv_io.write("name,type,mode,description\n")
    
    # Add each field
    for field in cast(list[Any], rootfields):
        add_field(csv_io, field)


if __name__ == "__main__":
    # Create an argument parser
    import argparse
    parser = argparse.ArgumentParser(description="Convert to csv")
    parser.add_argument("jsonfile", type=argparse.FileType("r"))
    parser.add_argument("csvfile", type=argparse.FileType("w"))
    args = parser.parse_args()
    # Text
    print(f"JSON: {args.jsonfile.name}")
    print(f"CSV: {args.csvfile.name}")
    # Convert the schemas
    convert_schema(args.jsonfile, args.csvfile)
    # Complete
    print("Completed")
