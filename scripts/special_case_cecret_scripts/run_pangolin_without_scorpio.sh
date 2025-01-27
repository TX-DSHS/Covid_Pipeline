#run pangolin without scorpio
#usage bash run_pangolin_without_scorpio.sh <runname>

basedir="$HOME/cecret_runs/$1"

cd $basedir/cecret/consensus/
mkdir $basedir/cecret/consensus/data
runfolder="consensus"
cat TX*.fa > combined_consensus.fasta
#pangolearn_no_Scorpio
#pangolearn_no_Scorpio
docker run --rm=True -v $PWD:/$runfolder/ -u $(id -u):$(id -g) staphb/pangolin:latest \
pangolin /$runfolder/combined_consensus.fasta --analysis-mode pangolearn \
-o /$runfolder/data/ --skip-scorpio --outfile lineage_report_no_scorpio_${1}.csv

aws s3 cp $(echo $basedir/cecret/consensus/data/lineage_report_no_scorpio_${1}.csv) s3://804609861260-covid-19/cecret_runs/run_results/
