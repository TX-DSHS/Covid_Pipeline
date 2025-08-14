#!/bin/sh

#################################################################################
#
# This script is used to run the Cecret pipeline on Clear Labs runs on the DSHS AWS server.
# The script will download the sequencing run data from the S3 bucket, run the Cecret pipeline, and upload the results back to the S3 bucket.
# The script will also run the postCecretPipeline.sh script if the demo file is found.
#
# Usage: bash run_Cecret_CL.sh <run_name> 
# Example: bash run_Cecret_CL.sh TX-CL001-240820
#
# Author(s): richard.bovio@dshs.texas.gov, jie.lu@dshs.texas.gov
# Date last updated: 2025-08-05
#
#################################################################################

## Create conda environment - completed 2025-08-05
# conda create --name covid
# conda install -c conda-forge -c bioconda r-dplyr r-lubridate pandas nextflow

# Activate conda environment
echo "Activating conda environment" 2>&1 | tee $basedir/run_Cecret.log 
echo "" 2>&1 | tee -a $basedir/run_Cecret.log 
source /bioinformatics/miniconda3/etc/profile.d/conda.sh
conda activate covid

# Create variables for cecret analysis
install_dir="/bioinformatics/Covid"
basedir="${install_dir}/cecret_runs/$1"
authors=$(head $install_dir'/template/authors.txt')
aws_bucket="s3://430118851772-covid-19"

# Create directories for run analysis
rm -rf $basedir 
mkdir -p $basedir
mkdir -p ${basedir}/download
mkdir -p ${basedir}/reads
mkdir -p ${basedir}/fastq

# Generate run_Cecret.log
echo "Running run_Cecret_CL.sh" 2>&1 | tee -a $basedir/run_Cecret.log 
echo `date` 2>&1 | tee -a $basedir/run_Cecret.log
echo "" 2>&1 | tee -a $basedir/run_Cecret.log

# Copy reads and demos from AWS S3 to ${basedir}/download
aws s3 cp $aws_bucket/DATA/RAW_RUNS/$1.zip ${basedir}/download

# If the zip file is not found, exit the script
echo "Checking if data was successfully copied over from AWS S3..." 2>&1 | tee -a $basedir/run_Cecret.log 
if [ ! -f ${basedir}/download/$1.zip ]; then
  echo "The zip file "$1".zip was not found in the S3 or was not copied over properly. Check AWS S3 to see if zip file was uploaded/named properly." 2>&1 | tee -a $basedir/run_Cecret.log 
  exit 1
else
  echo $1".zip was successfully found" 2>&1 | tee -a $basedir/run_Cecret.log
fi
echo "" 2>&1 | tee -a $basedir/run_Cecret.log 

