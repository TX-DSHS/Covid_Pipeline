#!/bin/bash
set -euo pipefail

#################################################################################
# Name: runCecret_CL.sh
# Description: Run the Cecret pipeline on Clear Labs runs on the DSHS AWS server.
# Usage: bash /bioinformatics/Covid/runCecret_CL.sh <run_name>
# Example: bash /bioinformatics/Covid/runCecret_CL.sh TX-CL001-240820
# Author: Richard (Stephen) Bovio
# Contact: richard.bovio@dshs.texas.gov
# Created: ???
# Last updated: 2025-08-14
#################################################################################

# Create variables
install_dir="/bioinformatics/Covid"
run_name="$1"
basedir="${install_dir}/cecret_runs/${run_name}"
runCecret_script="runCecret_CL.sh"
postCecret_script="postCecret_CL.sh"
create_samplesheet_script="create_samplesheet.R"
authors=$(head "${install_dir}/template/authors.txt")
aws_bucket="s3://430118851772-covid-19"

# Prepare directories
rm -rf "${basedir}"
mkdir -p "${basedir}" "${basedir}/download" "${basedir}/reads" "${basedir}/fastq"

# Set up logging (log to file + console)
log_file="$basedir/run_Cecret.log"
exec > >(tee -a "$log_file") 2>&1

echo "=== Starting ${runCecret_script} for ${run_name} ==="
date
echo

# Activate conda environment
source /bioinformatics/miniconda3/etc/profile.d/conda.sh
conda activate covid

echo "Conda environment 'covid' activated."
echo

# Download run data from AWS S3
aws s3 cp "${aws_bucket}/DATA/RAW_RUNS/${run_name}.zip" "${basedir}/download/"

echo "Checking if data was successfully copied..."
if [[ ! -f "${basedir}/download/${run_name}.zip" ]]; then
    echo "ERROR: ${run_name}.zip not found in S3 or copy failed."
    exit 1
fi
echo "${run_name}.zip successfully found."
echo

# Extract files
unzip -j "${basedir}/download/${run_name}.zip" -d "${basedir}/download/"
tar -xvf "${basedir}/download/"*.fastqs.tar -C "${basedir}/fastq"
tar -xvf "${basedir}/download/"*.fastas.tar -C "${basedir}/reads"

# Fix filenames with spaces
cd "${basedir}/reads"
# for f in *\ *; do mv "$f" "${f// /_}"; done

# Remove trailing blank line from demo file
remove_trailing_blank_line() {
    local file="${install_dir}/cecret_runs/$1/download/demo_$1.txt"
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File '$file' does not exist."
        exit 1
    fi
    sed -i ':a;/^[[:space:]]*$/{$d;N;ba}' "$file"
    echo "Trailing blank line removed from '$file'."
}
remove_trailing_blank_line "${run_name}"

# Create samplesheet
ls > samples.txt
sed -i '/VERSION.txt/d;/samples.txt/d;s/.fasta//g' samples.txt
cd "${install_dir}"
Rscript "${create_samplesheet_script}" "${run_name}" "${basedir}/reads/samples.txt"

# Pull latest Cecret
rm -rf ~/.nextflow/assets/UPHL-BioNGS/Cecret
nextflow pull UPHL-BioNGS/Cecret

# Run Cecret
echo "Running Cecret Pipeline..."
cd "${basedir}"
if ! nextflow run UPHL-BioNGS/Cecret -profile docker \
        --fastas "${basedir}/reads" \
        --sample_sheet "${install_dir}/samplesheets/${run_name}_samplesheet.csv"
then
    echo "ERROR: Cecret pipeline failed."
    exit 1
fi
echo "Cecret pipeline completed successfully."
echo

# Run post-processing
bash "${install_dir}/${postCecret_script}" "${run_name}" "${postCecret_script}" "${aws_bucket}"
# bash ${install_dir}/postCecret_CL.sh ${run_name} ${postCecret_script} ${aws_bucket}

# Deactivate conda
conda deactivate
echo "${runCecret_script} completed at $(date)"
