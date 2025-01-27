#!/usr/bin/env python3
from glob import glob
from io import StringIO
import re
import pandas as pd

reportFiles = glob("cecret/nextclade/*_report.csv")
reports = [pd.read_csv(f, sep=";", header=0, index_col=None)
           for f in reportFiles]
reports = pd.concat(reports, axis=0) # sort=False
#reports.index = reports["seqName"].str.replace(r"Consensus_|\..*", "").astype(int)
reports.index = reports["seqName"].str.replace(r"Consensus_|\..*", "")
reports.index.name = "Sample_Name"
reports = reports.sort_index()
reports.to_csv("summary_nextclade_report.tsv",
               sep="\t", header=True, index=True)
pangFiles = glob("cecret/pangolin/*/*_report.csv")
pang = [pd.read_csv(f, sep=",", header=0, index_col=None)
        for f in pangFiles]
pang = pd.concat(pang, axis=0)
pang.index = pang["taxon"].str.replace(r"Consensus_|\..*", "")
pang.index.name = "Sample_Name"
pang = pang.sort_index()
pang.to_csv("summary_pangolin_report.tsv",
            sep="\t", header=True, index=True)

## concat two DataFrames together horizontally (axis=1):
#both = pd.concat([reports, pang], axis=1)
#both.to_csv("merged_nextclade_plus_pangolin.tsv",
#            sep="\t", header=True, index=True)

