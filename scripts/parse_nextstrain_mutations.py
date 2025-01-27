import re; import math 
import pandas as pd
# Parses the Nexclade summary report AA substitutions and deletions lists. Output is a tab-delimited file where each mutation is a separate row.
nc = pd.read_csv("summary_nextclade_report.tsv", sep="\t", header=0, index_col=None) # nc.dtypes 
colnames = ['sample','clade','qcStatus','qcScore','mutType','mutName','mutGene','mutMut','mutPos','mutRef','mutAlt'] 
dfAll = pd.DataFrame(columns=colnames) 
for ix in range(len(nc)): # ix=0
    samp = str(nc["Sample_Name"][ix])
    clade = nc["clade"][ix]
    score = round(nc["qc.overallScore"][ix])
    status = nc["qc.overallStatus"][ix]
    aaSubs = nc["aaSubstitutions"][ix]
    if ((isinstance(aaSubs, float) and math.isnan(aaSubs)) == False):
        sub_name = aaSubs.split(sep=","); nsub = len(sub_name)
        sub_mut = [re.sub('.*[:]', '', el) for el in sub_name]
        dfs = pd.DataFrame(
            {'sample': [samp] * nsub,
                'clade' : [clade] * nsub,
                'qcStatus': [status] * nsub,
                'qcScore' : [int(score)] * nsub,
                'mutType' : ['sub'] * nsub,
                'mutName' : sub_name,
                'mutGene' : [re.sub('[:].*', '', el) for el in sub_name],
                'mutMut' : sub_mut,
                'mutPos' : [int(re.sub(r'[^\d]', '', el)) for el in sub_name] ,
                'mutRef' : [re.sub(r'\d+.*', '', el) for el in sub_mut],
                'mutAlt' : [re.sub(r'.*\d+', '', el) for el in sub_mut]
            })
        dfAll = pd.concat([dfAll, dfs], axis=0, ignore_index=True)
    aaDels = nc["aaDeletions"][ix]
    if ((isinstance(aaDels, float) and math.isnan(aaDels)) == False):
        del_name = aaDels.split(sep=","); ndel = len(del_name)
        del_mut = [re.sub('.*[:]', '', el) for el in del_name]
        dfd = pd.DataFrame(
            {'sample': [samp] * ndel,
                'clade' : [clade] * ndel,
                'qcStatus': [status] * ndel,
                'qcScore' : [int(score)] * ndel,
                'mutType' : ['del'] * ndel,
                'mutName' : del_name,
                'mutGene' : [re.sub('[:].*', '', el) for el in del_name],
                'mutMut' : del_mut,
                'mutPos' : [int(re.sub(r'[^\d]', '', el)) for el in del_name] ,
                'mutRef' : [re.sub(r'\d+.*', '', el) for el in del_mut],
                'mutAlt' : [re.sub(r'.*\d+', '', el) for el in del_mut]
            })
        dfAll = pd.concat([dfAll, dfd], axis=0, ignore_index=True)

dfAll.to_csv("nextclade_mutations.tsv", sep="\t", header=True, index=False)