# Extract read files
unzip -j ${basedir}/download/$1.zip -d ${basedir}/download/ # Unzip read files
tar -xvf ${basedir}/download/*.fastqs.tar -C ${basedir}/fastq # Extract fastq files from tar archive
tar -xvf ${basedir}/download/*.fastas.tar -C ${basedir}/reads # Extract fasta files from tar archive



#####################################################################################################
#########################################                   #########################################
#########################################  USE WHEN NEEDED  #########################################
#########################################                   #########################################
#####################################################################################################

# REMOVE UNWANTED SAMPLES
# rm ${basedir}/fastq/Water*
# rm ${basedir}/reads/Water*

# TMP MOVE MODIFIED DEMOS TO DOWNLOAD FOLDER
# cp ${install_dir}/modified_demos/demo_TX-CL001-250519.txt ${basedir}/download/ 

# RENAME DEMO FILE
# mv ${basedir}/download/demo_TX_CL001-250603.txt ${basedir}/download/demo_TX-CL001-250603.txt

#####################################################################################################

# If filename has spaces then replace with underscore
cd ${basedir}/reads
for f in *\ *; do mv "$f" "${f// /_}"; done

# Remove trailing line from demos function
remove_trailing_blank_line() {
  local file="${install_dir}/cecret_runs/$1/download/demo_$1.txt"
  # local file="${install_dir}/modified_demos/demo_$1.txt"
  # Check if file exists
  if [[ ! -f "$file" ]]; then
    echo "Error: File '$file' does not exist."
    exit 1
  fi

  # Use sed to remove the trailing blank line
  sed -i ':a;/^[[:space:]]*$/{$d;N;ba}' "$file"
  echo "Trailing blank line removed from '$file'."
}
# Remove trailing line if one is present
remove_trailing_blank_line "$1"

# Create samplesheet
cd ${basedir}/reads
ls > samples.txt
sed -i '/VERSION.txt/d' samples.txt
sed -i '/samples.txt/d' samples.txt
sed -i 's/.fasta//g' samples.txt
cd ${install_dir}
Rscript create_samplesheet.R $1 ${basedir}/reads/samples.txt

# Pulling the latest version of Cecret
rm -rf ~/.nextflow/assets/UPHL-BioNGS/Cecret
nextflow pull UPHL-BioNGS/Cecret

# Run Cecret
echo "Running Cecret Pipeline..." 2>&1 | tee -a $basedir/run_Cecret.log
cd ${basedir}
nextflow run UPHL-BioNGS/Cecret -profile docker --fastas ${basedir}/reads --sample_sheet $install_dir'/samplesheets/'$1_samplesheet.csv

# If the run is not successful, exit the script
if [ $? -ne 0 ]; then
  echo "The Cecret pipeline failed" 2>&1 | tee -a $basedir/run_Cecret.log
  exit 1
else
  echo "The Cecret pipeline completed successfully" 2>&1 | tee -a $basedir/run_Cecret.log
  echo "" 2>&1 | tee -a $basedir/run_Cecret.log 
fi






## Zip Cecret results
#if [ -e ${install_dir}/cecret_runs/zip_files/$1.zip ]; then
#  rm ${install_dir}/cecret_runs/zip_files/$1.zip
#fi
#echo "Zipping Cecret Pipeline output files" 2>&1 | tee -a $basedir/run_Cecret.log
#echo "" 2>&1 | tee -a $basedir/run_Cecret.log
#cd ${basedir}/cecret/
#zip -r $1.zip .
#mv $1.zip ${install_dir}/cecret_runs/zip_files/
#cd ${basedir}
#
## Copy Cecret results to AWS S3 zip_files
#echo "Transferring Cecret Pipeline output files to AWS S3" 2>&1 | tee -a $basedir/run_Cecret.log
#aws s3 cp ${install_dir}/cecret_runs/zip_files/$1.zip $aws_bucket/cecret_runs/zip_files/
## If the last executed command (i.e. AWS transfer) is not successful, exit the script
#if [ $? -ne 0 ]; then
#  echo "The zip file $1.zip failed to transfer to AWS S3" 2>&1 | tee -a $basedir/run_Cecret.log
#  exit 1
#fi
#
## Copy cecret_results.csv to AWS S3 run_results
#echo "Transferring cecret_results.csv to AWS S3" 2>&1 | tee -a $basedir/run_Cecret.log
#echo "" 2>&1 | tee -a $basedir/run_Cecret.log
#aws s3 cp $basedir/cecret/cecret_results.csv $aws_bucket/cecret_runs/run_results/run_results_$1.csv
## If the last executed command (i.e. AWS transfer) is not successful, exit the script
#if [ $? -ne 0 ]; then
#  echo "The cecret_results.csv file failed to transfer to the S3" 2>&1 | tee -a $basedir/run_Cecret.log
#  exit 1
#fi

echo -e "-----------------------------------------------------------" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------\n" 2>&1 | tee -a $basedir/run_Cecret.log







# Run postCecretPipeline
bash ${install_dir}/postCecretPipeline_CL.sh $1 2>&1 | tee -a $basedir/run_Cecret.log
echo "" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------\n" 2>&1 | tee -a $basedir/run_Cecret.log


######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################


echo "Continuing run_Cecret_CL.sh "$version"..." 2>&1 | tee -a $basedir/run_Cecret.log
echo `date` 2>&1 | tee -a $basedir/run_Cecret.log
echo "" 2>&1 | tee -a $basedir/run_Cecret.log

## Submit to SRA
#echo "Running submit_to_SRA.sh..." 2>&1 | tee -a $basedir/run_Cecret.log
#bash submit_to_SRA.sh $1
#
## Submit to GISAID
#echo "Running submit_to_Gisaid.sh..." 2>&1 | tee -a $basedir/run_Cecret.log
#bash submit_to_Gisaid.sh $1
#echo "" 2>&1 | tee -a $basedir/run_Cecret.log

# Deactivate conda environment
echo "Deactivating conda environment" 2>&1 | tee -a $basedir/run_Cecret.log 
echo "" 2>&1 | tee -a $basedir/run_Cecret.log
conda deactivate

echo "run_Cecret_CL.sh completed at "`date` 2>&1 | tee -a $basedir/run_Cecret.log