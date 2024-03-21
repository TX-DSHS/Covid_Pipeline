#!/bin/bash      
version="postCecretPipeline version 2.0 for Clear Labs"
#title          postCecretPipeline_CL.sh
#description    
#author         Jie.Lu@dshs.texas.gov
#date           20230925
#usage          bash postCecretPipeline_CL.sh <RUN_NAME> <SampleDemo.txt> <Primer (default=Artic protocol V3)>[-h]
#format         SampleDemo.txt header (tab-delimited)
# 1-TEXAS-DSHS####	2-Run name	3-DSHS ID	4-Complete/Failed	5-final_collection_date_text	6-final_sex	7-final_source	8-Final_County	9-Reason_for_Sequencing

authors=$(head authors.txt)

#==============================================================================
if [ $# -eq 0 -o "$1" == "-h" ] ; then

	echo "Usage: `basename $0` <RUN_NAME> <SampleDemo.txt (tab-delimited default=demo.txt)> <Primer (default=Artic protocol V3)>[-h]"
	echo "Note:   Please copy Column A to I from all_samples tab of the populated RUN_NAME_demos.xlsx file"
    echo "Note:   SampleDemo.txt header(tab-delimited)"
    echo "1-TEXAS-DSHS####	2-Run name	3-DSHS ID	4-Complete/Failed	5-final_collection_date_text	6-final_sex	7-final_source	8-Final_County	9-Reason_for_Sequencing"
	exit 0
fi
	
run_dir=$PWD/cecret_runs/$1
echo $run_dir
result=$run_dir'/cecret/cecret_results.txt'
SampleDemo='demo_'$1.txt
primer=$3

if [ -e $result ]; then
    echo "Processing run result of "$1
else
    echo "Error: No Cecret run result found for "$1
	exit 1
fi
	
if [ "$3" == "" ] ; then
    primer="Midnight 1200 PCR-tiling of SARS-CoV-2 cDNA"
fi

if [ -e $SampleDemo ]; then
   echo "The Demo File is: "$SampleDemo
   dos2unix $SampleDemo
else
   echo "Error: No Demo file Found. Please provide the demo file."
   exit 1
fi


#################################################################
# mark the status of sample with "Complete" or "failed"
echo "Running "$version 2>&1 | tee $run_dir/$1.postCecret.log
echo `date` 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "##################################################################################################" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "Processing "$1"..." 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "Primer set: "$primer 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "##################################################################################################" 2>&1 | tee -a $run_dir/$1.postCecret.log

# result.short
# 1- sample_id,2-sample, 3-num_N, 4-pangolin_QC, 5-pangolineage
awk -F '\t' '{print $1, $2, $7, $25, $3}' OFS="\t" $result > $result.short
sed 1d $result.short | awk -F '\t' '$2=="Undetermined" || $4=="fail" || $3>=15000 {print $2}' - | sort > $result.failed
sed 1d $result.short | awk -F '\t' '$2=="Undetermined" || $4=="NA" || $3>=15000 {print $2}' - | sort >> $result.failed
sed 1d $result.short | awk -F '\t' '{if($2!="Undetermined" && $3<15000 && $4=="pass" ){ print $2"\tComplete" } else {print $2"\tFailed"} }' - > $result.status

#################################################################
# Generate compiled and all sample tables $result.demo
join -1 1 -2 1 -a1 <( sort $SampleDemo ) <( sed 1d $result.short | sort ) -t $'\t' | sort -t '-' -k3n - > $result.demo
# $result.demo header

# 1-Run name	#2-Run_name 3-DSHS ID	4-Complete/Failed	5-final_collection_date_text	6-final_sex	
# 7-final_source	8-Final_County	9-Reason_for_Sequencing 
# 10-sample_id   11-num_N 12-pangolin_QC #13-pangoLineage 

join -1 1 -2 1 -a1 <( sort $result.status ) <( sort $result.demo ) -t $'\t' | sort -t '-' -k3n -  > $result.demo.status

# 1-sample_id   2-QC_status    
# 3-Run_name 4-DSHS_ID	5-Complete/Failed	6-final_collection_date_text	7-final_sex	
# 8-final_source	9-Final_County	10-Reason_for_Sequencing
# 11-sample  12-num_N   13-pangolin_status  14-pangoLineage

# Change Sex to unknown if 0, County to empty if 0

awk -F '\t' '{ $7 = ($7 == "0" ? "unknown" : $7)}1' OFS="\t" $result.demo.status |  awk -F '\t' '{ $9 = ($9 == "0" ? "" : $9) } 1 ' OFS="\t" \
 > $result.demo.status.final

# Exclude Positive/Negative controls
awk -F '\t' '$4 ~ /Positive/ || $4 ~ /Negative/ {print $1}' $result.demo.status.final | sort > $result.exclude

# ###############################################################
# Combine complete samples to one fasta consensus file(minus Undetermined, Positive/Negative Controls) 
if [ -e $result.filtered ];
then
rm $result.filtered
fi

sed 1d $result | awk -F '\t' '$2!="Undetermined" && $25=="pass" && $7<15000 {print $1}' - | sort | grep -f $result.exclude -v - | sort > $result.filtered
# Colletion year
grep -f $result.filtered $result.demo.status.final | awk -F '\t' -v OFS='\t' '{print $1,substr($6, 0, 4)}' - > $result.filtered.year

if [ -e $run_dir/$1.fasta ];
then
rm $run_dir/$1.fasta
fi

fasta_dir=$run_dir/reads
while IFS=$'\t' read -r -a line
do
  if [ -e $fasta_dir/${line[0]}.fasta ];
  then
	sed  "s/>.*/>${line[0]}\/${line[1]}/g" $fasta_dir/${line[0]}.fasta > $fasta_dir/${line[0]}.fa.tmp
    cat $fasta_dir/${line[0]}.fa.tmp >> $run_dir/$1.fasta
	rm $fasta_dir/${line[0]}.fa.tmp
  fi
done < $result.filtered.year

# Generate txt files for SRA submission and GISAID
###############################################################
# demo.status.final
# 1-sample_id   2-QC_status    
# 3-Run_name 4-DSHS_ID	5-Complete/Failed	6-final_collection_date_text	7-final_sex	
# 8-final_source	9-Final_County	10-Reason_for_Sequencing
# 11-sample  12-num_N   13-pangolin_status  14-pangoLineage

# SRA_metadata table 17 fields
# 1-sample_name	library_ID	title	library_strategy	5-library_source	library_selection	library_layout	platform	instrument_model	10-design_description	filetype	filename	filename2	filename3	15-filename4	assembly	17-fasta_file
ls -1 $run_dir/fastq/*.fastq | xargs -n 1 basename -s .fastq|\
awk -F '_' -v OFS='\t' '{ print $1, $1".fastq" }' | sort | uniq > $result.fastqnames
join -1 1 -2 1 -a1 <( sort $result.demo.status.final ) <( sort $result.fastqnames ) -t $'\t' | sort -t '-' -k3n - > $result.demo.status.sra

awk -F '\t' -v OFS='\t' -v primer="$primer" -v file=$result.fastqnames '{ print $1,$1,"PCR Tiled Amplification of SARS-CoV-2","AMPLICON","VIRAL RNA","PCR","single","OXFORD_NANOPORE","MinION",\
"Clear Dx SARS-CoV-2 WGS v3.0","fastq",$15,"","","","","",""}' $result.demo.status.sra | \
grep -f $result.failed -v - | grep -f $result.exclude -v - | cat template/SRA_metadata_template.txt - > $run_dir/$1_SRA_metadata.txt
#$15-- fastq

# Collect fastq files to be submitted
if [ -e $run_dir/SRA_fastq ];
then 
  rm -r $run_dir/SRA_fastq
fi
mkdir $run_dir/SRA_fastq

while IFS=$'\t' read -r -a line
do
  #echo ${line[11]}, ${line[12]}
  if [ -e $run_dir/fastq/${line[11]} ];
  then
    cp $run_dir/fastq/${line[11]} $run_dir/SRA_fastq/
  fi
done < $run_dir/$1_SRA_metadata.txt

# #################################################################
# Bioattibute table 49 fields
# 1-*sample_name	sample_title	bioproject_accession	*organism	5-strain	*collected_by	*collection_date	*geo_loc_name	*host	10-*host_disease	*isolate	*isolation_source	antiviral_treatment_agent	collection_device	15-collection_method	date_of_prior_antiviral_treat	date_of_prior_sars_cov_2_infection	date_of_sars_cov_2_vaccination	exposure_event	20-geo_loc_exposure	gisaid_accession	gisaid_virus_name	host_age	host_anatomical_material	25-host_anatomical_part	host_body_product	host_disease_outcome	host_health_state	host_recent_travel_loc	30-host_recent_travel_return_date	host_sex	host_specimen_voucher	host_subject_id	lat_lon	passage_method	35-passage_number	prior_sars_cov_2_antiviral_treat	prior_sars_cov_2_infection	prior_sars_cov_2_vaccination	40-purpose_of_sampling	purpose_of_sequencing	sars_cov_2_diag_gene_name_1	sars_cov_2_diag_gene_name_2	sars_cov_2_diag_pcr_ct_value_1	45-sars_cov_2_diag_pcr_ct_value_2	sequenced_by	vaccine_received	virus_isolate_of_prior_infection	49-description
awk -F '\t' -v OFS='\t' '{ print $1,"","PRJNA639066","Severe acute respiratory syndrome coronavirus 2","SARS-CoV-2/USA/"$1"/"substr($6,0,4),\
"Texas Department of State Health Services",$6,"USA: Texas","Homo sapiens","COVID-19","missing",$8,"","","","","","","","","",\
"hCoV-19/USA/"$1"/"substr($6,0,4),"","","","","","","","",$7,"","","missing","","","","","","",$10,"","","","","TXDSHS","","",""}' $result.demo.status.final |\
awk -F '\t' '{ $49 = (tolower($41) == "vaccine breakthrough" ? "VBC" : "") } 1' OFS="\t" |\
awk -F '\t' '{ $41 = (tolower($41) == "surveillance" ? "Baseline surveillance (random sampling)" : "") } 1' OFS="\t" |\
grep -f $result.failed -v - | grep -f $result.exclude -v - | cat template/attribute_template.txt - \
> $run_dir/$1_attribute.txt

# demo.status.final
# 1-sample_id   2-QC_status    
# 3-Run_name 4-DSHS_ID	5-Complete/Failed	6-final_collection_date_text	7-final_sex	
# 8-final_source	9-Final_County	10-Reason_for_Sequencing
# 11-sample  12-num_N   13-pangolin_status  14-pangoLineage

#################################################################
# GISAID csv 30 fields
# 1-submitter,fn,covv_virus_name,covv_type,5-covv_passage,covv_collection_date,covv_location,covv_add_location,covv_host,10-covv_add_host_info,covv_sampling_strategy,covv_gender,covv_patient_age,covv_patient_status,15-covv_specimen,covv_outbreak,covv_last_vaccinated,covv_treatment,covv_seq_technology,20-covv_assembly_method,covv_coverage,covv_orig_lab,covv_orig_lab_addr,covv_provider_sample_id,25-covv_subm_lab,covv_subm_lab_addr,covv_subm_sample_id,covv_authors,covv_comment,30-comment_type

awk -F '\t' -v OFS=',' -v runname="$1" -v authors="$authors" '{ \
print "TXWGS",runname".fasta","hCoV-19/USA/"$1"/"substr($6,0,4),"betacoronavirus","Original",\
$6,"North America/ USA/ Texas/ "$6,"","Human","",\
$10,$7,"unknown","unknown",$8,\
"unknown","unknown","unknown","OXFORD NANOPORE MinION","Minimap2/Medaka",\
"","TXDSHS","\"1100 W 49th Street, Austin TX 78756\"","","TXDSHS",\
"\"1100 W 49th Street, Austin TX 78756\"","",authors,"","",\
"","","","",""}' $result.demo.status.final |\

awk -F ',' '{ $10 = (tolower($11) == "vaccine breakthrough" ? "VBC" : "") } 1' OFS="," |\
awk -F ',' '{ $11 = ($11 == "Surveillance" ? "Baseline surveillance": "") } 1' OFS="," |\
sed 's/: Version: //g' | sed 's/version //g' |\
grep -f $result.failed -v - | grep -f $result.exclude -v - |\
cat template/GISAID_submission_template.csv - \
 > $run_dir/$1_gisaid_sub.csv

#################################################################
# runlist 8 fields
#1-TEXAS-DSHS#	2-Sequencing_run	3-DSHS_id	4-Completed/Failed	5-Utah_Lineage	6-num_N	7-Pangolin_status 8-C/FComments
echo "TEXAS-DSHS#	Sequencing_run	DSHS_id	Completed/Failed	Utah_Lineage	num_N	Pangolin_status	C/F_Comments" > $run_dir/$1.runlist.txt
awk -F '\t' -v OFS='\t' '{ print $1,$3,$4,$2,$14,$12,$13  }' $result.demo.status.final | grep -v 'Undetermined' |\
awk -F '\t' -v OFS='\t' '{ if($7=="fail") $8="Failed QC"; else $8="";print $0 } ' |\
awk -F '\t' -v OFS='\t' '{ if($7=="pass" && $6>15000) $8="N>15000";print $0 } '|\
awk -F '\t' -v OFS='\t' '{ if ($3 ~ /Positive/ || $3 ~ /Negative/) $4="Control";print $0}' |\
awk -F '\t' -v OFS='\t' '{ if ($3 ~ /Positive/ || $3 ~ /Negative/) $8="";print $0}' \
 >> $run_dir/$1.runlist.txt

# demo.status.final
# 1-sample_id   2-QC_status(Complete/Failed)    
# 3-Run_name 4-DSHS_ID	5-Complete/Failed(blank)	6-final_collection_date_text	7-final_sex	
# 8-final_source	9-Final_County	10-Reason_for_Sequencing
# 11-sample  12-num_N   13-pangolin_status  14-pangoLineage


################################################################
# Print Run Summary
Total=`grep -f $result.exclude -v $result.demo.status.final | grep -v 'Undetermined' | wc -l`
NComplete=`awk -F '\t' '$2=="Complete" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' | wc -l`
Nfail=`awk -F '\t' '$2=="Failed" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' | wc -l`
echo "Total number of samples: $Total" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "# Passed samples: $NComplete" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "# Failed samples: $Nfail" 2>&1 | tee -a $run_dir/$1.postCecret.log
awk -F '\t' '$5=="Failed" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' > $result.failed.samples
echo "-----------------------------------------------------------" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "Controls -- Removed from submission files:" 2>&1 | tee -a $run_dir/$1.postCecret.log
awk -F '\t' '{print $1,$3,$4}' $result.demo.status.final | grep -f $result.exclude | grep -v 'Undetermined' 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "-----------------------------------------------------------" 2>&1 | tee -a $run_dir/$1.postCecret.log

echo "Failed Samples:" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "-----------------------------------------------------------" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "TX-DSHS_id	pangolin_status	coverage	numN" 2>&1 | tee -a $run_dir/$1.postCecret.log
grep -f $result.failed.samples $result.demo | awk -F '\t' '{print $1, $6, $14, $26}' 2>&1 | tee -a $run_dir/$1.postCecret.log

echo "-----------------------------------------------------------" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "# samples to be submitted in GISAID csv: "`sed 1d $run_dir/$1_gisaid_sub.csv | wc -l` 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "# samples to be submitted in SRA_metadata file: "`sed 1d $run_dir/$1_SRA_metadata.txt | wc -l` 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "# samples in Bioattibute file: "`sed 1d $run_dir/$1_attribute.txt | grep 'TX-DSHS' | wc -l`  2>&1 | tee -a $run_dir/$1.postCecret.log
echo "# seqs in consensus fasta file: "`grep -c '>' $run_dir/$1.fasta` 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "Please see $1.runlist.txt for detailed results" 2>&1 | tee -a $run_dir/$1.postCecret.log

# rm $result.filtered*
# rm $result.status
# rm $result.failed.samples
# rm $result.demo
# rm $result.demo.status
# rm $result.demo.status.final
# rm $result.failed*
# rm $result.exclude
# rm $result.fastqnames
# rm $result.demo.status.sra
# cp $SampleDemo $PWD/old_demos/demos_$1.txt

# if [ -e /home/dnalab/cecret_runs/zipfiles/postCecret_$1.zip ];
# then
# rm /home/dnalab/cecret_runs/zipfiles/postCecret_$1.zip
# fi
# zip -rj /home/dnalab/cecret_runs/zipfiles/postCecret_$1 $run_dir/$1*
# aws s3 cp /home/dnalab/cecret_runs/zipfiles/postCecret_$1.zip s3://804609861260-covid-19/cecret_runs/zip_files/postCecret_$1.zip
