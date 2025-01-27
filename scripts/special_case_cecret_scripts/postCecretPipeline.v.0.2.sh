#!/bin/bash      
version="postCecretPipeline version 0.2"
#title           :postCecretPipeline.sh
#description     :
#author		     :Jie Lu 
#date            :20211008
#usage		     :bash postCecretPipeline.sh <RUN_NAME> <SampleDemo.txt> <Primer (default=Artic protocol V3)>[-h]
#format          :SampleDemo.txt header (tab-delimited)
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
result=$run_dir/'run_results_'$1.txt
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

sed 1d $result | awk -F '\t' '$2=="Undetermined" || $6=="fail" || $14<=20 || $26>=5000 {print $2}' - | sort > $result.failed
sed 1d $result | awk -F '\t' '{if($2!="Undetermined" && $6=="passed_qc" && $14>20 && $26<5000){ print $2"\tComplete" } else {print $2"\tFailed"} }' - > $result.status

#################################################################
# Generate compiled and all sample tables $result.demo
join -1 2 -2 1 -a1 <( sed 1d $result | sort ) <( sort $SampleDemo ) -t $'\t' | sort -t '-' -k3n - > $result.demo
# $result.demo header
#1	2	3	4	5	6	7	8	9	10	11	12	13	14	15	16	17	18	19	20	21	22	23	24	25	26	27	28	29	30	31	32	33	34	35	36	37
#sample_id	sample	aligner_version	ivar_version	pangolin_lineage	pangolin_status	pangolin_scorpio_call	nextclade_clade	fastqc_raw_reads_1	fastqc_raw_reads_2	seqyclean_pairs_kept_after_cleaning	seqyclean_percent_kept_after_cleaning	fastp_reads_passed	depth_after_trimming	1X_coverage_after_trimming	num_pos_10X	insert_size_before_trimming	insert_size_after_trimming	%_human_reads	percent_Severe_acute_respiratory_syndrome_coronavirus_2_reads	ivar_num_variants_identified	bcftools_variants_identified	bedtools_num_failed_amplicons	samtools_num_failed_amplicons	vadr_conclusion	26-num_N	num_degenerage	num_non-ambiguous	num_total	30-Run name	DSHS ID	Complete/Failed	final_collection_date_text	final_sex	35-final_source	Final_County	37-Reason_for_Sequencing



join -1 1 -2 1 -a1 -o 1.1,1.30,1.31,2.2,1.32,1.33,1.34,1.35,1.36,1.14,1.5,1.3,1.4,1.37 <( sort $result.demo ) <( sort $result.status ) -t $'\t' | sort -t '-' -k3n - > $result.demo.status
# $result.demo.status/final header
# 1-sample_id	2-Run_name	3-DSHS_id	4-Status	5-Empty	
# 6-Collection_date	7-Gender	8-Source	9-County	10-Coverage	
# 11-Pangolin_lineage	12-aligner_version 13-ivar_version 14-Reason_for_Sequencing
# Change Sex to unknown if 0, County to empty if 0, truncate coverage to integer


awk -F '\t' '{ $7 = ($7 == "0" ? "unknown" : $7)}1' OFS="\t" $result.demo.status |  awk -F '\t' '{ $9 = ($9 == "0" ? "" : $9) } 1 ' OFS="\t" \
| awk -F '\t' '{$10 = sprintf("%.0f",$10)}1' OFS='\t' > $result.demo.status.final

# Exclude Positive/Negative controls
awk -F '\t' '$3 ~ /Positive/ || $3 ~ /Negative/ {print $1}' $result.demo.status.final | sort > $result.exclude


###############################################################
# Combine complete samples to one fasta consensus file(minus Undetermined, Positive/Negative Controls) 
if [ -e $result.filtered ];
then
rm $result.filtered
fi

sed 1d $result | awk -F '\t' '$2!="Undetermined" && $6=="passed_qc" && $14>20 && $26<5000 {print $2}' - | sort | grep -f $result.exclude -v - | sort > $result.filtered
# Colletion year
grep -f $result.filtered $result.demo.status.final | awk -F '\t' -v OFS='\t' '{print $1,substr($6, 0, 4)}' - > $result.filtered.year

if [ -e $run_dir/$1.fasta ];
then
rm $run_dir/$1.fasta
fi

