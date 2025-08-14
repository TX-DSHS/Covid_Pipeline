#!/bin/bash
# This script is used to run the Cecret pipeline on the DSHS AWS server
# The script will download the sequencing run data from the S3 bucket, run the Cecret pipeline, and upload the results back to the S3 bucket
# The script will also run the postCecretPipeline.sh script if the demo file is found
# How to use this script
# Usage:
# bash run_Cecret.sh <sequencing_run>
# Help:
# <sequencing_run> is the name of the sequencing run to be analyzed. The script will look for a zip file with the same name in the S3 bucket 
# Date updated: 2024-03-28
# Author: jie.lu@dshs.texas.gov

# set the base directory
#aws_bucket="s3://804609861260-covid-19"

# Read the aws bucket name from file aws_bucket.txt
aws_bucket=$(cat aws_bucket.txt)

install_dir=$PWD
version="v1.0"

#set the base directory
basedir=$install_dir/cecret_runs/$1
rm -rf $basedir
mkdir -p $basedir

echo "Starting running run_Cecret.sh at "`date` 1>$basedir/run_Cecret.log
# log version of the script
echo "The version of the run_Cecret.sh script is" $version 1>>$basedir/run_Cecret.log

#Copy read files to working directory/reads
mkdir -p ${basedir}/reads

#aws s3 cp $aws_bucket/DATA/RAW_RUNS/$1.zip ${basedir}/reads 2>$basedir/run_Cecret.err
## if the zip file is not found, exit the script
#if [ ! -f ${basedir}/reads/$1.zip ]; then
#    echo "The zip file $1.zip is not found in the S3 bucket" 1>>$basedir/run_Cecret.log
#    exit 1
#fi

sequencer=$(echo $1 | cut -d "-" -f2)
run_date=$(echo $1 |cut -d "-" -f3)

#for new file path set vaiable $folder1 to directory name
folder1=$(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/$(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/ |grep $sequencer |grep $run_date |cut -d " " -f29)Alignment_1/ | cut -d " " -f29)
#copy fastq files to cecret run folder
if [[ $(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/$(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/ |grep $sequencer |grep $run_date |cut -d " " -f29)Alignment_1/${folder1}Fastq/) ]]
  then 
    seq_files=$(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/$(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/ |grep $sequencer |grep $run_date |cut -d " " -f29)Alignment_1/${folder1}Fastq/ | awk '{print $4}')
    for i in $seq_files 
      do 
      aws s3 cp s3://804609861260-covid-19/covid_sequencing_runs/$(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/ |grep $sequencer |grep $run_date |cut -d " " -f29)Alignment_1/${folder1}Fastq/$i $basedir/reads/    #this is the file structure for sequencers updated to windows 10 using local run manager
    done
    echo "sequencer uses new file structure"
