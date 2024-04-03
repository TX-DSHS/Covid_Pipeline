#!/bin/bash
# This script is used to run the Cecret pipeline on Clear Labs runs on the DSHS AWS server
# The script will download the sequencing run data from the S3 bucket, run the Cecret pipeline, and upload the results back to the S3 bucket
# The script will also run the postCecretPipeline.sh script if the demo file is found
# How to use this script
# Usage:
# bash run_Cecret_CL.sh <sequencing_run> 
# Date updated: 2024-03-28
# Author: jie.lu@dshs.texas.gov
#example############################################
# bash run_Cecret_CL.sh <run_name>

#set the base directory
#aws_bucket="s3://804609861260-covid-19"
# Read the aws bucket name from file aws_bucket.txt
aws_bucket=$(cat aws_bucket.txt)
install_dir=$PWD
version="v1.0"

basedir="${install_dir}/cecret_runs/$1" #$1 corresponds to first argument in bash command <sequencing_run>
rm -rf $basedir
mkdir -p $basedir

echo "Starting running run_Cecret_CL.sh at "`date` 1>$basedir/run_Cecret.log
# log version of the script
echo "The version of the run_Cecret_CL.sh script is" $version 1>>$basedir/run_Cecret.log

#Copy read files to working directory/reads
mkdir -p ${basedir}/download
mkdir -p ${basedir}/reads
mkdir -p ${basedir}/fastq

aws s3 cp $aws_bucket/DATA/RAW_RUNS/$1.zip ${basedir}/download
# if the zip file is not found, exit the script
if [ ! -f ${basedir}/download/$1.zip ]; then
    echo "The zip file $1.zip is not found in the S3 bucket" 1>>$basedir/run_Cecret.log
    exit 1
fi
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
# if the run is not successful, exit the script
if [ $? -ne 0 ]; then
    echo "The Cecret pipeline failed" 1>>$basedir/run_Cecret.log
    exit 1
fi

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
rm -r $basedir/work
zip -r $basedir/$1 $basedir/cecret/

echo "Transferring Cecret Pipeline output files to s3" 1>>$basedir/run_Cecret.log
aws s3 cp $basedir/$1.zip $aws_bucket/cecret_runs/zip_files/
# if the transfer is not successful, exit the script
if [ $? -ne 0 ]; then
    echo "The zip file $1.zip failed to transfer to the S3 bucket" 1>>$basedir/run_Cecret.log
    exit 1
fi

aws s3 cp $basedir/cecret/cecret_results.csv $aws_bucket/cecret_runs/run_results/$1_cecret_results.csv 2>>$basedir/run_Cecret.err
rm $basedir/$1.zip
# if the transfer is not successful, exit the script
if [ $? -ne 0 ]; then
    echo "The cecret_results.csv file failed to transfer to the S3 bucket" 1>>$basedir/run_Cecret.log
    exit 1
fi


echo "run_Cecret_CL.sh completed at "`date` 1>>$basedir/run_Cecret.log
# submit to SRA and Gisaid
# bash submit_to_SRA.sh $1
# bash submit_to_Gisaid.sh $1
