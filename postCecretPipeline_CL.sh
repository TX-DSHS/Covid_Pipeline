#!/bin/sh

######################################################################################################################################################
#
# Title: postCecretPipeline_CL_sb.sh
#
# Description: This script creates post analysis files for SRA and GISAID submission. 
#
# Usage: bash postCecretPipeline_CL.sh <run_name> [-h]
# Example: bash /bioinformatics/Covid_Pipeline/postCecretPipeline_CL.sh TX-CL001-240820
#
# Author: Richard (Stephen) Bovio
# Author Contact: richard.bovio@dshs.texas.gov
# Date created: 2024-09-04
# Date last updated: 2025-08-05
#
######################################################################################################################################################

# If no arguments are provided OR the <run_name> == '-h'
if [ $# -eq 0 -o "$1" == "-h" ] ; then
  echo "No arguments provided"
  echo "Usage: bash /bioinformatics/Covid_Pipeline/postCecretPipeline_CL.sh <run_name>"
  echo "Example: bash /bioinformatics/Covid_Pipeline/postCecretPipeline_CL.sh TX-CL001-240820"
	exit 0
fi

# Create variables for cecret analysis
basedir="/bioinformatics/Covid_Pipeline"
run_dir=$basedir'/cecret_runs/'$1

# Read results file
result=$run_dir'/cecret/cecret_results.txt'  # original results
# result=$basedir'/modified_results/cecret_results.csv' # modified results

# Read demo file
demo=$run_dir/download/'demo_'$1.txt # original demos
# demo=$basedir'/modified_demos/demo_'$1.txt # modified demos

# Read authors file
authors=$(head $basedir'/template/authors.txt')

echo "Running postCecretPipeline_CL.sh "$version 2>&1 | tee $run_dir/$1.postCecret.log
echo `date` 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log

# Check if cecret_results.txt file was generated
echo "Checking if cecret_results.txt was generated..." 2>&1 | tee -a $run_dir/$1.postCecret.log
if [ -e $result ]; then
  echo "cecret_results.txt file was successfully generated" 2>&1 | tee -a $run_dir/$1.postCecret.log
  echo ""  2>&1 | tee -a $run_dir/$1.postCecret.log 
  echo -e "-----------------------------------------------------------\n" 2>&1 | tee -a $run_dir/$1.postCecret.log
else
  echo "ERROR: cecret_results.txt was NOT generated" 2>&1 | tee -a $run_dir/$1.postCecret.log
	exit 1
fi

# Remove the suffix added by Clear Labs system from the Sample_ID
python3 /bioinformatics/Covid_Pipeline/convert_results.py $result $result.tmp

# Post-processing
Rscript /bioinformatics/Covid_Pipeline/postCecretPipeline_CL_linux.R $1

################################################################################################
################################ SRA FASTA SUBMISSION ##########################################
################################################################################################

# Remove pre-existing fasta consensus files
if [ -e $run_dir/$1.fasta ]; then
  rm $run_dir/$1.fasta 
fi

# Generate consensus fasta file
fasta_dir=$run_dir/reads

while IFS=$'\t' read -r -a line
do
  if [ -e $fasta_dir/${line[0]}.fasta ]; then
	  sed  "s/>.*/>${line[1]}\/${line[2]}/g" $fasta_dir/${line[0]}.fasta | sed  's/>/>hCoV-19\/USA\//g' > $fasta_dir/${line[0]}.fa.tmp
    cat $fasta_dir/${line[0]}.fa.tmp >> $run_dir/$1.fasta
	  rm $fasta_dir/${line[0]}.fa.tmp
  fi
done < $run_dir/$1'_SRA_fasta_samples_to_submit.txt'

# Modify SRA attribute file
tail -n +2 $run_dir/$1'_SRA_attribute_submission.txt' > $run_dir'/tmp.txt'
rm $run_dir/$1'_SRA_attribute_submission.txt'
cat $basedir'/template/attribute_template.txt' $run_dir'/tmp.txt' > $run_dir/$1'_SRA_attribute_submission.txt'
rm $run_dir'/tmp.txt'

################################################################################################
################################ SRA FASTQ SUBMISSION ##########################################
################################################################################################

# Remove pre-existing fastq files from $run_dir/SRA_fastq
if [ -e $run_dir/SRA_fastq ]; then 
  rm -r $run_dir/SRA_fastq
fi
mkdir $run_dir/SRA_fastq

# Collect fastq files to be submitted
# This reads each line from a metadata file ($run_dir/$1_SRA_metadata_submission.txt), checks if a file specified by the 12th field (filename) of the line exists in a source directory ($run_dir/fastq/), and if it does, copies that file to a destination directory ($run_dir/SRA_fastq/).
while IFS=$'\t' read -r -a line
do
  if [ -e $run_dir/fastq/${line[0]}.*.fastq ]; then
    cp $run_dir/fastq/${line[0]}.*.fastq $run_dir/SRA_fastq/
  fi
done < $run_dir/$1'_SRA_fastq_samples_to_submit.txt'

################################################################################################
################################################################################################
################################################################################################

# Remove work directory
rm -r $run_dir/work
rm $run_dir/$1'_SRA_fasta_samples_to_submit.txt'
rm $run_dir/$1'_SRA_fastq_samples_to_submit.txt'

################################################################################################
##################### ZIP AND COPY POSTCECRET RESULTS TO AWS S3 ################################
################################################################################################

# Remove pre-existing postCecret zip results
if [ -e $basedir/cecret_runs/zip_files/postCecret_$1.zip ]; then
  rm $basedir/cecret_runs/zip_files/postCecret_$1.zip
fi

# Zip and copy postCecret results to AWS S3
echo "Zipping postCecretPipeline output files" 2>&1 | tee -a $run_dir/$1.postCecret.log
zip -rj $basedir/cecret_runs/zip_files/postCecret_$1 $run_dir/$1*
echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "Transferring postCecretPipeline output files to AWS S3" 2>&1 | tee -a $run_dir/$1.postCecret.log
aws s3 cp $basedir/cecret_runs/zip_files/postCecret_$1.zip s3://430118851772-covid-19/cecret_runs/zip_files/postCecret_$1.zip
