#!/bin/sh

######################################################################################################################################################
#
# Title: postCecretPipeline_CL_sb.sh
#
# Description: This script creates post analysis files for SRA and GISAID submission. 
#
# Usage: bash postCecretPipeline_CL_sb.sh <run_name> [-h]
# Example: bash /bioinformatics/Covid_Pipeline/postCecretPipeline_CL_sb.sh TX-CL001-240820
#
# Author: Richard (Stephen) Bovio
# Author Contact: richard.bovio@dshs.texas.gov
# Date created: 2024-09-04
# Date last updated: 2025-03-18
#
######################################################################################################################################################

# If no arguments are provided OR the <run_name> == '-h'
if [ $# -eq 0 -o "$1" == "-h" ] ; then
  echo "No arguments provided"
  echo "Usage: bash /bioinformatics/Covid_Pipeline/postCecretPipeline_CL_sb.sh <run_name>"
  echo "Example: bash /bioinformatics/Covid_Pipeline/postCecretPipeline_CL_sb.sh TX-CL001-240820"
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

# Activate conda environment
echo "Activating conda environment..." 2>&1 | tee -a $run_dir/$1.postCecret.log
echo ""  2>&1 | tee -a $run_dir/$1.postCecret.log
source /bioinformatics/Covid_Pipeline/miniconda3/etc/profile.d/conda.sh
conda activate covid

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

Rscript /bioinformatics/Covid_Pipeline/postCecretPipeline_CL_linux.R $1


######################################################################################################################################################
######################################################## PROCESS RESULTS #############################################################################
######################################################################################################################################################
######################################################################################################################################################
###################################################### REPLACE WITH R SCRIPT #########################################################################
######################################################################################################################################################

# Generate short file (5 columns):
# 1-sample_id  sample	pangolin_lineage  num_N	
# 5-pangolin_qc_status

#awk -F '\t' '{print $1, $2, $3, $7, $25}' OFS="\t" $result > $result.short
#
## Generate failed file (1 column; contains only failed samples):
## 1-sample_id
#sed 1d $result.short | awk -F '\t' '$5=="fail" || $4>=15000 {print $1}' - | sort > $result.failed
#
## Genereate status file (2 columns):
## 1-sample_id  status
#sed 1d $result.short | awk -F '\t' '{if($4<15000 && $5=="pass" ){ print $1"\tComplete" } else {print $1"\tFailed"} }' - > $result.status
#
## Generate demo file by joining short and uploaded demo file (13 columns)
#join -1 1 -2 1 -a2 <( sed 1d $result.short | sort ) <( sort $demo ) -t $'\t' | sort -t '-' -k3n - > $result.demo
#
## Generate demo file by joining status and uploaded demo file (14 columns)
#join -1 1 -2 1 -a2 <( sort $result.status ) <( sort $result.demo ) -t $'\t' | sort -t '-' -k3n -  > $result.demo.status
#
## Remove status header
#sed 1d $result.demo.status > $result.demo.status.tmp
#
## Generate demo.status.final (14 columns)
## Change Sex to unknown if 0, County to empty if 0
#awk -F '\t' '{ $11 = ($11 == "0" ? "unknown" : $11) } 1' OFS="\t" $result.demo.status.tmp |  awk -F '\t' '{ $13 = ($13 == "0" ? "" : $13) } 1' OFS="\t" \
# > $result.demo.status.final
#
## Generate exclude file (1 column; contains only Positive/Negative controls)
#awk -F '\t' '$8 ~ /Positive/ || $8 ~ /Negative/ || $8 ~ /PT/ {print $1}' $result.demo.status.final | sort > $result.exclude
#
## Generate filtered file (1 column; contains only passing samples, minus Positive/Negative/PT controls)
## 1-sample_ID
#sed 1d $result.short | awk -F '\t' '$5=="pass" && $4<15000 {print $1}' - | sort | grep -f $result.exclude -v - | sort > $result.filtered
#
## Generate filtered.year file (2 columns, contains only passing samples, minus Positive/Negative/PT controls)
## 1-sample_ID  year
#grep -f $result.filtered $result.demo.status.final | awk -F '\t' -v OFS='\t' '{print $1,substr($10, 0, 4)}' - > $result.filtered.year


######################################################################################################################################################
###################################################### END OF PROCESSING RESULTS #####################################################################
######################################################################################################################################################







######################################################################################################################################################
###################################################### CREATE SRA METADATA ###########################################################################
######################################################################################################################################################
######################################################################################################################################################
###################################################### REPLACE WITH R SCRIPT #########################################################################
######################################################################################################################################################

# SRA_metadata table (17 columns):
# 1-sample_name  library_ID  title  library_strategy
# 5-library_source  library_selection  library_layout  platform  instrument_model
# 10-design_description  filetype  filename  filename2  filename3
# 15-filename4  assembly  fasta_file

## This creates an output file ($result.fastqnames) which will contain unique, sorted entries of sample IDs and their corresponding filenames in a tab-separated format for all samples sequenced in the run.
#ls -1 $run_dir/fastq/*.fastq | xargs -n 1 basename -s .fastq | awk -F '_' -v OFS='\t' '{ print $1, $1".fastq" }' | sort | uniq > $result.fastqnames
#
## The resulting file $result.demo.status.sra will contain the joined data, with all entries from the $result.demo.status.final file, sorted by the 3rd field in the context of hyphen-separated values.
#join -1 1 -2 3 -a2 <( sort $result.fastqnames ) <( sort $result.demo.status.final ) -t $'\t' | sort -t '-' -k3n - > $result.demo.status.sra
#
## Generate SRA_metadata file for SRA submission, filtering out unwanted entries and combining them with a predefined template.
#awk -F '\t' -v OFS='\t' '{ print $3,$3,"PCR Tiled Amplification of SARS-CoV-2","AMPLICON","VIRAL RNA","PCR","single","OXFORD_NANOPORE","MinION","Clear Dx SARS-CoV-2 WGS v3.0","fastq",$2,"","","","","" }' $result.demo.status.sra | grep -f $result.failed -v - | grep -f $result.exclude -v - | cat $basedir'//template/SRA_metadata_template.txt' - > $run_dir/$1'_SRA_metadata_submission.txt'

######################################################################################################################################################
###################################################### END OF SRA METADATA #####################################################################
######################################################################################################################################################

# Remove pre-existing fastq files from $run_dir/SRA_fastq
if [ -e $run_dir/SRA_fastq ]; then 
  rm -r $run_dir/SRA_fastq
fi
mkdir $run_dir/SRA_fastq

# Collect fastq files to be submitted
# This reads each line from a metadata file ($run_dir/$1_SRA_metadata_submission.txt), checks if a file specified by the 12th field (filename) of the line exists in a source directory ($run_dir/fastq/), and if it does, copies that file to a destination directory ($run_dir/SRA_fastq/).
while IFS=$'\t' read -r -a line
do
  if [ -e $run_dir/fastq/${line[11]} ]; then
    cp $run_dir/fastq/${line[11]} $run_dir/SRA_fastq/
  fi
done < $run_dir/$1'_SRA_metadata_submission.txt'


######################################################################################################################################################
###################################################### CREATE SRA ATTRIBUTE ##########################################################################
######################################################################################################################################################
######################################################################################################################################################
###################################################### REPLACE WITH R SCRIPT #########################################################################
######################################################################################################################################################

# Bioattibute table (49 fields):
# 1-*sample_name	sample_title	bioproject_accession	*organism
#	5-strain	*collected_by	*collection_date	*geo_loc_name	*host
#	10-*host_disease	*isolate	*isolation_source	antiviral_treatment_agent	collection_device
#	15-collection_method	date_of_prior_antiviral_treat	date_of_prior_sars_cov_2_infection	date_of_sars_cov_2_vaccination	exposure_event
#	20-geo_loc_exposure	gisaid_accession	gisaid_virus_name	host_age	host_anatomical_material
#	25-host_anatomical_part	host_body_product	host_disease_outcome	host_health_state	host_recent_travel_loc
#	30-host_recent_travel_return_date	host_sex	host_specimen_voucher	host_subject_id	lat_lon	passage_method
#	35-passage_number	prior_sars_cov_2_antiviral_treat	prior_sars_cov_2_infection	prior_sars_cov_2_vaccination
#	40-purpose_of_sampling	purpose_of_sequencing	sars_cov_2_diag_gene_name_1	sars_cov_2_diag_gene_name_2	sars_cov_2_diag_pcr_ct_value_1
#	45-sars_cov_2_diag_pcr_ct_value_2	sequenced_by	vaccine_received	virus_isolate_of_prior_infection  description

## Generate the attributes file for SRA submission, filtering out unwanted entries and combining them with a predefined template.
#awk -F '\t' -v OFS='\t' '{ print $1,"","PRJNA639066","Severe acute respiratory syndrome coronavirus 2","SARS-CoV-2/USA/"$1"/"substr($10,0,4),"Texas Department of State Health Services",$10,"USA: Texas","Homo sapiens","COVID-19","missing",$12,"","","","","","","","","","hCoV-19/USA/"$1"/"substr($10,0,4),"","","","","","","","",$11,"","","missing","","","","","","",$14,"","","","","TXDSHS","","",""}' $result.demo.status.final | awk -F '\t' '{ $49 = (tolower($41) == "vaccine breakthrough" ? "VBC" : "") } 1' OFS="\t" | awk -F '\t' '{ $41 = (tolower($41) == "surveillance" ? "Baseline surveillance (random sampling)" : "") } 1' OFS="\t" | grep -f $result.failed -v - | grep -f $result.exclude -v - | cat $basedir'/template/attribute_template.txt' - > $run_dir/$1_attribute_submission.txt

######################################################################################################################################################
###################################################### END OF SRA ATTRIBUTE ##########################################################################
######################################################################################################################################################














######################################################################################################################################################
###################################################### CREATE GISAID #################################################################################
######################################################################################################################################################
######################################################################################################################################################
###################################################### REPLACE WITH R SCRIPT #########################################################################
######################################################################################################################################################


# GISAID file (30 fields):
# 1 submitter  fn  covv_virus_name  covv_type
# 5 covv_passage  covv_collection_date  covv_location  covv_add_location  covv_host
# 10 covv_add_host_info  covv_sampling_strategy  covv_gender  covv_patient_age  covv_patient_status
# 15 covv_specimen  covv_outbreak  covv_last_vaccinated  covv_treatment  covv_seq_technology
# 20 covv_assembly_method  covv_coverage  covv_orig_lab  covv_orig_lab_addr  covv_provider_sample_id
# 25 covv_subm_lab  covv_subm_lab_addr  covv_subm_sample_id  covv_authors  covv_comment comment_type

# Generate the GISAID csv for GISAID submission, filtering out unwanted entries and combining them with a predefined template.
#awk -F '\t' -v OFS=',' -v runname="$1" -v authors="$authors" '{ \
#print "TXWGS",$3".fasta","hCoV-19/USA/"$1"/"substr($10,0,4),"betacoronavirus","Original",\
#$10,"North America/ USA/ Texas/ "$13,"unknown","Human","",\
#$14,$11,"unknown","unknown",$12,\
#"unknown","unknown","unknown","OXFORD NANOPORE MinION","Minimap2/Medaka",\
#"","TXDSHS","\"1100 W 49th Street, Austin TX 78756\"","","TXDSHS",\
#"\"1100 W 49th Street, Austin TX 78756\"","",authors,"",""}' $result.demo.status.final |\
#
#awk -F ',' '{ $10 = (tolower($11) == "vaccine breakthrough" ? "VBC" : "") } 1' OFS="," |\
#awk -F ',' '{ $11 = (tolower($11) == "surveillance" ? "Baseline surveillance": "") } 1' OFS="," |\
#sed 's/: Version: //g' | sed 's/version //g' |\
#grep -f $result.failed -v - | grep -f $result.exclude -v - |\
#cat $basedir'/template/GISAID_submission_template.csv - \
# > $run_dir/$1_gisaid_submission.csv

# Remove pre-existing fasta consensus files
if [ -e $run_dir/$1.fasta ]; then
  rm $run_dir/$1.fasta 
fi

# Generate consensus fasta file
fasta_dir=$run_dir/reads

while IFS=$'\t' read -r -a line
do
  if [ -e $fasta_dir/${line[0]}.*.fasta ]; then
	  sed  "s/>.*/>${line[0]}\/${line[1]}/g" $fasta_dir/${line[0]}.*.fasta | sed  's/>/>hCoV-19\/USA\//g' > $fasta_dir/${line[0]}.fa.tmp
    cat $fasta_dir/${line[0]}.fa.tmp >> $run_dir/$1.fasta
	  rm $fasta_dir/${line[0]}.fa.tmp
  fi
done < $run_dir/$1'_SRA_fastq_submission.txt'

 
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################


# runlist (8 fields):
# 1 TEXAS-DSHS  Sequencing_run  DSHS_id  Completed/Failed
# 5 Lineage  num_N  Pangolin_status C/FComments
#echo -e "TEXAS_DSHS\tSequencing_Run\tSequencing_ID\tSample_Type\tLineage\tnum_N\tPangolin_Status\tPangolin_Status_Comments" > $run_dir/$1.runlist.txt
#awk -F '\t' -v OFS='\t' '{ print $1,$7,$8,$2,$4,$5,$6  }' $result.demo.status.final | grep -v 'Undetermined' |\
#awk -F '\t' -v OFS='\t' '{ if($7=="fail") $8="Failed QC"; else $8="";print $0 } ' |\
#awk -F '\t' -v OFS='\t' '{ if($7=="pass" && $6>15000) $8="N>15000";print $0 } '|\
#awk -F '\t' -v OFS='\t' '{ if ($3 ~ /Positive/ || $3 ~ /Negative/ || $3 ~ /PT/) $4="Control";print $0}' |\
#awk -F '\t' -v OFS='\t' '{ if ($3 ~ /Positive/ || $3 ~ /Negative/ || $3 ~ /PT/) $8="";print $0}' \
# >> $run_dir/$1.runlist.txt


######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################
######################################################################################################################################################


## Print Run Summary
#Total=`grep -f $result.exclude -v $result.demo.status.final | grep -v 'Undetermined' | wc -l`
#NComplete=`awk -F '\t' '$2=="Complete" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' | wc -l`
#Nfail=`awk -F '\t' '$2=="Failed" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' | wc -l`
#
## Total # Passed/Failed clinical samples
#echo "Total number of clinical samples: $Total" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "# Passed clinical samples: $NComplete" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "# Failed clinical samples: $Nfail" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo -e "-----------------------------------------------------------\n" 2>&1 | tee -a $run_dir/$1.postCecret.log
#
## Passed clincial samples
#echo "Passed clinical samples:" 2>&1 | tee -a $run_dir/$1.postCecret.log
#printf "%-15s %-18s %-10s %-10s\n" "TX-DSHS_id" "pangolin_status" "coverage" "numN" 2>&1 | tee -a $run_dir/$1.postCecret.log
#awk -F '\t' '$2=="Complete" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' > $result.passed.samples
#grep -f $result.passed.samples $result.demo.status.final | awk -F '\t' '{printf "%-15s %-18s %-10s %-10s\n", $1, $6, "NA", $5}' 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo -e "-----------------------------------------------------------\n" 2>&1 | tee -a $run_dir/$1.postCecret.log
#
## Failed cilincal samples
#echo "Failed clinical samples:" 2>&1 | tee -a $run_dir/$1.postCecret.log
#printf "%-15s %-18s %-10s %-10s\n" "TX-DSHS_id" "pangolin_status" "coverage" "numN" 2>&1 | tee -a $run_dir/$1.postCecret.log
#awk -F '\t' '$2=="Failed" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' > $result.failed.samples
#grep -f $result.failed.samples $result.demo.status.final | awk -F '\t' '{printf "%-15s %-18s %-10s %-10s\n", $1, $6, "NA", $5}' 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo -e "-----------------------------------------------------------\n" 2>&1 | tee -a $run_dir/$1.postCecret.log
#
## Controls
#echo "Controls -- Removed from submission files:" 2>&1 | tee -a $run_dir/$1.postCecret.log
#printf "%-15s %-25s %-10s\n" "TX-DSHS_id" "DSHS_ID" "Status" 2>&1 | tee -a $run_dir/$1.postCecret.log
#awk -F '\t' '{printf "%-15s %-25s %-10s\n", $1,$8,$2}' $result.demo.status.final | grep -f $result.exclude | grep -v 'Undetermined' 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo -e "-----------------------------------------------------------\n" 2>&1 | tee -a $run_dir/$1.postCecret.log
#
## Samples for submission
#echo "# samples in SRA_metadata_submission file: "`sed 1d $run_dir/$1_SRA_metadata_submission.txt | wc -l` 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "# samples in SRA bioattibute file: "`sed 1d $run_dir/$1_attribute_submission.txt | grep 'TX-DSHS' | wc -l`  2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "# sequences in fasta consensus file: "`grep -c '>' $run_dir/$1.fasta` 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "# samples in GISAID csv: "`sed 1d $run_dir/$1_gisaid_submission.csv | wc -l` 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "See $1.runlist.txt for detailed results." 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log
#
## Remove work directory and temporary files
#echo "Removing work directory and temporary files" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log
rm -r $run_dir/work
#rm $result.tmp
#rm $result.status
#rm $result.short
#rm $result.exclude
#rm $result.fastqnames
#rm $result.filtered*
#rm $result.failed*
#rm $result.passed*
#rm $result.demo*
#
## Remove pre-existing postCecret zip results
#if [ -e $basedir/cecret_runs/zip_files/postCecret_$1.zip ]; then
#  rm $basedir/cecret_runs/zip_files/postCecret_$1.zip
#fi
#
## Zip and copy postCecret results to AWS S3
#echo "Zipping postCecretPipeline output files" 2>&1 | tee -a $run_dir/$1.postCecret.log
#zip -rj $basedir/cecret_runs/zip_files/postCecret_$1 $run_dir/$1*
#echo "" 2>&1 | tee -a $run_dir/$1.postCecret.log
#echo "Transferring postCecretPipeline output files to AWS S3" 2>&1 | tee -a $run_dir/$1.postCecret.log
#aws s3 cp $basedir/cecret_runs/zip_files/postCecret_$1.zip s3://804609861260-covid-19/cecret_runs/zip_files/postCecret_$1.zip