elif [[ $(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/$(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/ |grep $sequencer |grep $run_date |cut -d " " -f29)Data/Intensities/BaseCalls/) ]]
  then
    seq_files=$(aws s3 ls  s3://804609861260-covid-19/covid_sequencing_runs/$(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/ |grep $sequencer |grep $run_date |cut -d " " -f29)Data/Intensities/BaseCalls/ |grep fastq.gz |awk '{print $4}')
    for i in $seq_files
      do
      aws s3 cp s3://804609861260-covid-19/covid_sequencing_runs/$(aws s3 ls s3://804609861260-covid-19/covid_sequencing_runs/ |grep $sequencer |grep $run_date |cut -d " " -f29)Data/Intensities/BaseCalls/$i $basedir/reads/
    done
    echo "sequencer used old file structure"
else
    echo "no sequence files exist"
fi

#unzip -j $basedir/reads/$1.zip -d $basedir/reads/ 2>>$basedir/run_Cecret.err
#rm $basedir/reads/$1.zip 2>$basedir/run_Cecret.err

#pull the latest pangolin version
echo "pulling pangolin latest version" 1>>$basedir/run_Cecret.log
docker pull staphb/pangolin:latest 2>>$basedir/run_Cecret.err

cd $basedir
#print run_cecret script name to text file
echo "The analysis of covid sequencing run" ${1} "was executed with " $0 > $basedir/cecret_script_used.txt

#run cecret
echo "running Cecret pipeline" 1>>$basedir/run_Cecret.log

source $install_dir/miniconda3/etc/profile.d/conda.sh
conda activate covid_illumina

nextflow run $install_dir/Cecret/Cecret_DSHS_midnight_pango_v4.1plus_usher.nf -c $install_dir/Cecret/configs/docker.config 2>$basedir/run_Cecret.err
#/work/software/nextflow run $install_dir/Cecret/Cecret_DSHS_midnight_pango_v4.1plus_usher.nf -c $install_dir/Cecret/configs/docker.config 2>$basedir/run_Cecret.err
conda deactivate
# if the run is not successful, exit the script
if [ $? -ne 0 ]; then
    echo "The Cecret pipeline failed" 1>>$basedir/run_Cecret.log
    exit 1
fi

# remove work directory
# rm -r $basedir/work/

#rename sumamry file
cp $basedir/cecret_run_results.txt $basedir/run_results_${1}.txt

echo "running data cleaning scripts" 1>>$basedir/run_Cecret.log

python3 $install_dir/scripts/summarize_cecret.py 2>>$basedir/run_Cecret.err  #script from Anna at UT Austin to summarize cecret results
# if the run is not successful, exit the script
if [ $? -ne 0 ]; then
    echo "The summarize_cecret.py script failed" 1>>$basedir/run_Cecret.log
    exit 1
fi

python3 $install_dir/scripts/parse_nextstrain_mutations.py 2>>$basedir/run_Cecret.err #script from Anna at UT Austin to create list of mutations
# if the run is not successful, exit the script
if [ $? -ne 0 ]; then
    echo "The parse_nextstrain_mutations.py script failed" 1>>$basedir/run_Cecret.log
    exit 1
fi

echo "running postCecretPipeline" 1>>$basedir/run_Cecret.log
# run postCecretPipeline
if ls ${install_dir}/demo_$1.txt 1> /dev/null 2>&1; then
    echo "demo file found" 1>>$basedir/run_Cecret.log
    cd $install_dir
    bash postCecretPipeline_Miseq.sh $1 2>>$basedir/run_Cecret.err
  
else
    echo "demo file does not exist" 1>>$basedir/run_Cecret.log
fi

echo "wrapping up results and transferring to s3" 1>>$basedir/run_Cecret.log
#zip output files
zip -r $basedir/$1.zip $basedir/* -x "$basedir/work/*"
# zip -r $basedir/$1* $basedir/*.txt $basedir/cecret/aligned/ $basedir/cecret/bedtools_multicov $basedir/cecret/consensus/  $basedir/cecret/fastqc/ $basedir/cecret/ivar_trim/ $basedir/cecret/ivar_variants/ $basedir/cecret/logs/ $basedir/cecret/nextclade/  $basedir/cecret/pangolin/ $basedir/cecret/samtools_ampliconstats/ $basedir/cecret/samtools_coverage/ $basedir/cecret/samtools_depth/  $basedir/cecret/samtools_flagstat/ $basedir/cecret/samtools_plot_ampliconstats/ $basedir/cecret/samtools_stats/ $basedir/cecret/seqyclean/   $basedir/cecret/summary.csv $basedir/cecret/vadr  $basedir/summary_nextclade_report.tsv $basedir/summary_pangolin_report.tsv $basedir/cecret/kraken2/ $basedir/Cecret/

#copy zip files and runresult file to S3 bucket
aws s3 cp $basedir/$1.zip $aws_bucket/cecret_runs/zip_files/ 2>>$basedir/run_Cecret.err
# if the run is not successful, exit the script
if [ $? -ne 0 ]; then
    echo "The zip file $1.zip failed to copy to the S3 bucket" 1>>$basedir/run_Cecret.log
    exit 1
fi
aws s3 cp $basedir/run_results_$1.txt $aws_bucket/cecret_runs/run_results/$1_cecret_results.csv 2>>$basedir/run_Cecret.err
# if the run is not successful, exit the script
if [ $? -ne 0 ]; then
    echo "The run_results_$1.txt file failed to copy to the S3 bucket" 1>>$basedir/run_Cecret.log
    exit 1
fi

echo "run_Cecret.sh completed at "`date` 1>>$basedir/run_Cecret.log

# bash postCecretPipeline.sh $1
# submit to SRA and Gisaid

# bash submit_to_SRA.sh $1
# bash submit_to_Gisaid.sh $1
