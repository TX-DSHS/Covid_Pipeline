#!/bin/sh

#################################################################################
#
# This script is used to run the Cecret pipeline on Clear Labs runs on the DSHS AWS server.
# The script will download the sequencing run data from the S3 bucket, run the Cecret pipeline, and upload the results back to the S3 bucket.
# The script will also run the postCecretPipeline.sh script if the demo file is found.
#
# Usage: bash run_Cecret_CL_sb.sh <run_name> 
# Example: bash run_Cecret_CL_sb.sh TX-CL001-240820
#
# Author(s): jie.lu@dshs.texas.gov & richard.bovio@dshs.texas.gov
# Date last updated: 2024-09-04
#
#################################################################################

# Create variables for cecret analysis
version="v1.0"
aws_bucket="s3://804609861260-covid-19"

# Create directories for run analysis
# install_dir=$PWD # UNCOMMENT ONCE PIPELINE IS COMPLETE AND LAMBDA IS TURNED BACK ON 
install_dir="/bioinformatics/Covid_Pipeline"
basedir="${install_dir}/cecret_runs/$1"
rm -rf $basedir 
mkdir -p $basedir
mkdir -p ${basedir}/download
mkdir -p ${basedir}/reads
mkdir -p ${basedir}/fastq

# Generate run_Cecret.log
echo "Running run_Cecret_CL.sh "$version 2>&1 | tee $basedir/run_Cecret.log 
echo `date` 2>&1 | tee -a $basedir/run_Cecret.log
echo "" 2>&1 | tee -a $basedir/run_Cecret.log

# Copy read files from AWS S3 to ${basedir}/download
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

# Activate conda environment
echo "Activating conda environment" 2>&1 | tee -a $basedir/run_Cecret.log 
echo "" 2>&1 | tee -a $basedir/run_Cecret.log 
source ${install_dir}/miniconda3/etc/profile.d/conda.sh
conda activate covid

# Pulling the latest version of Cecret
nextflow pull UPHL-BioNGS/Cecret

# Run Cecret
echo "Running Cecret Pipeline..." 2>&1 | tee -a $basedir/run_Cecret.log
cd ${basedir}
nextflow run UPHL-BioNGS/Cecret -profile docker --fastas ${basedir}/reads

# If the run is not successful, exit the script
if [ $? -ne 0 ]; then
  echo "The Cecret pipeline failed" 2>&1 | tee -a $basedir/run_Cecret.log
  exit 1
else
  echo "The Cecret pipeline completed successfully" 2>&1 | tee -a $basedir/run_Cecret.log
  echo "" 2>&1 | tee -a $basedir/run_Cecret.log 
fi

# Zip Cecret results
if [ -e ${install_dir}/cecret_runs/zip_files/$1.zip ]; then
  rm ${install_dir}/cecret_runs/zip_files/$1.zip
fi
echo "Zipping Cecret Pipeline output files" 2>&1 | tee -a $basedir/run_Cecret.log
echo "" 2>&1 | tee -a $basedir/run_Cecret.log
#zip -r ${install_dir}/cecret_runs/zip_files/$1.zip $basedir/cecret/
cd ${basedir}/cecret/
zip -r $1.zip .
mv $1.zip ${install_dir}/cecret_runs/zip_files/
cd ${basedir}

# Copy Cecret results to AWS S3 zip_files
echo "Transferring Cecret Pipeline output files to AWS S3" 2>&1 | tee -a $basedir/run_Cecret.log
aws s3 cp ${install_dir}/cecret_runs/zip_files/$1.zip $aws_bucket/cecret_runs/zip_files/
# If the last executed command (i.e. AWS transfer) is not successful, exit the script
if [ $? -ne 0 ]; then
  echo "The zip file $1.zip failed to transfer to AWS S3" 2>&1 | tee -a $basedir/run_Cecret.log
  exit 1
fi

# Copy cecret_results.csv to AWS S3 run_results
echo "Transferring cecret_results.csv to AWS S3" 2>&1 | tee -a $basedir/run_Cecret.log
echo "" 2>&1 | tee -a $basedir/run_Cecret.log
aws s3 cp $basedir/cecret/cecret_results.csv $aws_bucket/cecret_runs/run_results/run_results_$1.csv
# If the last executed command (i.e. AWS transfer) is not successful, exit the script
if [ $? -ne 0 ]; then
  echo "The cecret_results.csv file failed to transfer to the S3" 2>&1 | tee -a $basedir/run_Cecret.log
  exit 1
fi

echo -e "-----------------------------------------------------------" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------\n" 2>&1 | tee -a $basedir/run_Cecret.log


######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################


# Check if demo file exists and is properly formatted
demo=$basedir/download/'demo_'$1.txt
if [ -e $demo ]; then
  dos2unix $demo > /dev/null 2>&1
  # Run the script and capture its exit status
  {
    bash ${install_dir}/check_demo.sh $1
  } 2>&1 | tee -a $basedir/run_Cecret.log
  # Capture the exit status of the script execution
  status=${PIPESTATUS[0]}
  # If the last executed command (i.e. checking demo file) is not successful, exit the script
  if [ $status -ne 0 ]; then
    echo "The demo file is not formatted properly" 2>&1 | tee -a $basedir/run_Cecret.log
    exit 1
  fi
else
  echo "ERROR: No demo file found" 2>&1 | tee -a $basedir/run_Cecret.log
  exit 1
fi
echo "" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------" 2>&1 | tee -a $basedir/run_Cecret.log
echo -e "-----------------------------------------------------------\n" 2>&1 | tee -a $basedir/run_Cecret.log


######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################


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


#echo "Continuing run_Cecret_CL.sh "$version"..." 2>&1 | tee -a $basedir/run_Cecret.log
#echo `date` 2>&1 | tee -a $basedir/run_Cecret.log
#echo "" 2>&1 | tee -a $basedir/run_Cecret.log

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

echo "run_Cecret_CL_sb.sh completed at "`date` 2>&1 | tee -a $basedir/run_Cecret.log