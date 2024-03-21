#!/bin/bash

#use this script to run Cecret
#useage:
# bash run_Cecret_CL.sh <sequencing_run> 
# Date updated: 2023-04-18
# Author: jie.lu@dshs.texas.gov
#example############################################
# bash run_Cecret_CL.sh <run_name>

#add nextflow and miniconda to PATH
export PATH="$PATH:/work/software/"
source /work/software/miniconda3/etc/profile.d/conda.sh
if [[ -z ${CONDA_PREFIX+x} ]]; then
    export PATH="$PATH:~/conda/bin"
fi
#set the base directory
basedir="/home/dnalab/cecret_runs/$1" #$1 corresponds to first argument in bash command <sequencing_run>
rm -rf $basedir
mkdir $basedir

echo "Starting running run_Cecret.sh at "`date` 1>$basedir/run_Cecret.log

#Copy read files to working directory/reads
mkdir -p ${basedir}/download
mkdir -p ${basedir}/reads
mkdir -p ${basedir}/fastq

aws s3 cp s3://804609861260-covid-19/DATA/RAW_RUNS/$1.zip ${basedir}/download
unzip -j ${basedir}/download/$1.zip -d ${basedir}/download/
tar -xvf ${basedir}/download/*.fastqs.tar -C ${basedir}/fastq
tar -xvf ${basedir}/download/*.fastas.tar -C ${basedir}/reads

#rm -r $basedir/download

echo "Pulling latest version of Pangolin" 1>>$basedir/run_Cecret.log
#pull the latest pangolin version
#docker pull staphb/pangolin:latest

#/work/software/nextflow pull UPHL-BioNGS/Cecret

#run cecret
echo "Running Cecret Pipeline" 1>>$basedir/run_Cecret.log
cd ${basedir}
source /home/dnalab/miniconda3/etc/profile.d/conda.sh
conda activate covid
nextflow pull UPHL-BioNGS/Cecret
nextflow run UPHL-BioNGS/Cecret -profile docker --fastas ${basedir}/reads
conda deactivate

# Run postCecretPipeline
echo "Running postCecretPipeline" 1>>$basedir/run_Cecret.log

if ls ${basedir}/reads/demo* 1> /dev/null 2>&1; then
    echo "demo file found" 1>>$basedir/run_Cecret.log
    cp ${basedir}/reads/demo* /home/dnalab/ 2>>$basedir/run_Cecret.err
    cd /home/dnalab/
    bash postCecretPipeline_test.sh $1 2>>$basedir/run_Cecret.err
else
    echo "demo file does not exist" 1>>$basedir/run_Cecret.log
fi

echo "Zipping Cecret Pipeline output files" 1>>$basedir/run_Cecret.log
zip -r /home/dnalab/cecret_runs/zipfiles/$1 $basedir/cecret/

echo "Transferring Cecret Pipeline output files to s3" 1>>$basedir/run_Cecret.log
aws s3 cp  $(echo /home/dnalab/cecret_runs/zipfiles/${1}.zip) s3://804609861260-covid-19/cecret_runs/zip_files/
rm /home/dnalab/cecret_runs/zipfiles/$1.zip

echo "run_Cecret_CL.sh completed at "`date` 1>>$basedir/run_Cecret.log
# submit to SRA and Gisaid
# bash submit_to_SRA.sh $1
# bash submit_to_Gisaid.sh $1
