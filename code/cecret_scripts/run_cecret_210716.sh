#!/bin/bash

#use this script to run Cecret
#useage:
# bash run_cecret.sh <sequencing_run> <path/to/reads>
#example############################################
# bash run_cecret.sh test_run /home/karen_test/test_run2/reads/

#set the base directory
basedir="$HOME/cecret_runs/$1" #$1 corresponds to first argument in bash command <sequencing_run>
mkdir -p $basedir


#add nextflow and miniconda to PATH
export PATH="$PATH:/work/software/"
source /work/software/miniconda3/etc/profile.d/conda.sh
if [[ -z ${CONDA_PREFIX+x} ]]; then
    export PATH="$PATH:~/conda/bin"
fi

#Copy read files to working directory/reads
mkdir ${basedir}/reads
cp -p ${2}/*.fastq.gz $basedir/reads/

#copy Cecret to the working directory
cp  -r /home/bioinform/Cecret/ $basedir/
cd $basedir
#run cecret
/work/software/nextflow run $basedir/Cecret/Cecret.nf -c $basedir/Cecret/configs/DSHS.config

#cp /work/software/code/summarize_cecret.py ./
python3 /work/software/code/summarize_cecret.py #script from Anna at UT Austin to summarize cecret results
#cp /work/software/code/parse_nextstrain_mutations.py ./
python3 /work/software/code/parse_nextstrain_mutations.py #script from Anna at UT Austin to create list of mutations

#run annotation portion of cecret
/work/software/nextflow run $basedir/Cecret/Cecret_annotation.nf  -c $basedir/Cecret/configs/DSHS.config

#copy new fastas so they can be used to run mafft, snpdists, and iqtree
cp $basedir/cecret/consensus/*.consensus.fa /home/dnalab/cecret_runs/cumulative_fastas/
#run mafft, snpdists, and iqtree for cumulative fasta files
/work/software/nextflow run $basedir/Cecret/Cecret_annotation.nf  -c $basedir/Cecret/configs/DSHS.config --relatedness true --fastas /home/dnalab/cecret_runs/cumulative_fastas/


/home/dnalab/cecret_runs/test_210716_KB/configs/DSHS.config
/home/dnalab/cecret_runs/test_210716_KB/Cecret/configs
