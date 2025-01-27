wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
rm Miniconda3-latest-Linux-x86_64.sh
source /home/dnalab/miniconda3/etc/profile.d/conda.sh
conda create -n covid
conda activate covid
conda install -c bioconda nextflow

