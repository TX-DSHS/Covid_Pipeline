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

#copy Cecret to the working directory

#Copy read files to working directory/reads
mkdir ${basedir}/reads
cp -p ${2}/*.fastq.gz $basedir/reads/


cp  -r /home/bioinform/Cecret/ $basedir/
cd $basedir
/work/software/nextflow run $basedir/Cecret/Cecret_with_kraken.nf -c $basedir/Cecret/configs/docker.config

