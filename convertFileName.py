#!/usr/bin/env python3
import csv
import sys
import pandas as pd

if len(sys.argv) != 3:
    print("Usage: python3 convertFileName.py <filename>")
    sys.exit(1)

filename = sys.argv[1]
outname = sys.argv[2]

def truncateNames(s):
    return s.split(".")[0]

df = pd.read_csv(filename, sep='\t')
df["sample_id"] = df["sample_id"].apply(truncateNames)
df["fasta_line"] = df["fasta_line"].apply(truncateNames)

df.to_csv(outname, sep = "\t", index=False)