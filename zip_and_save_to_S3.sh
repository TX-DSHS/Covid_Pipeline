#!/bin/bash

#use this script to run Cecret
#useage:
# bash zip_and_save_to_S3.sh  <sequencing_run_folder_name> 
#example############################################
# bash run_cecret.sh test_run /home/karen_test/test_run2/reads/

#set the base directory
basedir="$HOME/cecret_runs/$1" #$1 corresponds to first argument in bash command <sequencing_run>
mkdir -p $basedir



cd $basedir


#zip output files
zip -r /home/dnalab/cecret_runs/zipfiles/$1.zip $basedir/*.txt $basedir/cecret/aligned/ $basedir/cecret/bedtools_multicov $basedir/cecret/consensus/  $basedir/cecret/fastqc/ $basedir/cecret/ivar_trim/ $basedir/cecret/ivar_variants/ $basedir/cecret/logs/ $basedir/cecret/nextclade/  $basedir/cecret/pangolin/ $basedir/cecret/samtools_ampliconstats/ $basedir/cecret/samtools_coverage/ $basedir/cecret/samtools_depth/  $basedir/cecret/samtools_flagstat/ $basedir/cecret/samtools_plot_ampliconstats/ $basedir/cecret/samtools_stats/ $basedir/cecret/seqyclean/   $basedir/cecret/summary.csv $basedir/cecret/vadr  $basedir/summary_nextclade_report.tsv $basedir/summary_pangolin_report.tsv $basedir/cecret/kraken2/ $basedir/Cecret/

zip -r /home/dnalab/cecret_runs/zipfiles/ALL_to_$1.zip $basedir/cecret/fasta_prep/ $basedir/cecret/iqtree/ $basedir/cecret/mafft/ $basedir/cecret/snp-dists/

#copy zip files and runresult file to S3 bucket
aws s3 cp  $(echo /home/dnalab/cecret_runs/zipfiles/${1}.zip) s3://804609861260-covid-19/cecret_runs/zip_files/
aws s3 cp  $(echo /home/dnalab/cecret_runs/zipfiles/ALL_to_${1}.zip) s3://804609861260-covid-19/cecret_runs/zip_files/

aws s3 cp $(echo $basedir/run_results_$1.txt) s3://804609861260-covid-19/cecret_runs/run_results/