while IFS=$'\t' read -r -a line
do
  if [ -e $run_dir/cecret/consensus/${line[0]}.consensus.fa ];
  then
	sed  "s/\.consensus_threshold_0.6_quality_20/\/${line[1]}/g" $run_dir/cecret/consensus/${line[0]}.consensus.fa | sed  's/Consensus_/hCoV-19\/USA\//g' > $run_dir/cecret/consensus/${line[0]}.consensus.fa.tmp
    cat $run_dir/cecret/consensus/${line[0]}.consensus.fa.tmp >> $run_dir/$1.fasta
	rm $run_dir/cecret/consensus/${line[0]}.consensus.fa.tmp
  fi
done < $result.filtered.year


# Generate txt files for SRA submission and GISAID
###############################################################
# SRA_metadata table 17 fields
# 1-sample_name	library_ID	title	library_strategy	5-library_source	library_selection	library_layout	platform	instrument_model	10-design_description	filetype	filename	filename2	filename3	15-filename4	assembly	17-fasta_file
ls -1 $run_dir/reads/*.fastq.gz | xargs -n 1 basename |\
awk -F '_' -v OFS='\t' '{ print $1,$1"_"$2"_L001_R1_001.fastq.gz",$1"_"$2"_L001_R2_001.fastq.gz" }' | sort | uniq > $result.fastqnames
join -1 1 -2 1 -a1 <( sort $result.demo.status.final ) <( sort $result.fastqnames ) -t $'\t' | sort -t '-' -k3n - > $result.demo.status.sra

awk -F '\t' -v OFS='\t' -v primer="$primer" -v file=$result.fastqnames '{ print $1,$1,"PCR Tiled Amplification of SARS-CoV-2","AMPLICON","VIRAL RNA","PCR","paired","ILLUMINA","Illumina MiSeq",\
primer,"fastq",$15,$16,"","","",""}' $result.demo.status.sra | \
grep -f $result.failed -v - | grep -f $result.exclude -v - | cat template/SRA_metadata_template.txt - > $run_dir/$1_SRA_metadata.txt
#$15,$16 -- fastq1, fastq2

# Collect fastq files to be submitted
if [ -e $run_dir/SRA_fastq ];
then 
  rm -r $run_dir/SRA_fastq
fi
mkdir $run_dir/SRA_fastq

while IFS=$'\t' read -r -a line
do
  #echo ${line[11]}, ${line[12]}
  if [ -e $run_dir/reads/${line[11]} ];
  then
    cp $run_dir/reads/${line[11]} $run_dir/SRA_fastq/
  fi
  if [ -e $run_dir/reads/${line[12]} ];
  then
    cp $run_dir/reads/${line[12]} $run_dir/SRA_fastq/
  fi	
done < $run_dir/$1_SRA_metadata.txt

#################################################################
# Bioattibute table 49 fields
# 1-*sample_name	sample_title	bioproject_accession	*organism	5-strain	*collected_by	*collection_date	*geo_loc_name	*host	10-*host_disease	*isolate	*isolation_source	antiviral_treatment_agent	collection_device	15-collection_method	date_of_prior_antiviral_treat	date_of_prior_sars_cov_2_infection	date_of_sars_cov_2_vaccination	exposure_event	20-geo_loc_exposure	gisaid_accession	gisaid_virus_name	host_age	host_anatomical_material	25-host_anatomical_part	host_body_product	host_disease_outcome	host_health_state	host_recent_travel_loc	30-host_recent_travel_return_date	host_sex	host_specimen_voucher	host_subject_id	lat_lon	passage_method	35-passage_number	prior_sars_cov_2_antiviral_treat	prior_sars_cov_2_infection	prior_sars_cov_2_vaccination	40-purpose_of_sampling	purpose_of_sequencing	sars_cov_2_diag_gene_name_1	sars_cov_2_diag_gene_name_2	sars_cov_2_diag_pcr_ct_value_1	45-sars_cov_2_diag_pcr_ct_value_2	sequenced_by	vaccine_received	virus_isolate_of_prior_infection	49-description
awk -F '\t' -v OFS='\t' '{ sub("\r", "", $14); print $1,"","PRJNA639066","Severe acute respiratory syndrome coronavirus 2","SARS-CoV-2/USA/"$1"/"substr($6,0,4),\
"Texas Department of State Health Services",$6,"USA: Texas","Homo sapiens","COVID-19","missing",$8,"","","","","","","","","",\
"hCoV-19/USA/"$1"/"substr($6,0,4),"","","","","","","","",$7,"","","missing","","","","","","",$14,"","","","","TXDSHS","","",""}' $result.demo.status.final |\
awk -F '\t' '{ $49 = (tolower($41) == "vaccine breakthrough" ? "VBC" : "") } 1' OFS="\t" |\
awk -F '\t' '{ $41 = (tolower($41) == "surveillance" ? "Baseline surveillance (random sampling)" : "") } 1' OFS="\t" |\
grep -f $result.failed -v - | grep -f $result.exclude -v - | cat template/attribute_template.txt - \
> $run_dir/$1_attribute.txt


#################################################################
# GISAID csv 30 fields
# 1-submitter,fn,covv_virus_name,covv_type,5-covv_passage,covv_collection_date,covv_location,covv_add_location,covv_host,10-covv_add_host_info,covv_sampling_strategy,covv_gender,covv_patient_age,covv_patient_status,15-covv_specimen,covv_outbreak,covv_last_vaccinated,covv_treatment,covv_seq_technology,20-covv_assembly_method,covv_coverage,covv_orig_lab,covv_orig_lab_addr,covv_provider_sample_id,25-covv_subm_lab,covv_subm_lab_addr,covv_subm_sample_id,covv_authors,covv_comment,30-comment_type

awk -F '\t' -v OFS=',' -v runname="$1" -v authors="$authors" '{ sub("\r", "", $14); \
print "TXWGS",runname".fasta","hCoV-19/USA/"$1"/"substr($6,0,4),"betacoronavirus","Original",\
$6,"North America/ USA/ Texas/ "$9,"","Human","",\
$14,$7,"unknown","unknown",$8,\
"unknown","unknown","unknown","Illumina Miseq",$12"/"$13,\
$10"x","TXDSHS","\"1100 W 49th Street, Austin TX 78756\"","","TXDSHS",\
"\"1100 W 49th Street, Austin TX 78756\"","",authors,"","",\
"","","","",""}' $result.demo.status.final |\
awk -F ',' '{ $10 = (tolower($11) == "vaccine breakthrough" ? "VBC" : "") } 1' OFS="," |\
awk -F ',' '{ $11 = ($11 == "Surveillance" ? "Baseline surveillance": "") } 1' OFS="," |\
sed 's/: Version: //g' | sed 's/version //g' |\
grep -f $result.failed -v - | grep -f $result.exclude -v - |\
cat template/GISAID_submission_template.csv - \
 > $run_dir/$1_gisaid_sub.csv

 

#################################################################
# runlist 6 fields
#1-TEXAS-DSHS#	2-Sequencing_run	3-DSHS_id	4-Completed/Failed	5-Depth_After_Trimming	6-Utah_Lineage
echo "TEXAS-DSHS#	Sequencing_run	DSHS_id	Completed/Failed	Depth_After_Trimming	Utah_Lineage" > $run_dir/$1.runlist.txt
awk -F '\t' -v OFS='\t' '{ print $1,$2,$3,$4,$10"x",$11 }' $result.demo.status.final | grep -v 'Undetermined' >> $run_dir/$1.runlist.txt

################################################################
# Print Run Summary
Total=`grep -f $result.exclude -v $result.demo.status.final | grep -v 'Undetermined' | wc -l`
NComplete=`awk -F '\t' '$4=="Complete" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' | wc -l`
Nfail=`awk -F '\t' '$4=="Failed" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' | wc -l`
echo "Total number of samples: $Total" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "# Passed samples: $NComplete" 2>&1 | tee -a $run_dir/$1.postCecret.log
echo "# Failed samples: $Nfail" 2>&1 | tee -a $run_dir/$1.postCecret.log
awk -F '\t' '$4=="Failed" {print $1}' $result.demo.status.final | grep -f $result.exclude -v | grep -v 'Undetermined' > $result.failed.samples
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

rm $result.filtered*
rm $result.status
rm $result.failed.samples
rm $result.demo
rm $result.demo.status
rm $result.demo.status.final
rm $result.failed*
rm $result.exclude
rm $result.fastqnames
rm $result.demo.status.sra
cp $SampleDemo $PWD/old_demos/demos_$1.txt

if [ -e /home/dnalab/cecret_runs/zipfiles/postCecret_$1.zip ];
then
rm /home/dnalab/cecret_runs/zipfiles/postCecret_$1.zip
fi
zip -rj /home/dnalab/cecret_runs/zipfiles/postCecret_$1 $run_dir/$1*
aws s3 cp /home/dnalab/cecret_runs/zipfiles/postCecret_$1.zip s3://804609861260-covid-19/cecret_runs/zip_files/postCecret_$1.zip
