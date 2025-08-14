#!/bin/bash 
set -euo pipefail

################################################################################################
# Name: postCecret_CL.sh
# Description: Creates post-analysis files for SRA and GISAID submission.
# Usage: bash /bioinformatics/Covid/postCecret_CL.sh <run_name> [-h]
# Example: bash /bioinformatics/Covid/postCecret_CL.sh TX-CL001-250225
# Author: Richard (Stephen) Bovio
# Contact: richard.bovio@dshs.texas.gov
# Created: 2024-09-04
# Last updated: 2025-08-14
################################################################################################

## Check args
#if [[ $# -eq 0 || "$1" == "-h" ]]; then
#    echo "Usage: bash /bioinformatics/Covid/postCecret_CL.sh <run_name>"
#    echo "Example: bash /bioinformatics/Covid/postCecret_CL.sh TX-CL001-240820"
#    exit 0
#fi

# Variables
basedir="/bioinformatics/Covid"
run_name=$1
run_dir="${basedir}/cecret_runs/${run_name}"
result="${run_dir}/cecret/cecret_results.txt"
demo="${run_dir}/download/demo_${run_name}.txt"
postCecret_script=$2
postCecret_R_script="${basedir}/postCecret_CL.R"
convert_results_script="${basedir}/convert_results.py"
authors=$(head "${basedir}/template/authors.txt")
log_file="${run_dir}/${run_name}.postCecret.log"
aws_bucket=$3

# Set up logging
exec > >(tee -a "$log_file") 2>&1

echo "=== Running ${postCecret_script} for ${run_name} ==="
date
echo

# Check if cecret_results.txt exists
echo "Checking if cecret_results.txt was generated..."
if [[ -f "${result}" ]]; then
    echo "cecret_results.txt found."
    echo "-----------------------------------------------------------"
else
    echo "ERROR: cecret_results.txt not found."
    exit 1
fi
echo

# Remove Clear Labs suffix from Sample_ID
python3 "${convert_results_script}" "${result}" "${result}.tmp"

# Post-processing with R
Rscript "${postCecret_R_script}" "${run_name}"

################################################################################################
# SRA FASTA SUBMISSION
################################################################################################

# Remove existing fasta consensus
rm -f "${run_dir}/${run_name}.fasta"

# Generate consensus fasta
fasta_dir="${run_dir}/reads"
while IFS=$'\t' read -r -a line; do
    if [[ -f "${fasta_dir}/${line[0]}.fasta" ]]; then
        sed "s/>.*/>${line[1]}\/${line[2]}/g" "${fasta_dir}/${line[0]}.fasta" \
            | sed 's/>/>hCoV-19\/USA\//g' \
            > "${fasta_dir}/${line[0]}.fa.tmp"
        cat "${fasta_dir}/${line[0]}.fa.tmp" >> "${run_dir}/${run_name}.fasta"
        rm "${fasta_dir}/${line[0]}.fa.tmp"
    fi
done < "${run_dir}/${run_name}_SRA_fasta_samples_to_submit.txt"

# Modify SRA attribute file
tail -n +2 "${run_dir}/${run_name}_SRA_attribute_submission.txt" > "${run_dir}/tmp.txt"
rm "${run_dir}/${run_name}_SRA_attribute_submission.txt"
cat "${basedir}/template/attribute_template.txt" "${run_dir}/tmp.txt" \
    > "${run_dir}/${run_name}_SRA_attribute_submission.txt"
rm "${run_dir}/tmp.txt"

################################################################################################
# SRA FASTQ SUBMISSION
################################################################################################

# Prepare SRA_fastq directory
rm -rf "${run_dir}/SRA_fastq"
mkdir -p "${run_dir}/SRA_fastq"

# Copy fastq files
while IFS=$'\t' read -r -a line; do
    if compgen -G "${run_dir}/fastq/${line[0]}.*.fastq" > /dev/null; then
        cp "${run_dir}/fastq/${line[0]}."*.fastq "${run_dir}/SRA_fastq/"
    fi
done < "${run_dir}/${run_name}_SRA_fastq_samples_to_submit.txt"

################################################################################################
# CLEANUP
################################################################################################

rm -rf "${run_dir}/work"
rm -f "${run_dir}/${run_name}_SRA_fasta_samples_to_submit.txt"
rm -f "${run_dir}/${run_name}_SRA_fastq_samples_to_submit.txt"

################################################################################################
# ZIP & UPLOAD TO AWS S3
################################################################################################

# Remove old zip
rm -f "${basedir}/cecret_runs/zip_files/postCecret_${run_name}.zip"

# Zip results
echo "Zipping postCecretPipeline output files..."
zip -rj "${basedir}/cecret_runs/zip_files/postCecret_${run_name}" "${run_dir}/${run_name}"*

# Upload to S3
echo "Uploading to AWS S3..."
aws s3 cp "${basedir}/cecret_runs/zip_files/postCecret_${run_name}.zip" \
    "${aws_bucket}/cecret_runs/zip_files/postCecret_${run_name}.zip"

echo "=== ${postCecret_script} completed successfully ==="
