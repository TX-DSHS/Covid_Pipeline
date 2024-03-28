#!/bin/bash

#use this script to run Cecret
#useage:
# bash run_Cecret_CL.sh <sequencing_run> 
# Date updated: 2024-03-28
# Author: jie.lu@dshs.texas.gov
#example############################################
# bash run_Cecret_CL.sh <run_name>

#set the base directory
aws_bucket="s3://804609861260-covid-19"
install_dir="/bioinformatics/Covid_Pipeline"

basedir="${install_dir}/cecret_runs/$1" #$1 corresponds to first argument in bash command <sequencing_run>
rm -rf $basedir
mkdir -p $basedir

echo "Starting running run_Cecret.sh at "`date` 1>$basedir/run_Cecret.log

#Copy read files to working directory/reads
mkdir -p ${basedir}/download
mkdir -p ${basedir}/reads
mkdir -p ${basedir}/fastq

aws s3 cp $aws_bucket/DATA/RAW_RUNS/$1.zip ${basedir}/download
unzip -j ${basedir}/download/$1.zip -d ${basedir}/download/
tar -xvf ${basedir}/download/*.fastqs.tar -C ${basedir}/fastq
tar -xvf ${basedir}/download/*.fastas.tar -C ${basedir}/reads

#rm -r $basedir/download

#run cecret
echo "Running Cecret Pipeline" 1>>$basedir/run_Cecret.log
cd ${basedir}
source /home/dnalab/miniconda3/etc/profile.d/conda.sh
conda activate covid

# Pulling the latest version of Cecret
nextflow pull UPHL-BioNGS/Cecret

nextflow run UPHL-BioNGS/Cecret -profile docker --fastas ${basedir}/reads
conda deactivate

# Run postCecretPipeline
echo "Running postCecretPipeline" 1>>$basedir/run_Cecret.log

if ls ${basedir}/reads/demo* 1> /dev/null 2>&1; then
    echo "demo file found" 1>>$basedir/run_Cecret.log
    cp ${basedir}/reads/demo* $install_dir 2>>$basedir/run_Cecret.err
    cd $install_dir
    bash postCecretPipeline_CL.sh $1 2>>$basedir/run_Cecret.err
else
    echo "demo file does not exist" 1>>$basedir/run_Cecret.log
fi

echo "Zipping Cecret Pipeline output files" 1>>$basedir/run_Cecret.log
rm -r $basedir/cecret/work
zip -r $install_dir/cecret_runs/zipfiles/$1 $basedir/cecret/

echo "Transferring Cecret Pipeline output files to s3" 1>>$basedir/run_Cecret.log
aws s3 cp  $(echo ${install_dir}/cecret_runs/zipfiles/${1}.zip) $aws_bucket/cecret_runs/zip_files/
rm $install_dir/cecret_runs/zipfiles/$1.zip

echo "run_Cecret_CL.sh completed at "`date` 1>>$basedir/run_Cecret.log
# submit to SRA and Gisaid
# bash submit_to_SRA.sh $1
# bash submit_to_Gisaid.sh $1
