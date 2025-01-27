#!/usr/bin/env python3

import sys
import pandas as pd

if len(sys.argv) != 3:
    print("Usage: python3 convertFileName.py <filename> <outputname>")
    sys.exit(1)

filename = sys.argv[1]
outname = sys.argv[2]

# Define a function to truncate names safely
def truncateNames(s):
    if isinstance(s, str):  # Check if the value is a string
        return s.split(".")[0]
    return s  # Return the value unchanged if not a string

# Read the tab-delimited file
df = pd.read_csv(filename, sep="\t")

# Apply the truncateNames function to relevant columns
df["sample_id"] = df["sample_id"].apply(truncateNames)
df["fasta_line"] = df["fasta_line"].apply(truncateNames)

# Write the updated DataFrame back to a tab-delimited file
df.to_csv(outname, sep="\t", index=False)
