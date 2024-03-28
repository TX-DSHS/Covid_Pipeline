#!/bin/bash

#use this script to run Cecret
#useage:
# bash run_Cecret.sh <sequencing_run> 
# Date updated: 2024-03-28
# Author: jie.lu@dshs.texas.gov

#add nextflow and miniconda to PATH
#export PATH="$PATH:/work/software/"
#source /work/software/miniconda3/etc/profile.d/conda.sh
#if [[ -z ${CONDA_PREFIX+x} ]]; then
#    export PATH="$PATH:~/conda/bin"
#fi
# set the base directory
install_dir="/home/dnalab"
#set the base directory
basedir="/home/dnalab/cecret_runs/$1" #$1 corresponds to first argument in bash command <sequencing_run>
rm -rf $basedir
mkdir -p $basedir
rm $basedir/run_Cecret.log $basedir/run_Cecret.err
echo "Starting running run_Cecret.sh at "`date` 1>$basedir/run_Cecret.log

#Copy read files to working directory/reads
mkdir -p ${basedir}/reads

aws s3 cp s3://804609861260-covid-19/DATA/RAW_RUNS/$1.zip ${basedir}/reads 2>$basedir/run_Cecret.err
unzip -j $basedir/reads/$1.zip -d $basedir/reads/ 2>>$basedir/run_Cecret.err
rm $basedir/reads/$1.zip 2>$basedir/run_Cecret.err

#pull the latest pangolin version
echo "pulling pangolin latest version" 1>>$basedir/run_Cecret.log
docker pull staphb/pangolin:latest 2>>$basedir/run_Cecret.err

cd $basedir
#print run_cecret script name to text file
echo "The analysis of covid sequencing run" ${1} "was executed with " $0 > $basedir/cecret_script_used.txt
#cp $HOME/$0 $basedir/

#run cecret
echo "running Cecret pipeline" 1>>$basedir/run_Cecret.log
/work/software/nextflow run $install_dir/Cecret/Cecret_DSHS_midnight_pango_v4.1plus_usher.nf -c $install_dir/Cecret/configs/docker.config 2>$basedir/run_Cecret.err
#rename sumamry file
cp $basedir/cecret_run_results.txt $basedir/run_results_${1}.txt

echo "running data cleaning scripts" 1>>$basedir/run_Cecret.log

python3 $install_dir/code/summarize_cecret.py 2>>$basedir/run_Cecret.err  #script from Anna at UT Austin to summarize cecret results

python3 $install_dir/code/parse_nextstrain_mutations.py 2>>$basedir/run_Cecret.err #script from Anna at UT Austin to create list of mutations

echo "running postCecretPipeline" 1>>$basedir/run_Cecret.log
# run postCecretPipeline
if ls ${basedir}/reads/demo* 1> /dev/null 2>&1; then
    echo "demo file found" 1>>$basedir/run_Cecret.log
    cp ${basedir}/reads/demo* $install_dir 2>>$basedir/run_Cecret.err
    cd $install_dir
    bash postCecretPipeline_test.sh $1 2>>$basedir/run_Cecret.err
else
    echo "demo file does not exist" 1>>$basedir/run_Cecret.log
fi

echo "wrapping up results and transferring to s3" 1>>$basedir/run_Cecret.log
#zip output files
mkdir -p $install_dir/cecret_runs/zipfiles
zip -r $install_dir/cecret_runs/zipfiles/$1 $basedir/$0 $basedir/*.txt $basedir/cecret/aligned/ $basedir/cecret/bedtools_multicov $basedir/cecret/consensus/  $basedir/cecret/fastqc/ $basedir/cecret/ivar_trim/ $basedir/cecret/ivar_variants/ $basedir/cecret/logs/ $basedir/cecret/nextclade/  $basedir/cecret/pangolin/ $basedir/cecret/samtools_ampliconstats/ $basedir/cecret/samtools_coverage/ $basedir/cecret/samtools_depth/  $basedir/cecret/samtools_flagstat/ $basedir/cecret/samtools_plot_ampliconstats/ $basedir/cecret/samtools_stats/ $basedir/cecret/seqyclean/   $basedir/cecret/summary.csv $basedir/cecret/vadr  $basedir/summary_nextclade_report.tsv $basedir/summary_pangolin_report.tsv $basedir/cecret/kraken2/ $basedir/Cecret/

#copy zip files and runresult file to S3 bucket
aws s3 cp  $(echo ${install_dir}/cecret_runs/zipfiles/${1}.zip) s3://804609861260-covid-19/cecret_runs/zip_files/ 2>>$basedir/run_Cecret.err

aws s3 cp $(echo $basedir/run_results_$1.txt) s3://804609861260-covid-19/cecret_runs/run_results/ 2>>$basedir/run_Cecret.err

echo "run_Cecret.sh completed at "`date` 1>>$basedir/run_Cecret.log
#bash postCecretPipeline.sh $1
# submit to SRA and Gisaid

# bash submit_to_SRA.sh $1
# bash submit_to_Gisaid.sh $1
