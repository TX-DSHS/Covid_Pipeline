#!/bin/bash

#use this script to run Cecret
#useage:
# bash run_cecret.sh <sequencing_run> <path/to/reads>
#example############################################
# bash run_cecret.sh test_run /home/karen_test/test_run2/reads/

#set the base directory
basedir="$HOME/cecret_runs/$1" #$1 corresponds to first argument in bash command <sequencing_run>
mkdir -p $basedir


#add nextflow and miniconda to PATH
export PATH="$PATH:/work/software/"
source /work/software/miniconda3/etc/profile.d/conda.sh
if [[ -z ${CONDA_PREFIX+x} ]]; then
    export PATH="$PATH:~/conda/bin"
fi

sequencer=$(echo $1 | cut -d "-" -f2)
run_date=$(echo $1 |cut -d "-" -f3)

#Copy read files to working directory/reads
mkdir ${basedir}/reads
# cp -p ${2}/*.fastq.gz $basedir/reads/


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

#pull the latest pangolin version
#docker pull staphb/pangolin:latest

#copy Cecret to the working directory
cp  -r /home/bioinform/Cecret/ $basedir/
cd $basedir
#run cecret
/work/software/nextflow run $basedir/Cecret/Cecret_DSHS_midnight_pango_3.1.20.nf -c $basedir/Cecret/configs/docker.config
#rename sumamry file
cp $basedir/cecret_run_results.txt $basedir/run_results_${1}.txt

#cp /work/software/code/summarize_cecret.py ./
python3 /work/software/code/summarize_cecret.py #script from Anna at UT Austin to summarize cecret results
#cp /work/software/code/parse_nextstrain_mutations.py ./
python3 /work/software/code/parse_nextstrain_mutations.py #script from Anna at UT Austin to create list of mutations

#run annotation portion of cecret
/work/software/nextflow run $basedir/Cecret/Cecret_annotation_pango_3.1.20.nf  -c $basedir/Cecret/configs/docker.config

#copy new fastas so they can be used to run mafft, snpdists, and iqtree
cp $basedir/cecret/consensus/*.consensus.fa /home/dnalab/cecret_runs/cumulative_fastas/
#run mafft, snpdists, and iqtree for cumulative fasta files
/work/software/nextflow run $basedir/Cecret/Cecret_annotation.nf  -c $basedir/Cecret/configs/docker.config --relatedness true --fastas /home/dnalab/cecret_runs/cumulative_fastas/

#zip output files
zip -r /home/dnalab/cecret_runs/zipfiles/$1 $basedir/*.txt $basedir/cecret/aligned/ $basedir/cecret/bedtools_multicov $basedir/cecret/consensus/  $basedir/cecret/fastqc/ $basedir/cecret/ivar_trim/ $basedir/cecret/ivar_variants/ $basedir/cecret/logs/ $basedir/cecret/nextclade/  $basedir/cecret/pangolin/ $basedir/cecret/samtools_ampliconstats/ $basedir/cecret/samtools_coverage/ $basedir/cecret/samtools_depth/  $basedir/cecret/samtools_flagstat/ $basedir/cecret/samtools_plot_ampliconstats/ $basedir/cecret/samtools_stats/ $basedir/cecret/seqyclean/   $basedir/cecret/summary.csv $basedir/cecret/vadr  $basedir/summary_nextclade_report.tsv $basedir/summary_pangolin_report.tsv $basedir/cecret/kraken2/ $basedir/Cecret/

zip -r /home/dnalab/cecret_runs/zipfiles/ALL_to_$1 $basedir/cecret/fasta_prep/ $basedir/cecret/iqtree/ $basedir/cecret/mafft/ $basedir/cecret/snp-dists/

#copy zip files and runresult file to S3 bucket
aws s3 cp  $(echo /home/dnalab/cecret_runs/zipfiles/${1}.zip) s3://804609861260-covid-19/cecret_runs/zip_files/
aws s3 cp  $(echo /home/dnalab/cecret_runs/zipfiles/ALL_to_${1}.zip) s3://804609861260-covid-19/cecret_runs/zip_files/

aws s3 cp $(echo $basedir/run_results_$1.txt) s3://804609861260-covid-19/cecret_runs/run_results/
