# Covid Pipeline
Texas DSHS Sars-CoV2 pipeline is designed to process Sars-CoV2 samples using the Utah Cecret pipeline:
https://github.com/UPHL-BioNGS/Cecret

## The pipeline can be installed in /bioinformatics/ partition of AWS EC2 by:

```bash
git clone https://github.com/TX-DSHS/Covid_pipeline.git -b bfx

# If seeing CRLF error
git config core.autocrlf false
git rm --cached -r .         # Don’t forget the dot at the end
git reset --hard
```
## Install conda
```bash
curl -sL \
  "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" > \
  "Miniconda3.sh"
bash Miniconda3.sh
```
Do you accept the license terms? [yes|no]
>>> yes

Miniconda3 will now be installed into this location:
/home/dnalab/miniconda3

  - Press ENTER to confirm the location
  - Press CTRL-C to abort the installation
  - Or specify a different location below

[/home/dnalab/miniconda3] >>> /bioinformatics/Covid_pipeline/miniconda3

```bash
rm Miniconda3.sh
```

## Create a conda environment installing Singularity and nextflow:
```bash
source /bioinformatics/Covid_pipeline/miniconda3/etc/profile.d/conda.sh
conda create -n nextflow -c conda-forge -c bioconda \
   nextflow pandas
```

## To run Covid pipeline:
```bash
# For Illumina runs
bash run_Cecret.sh <run_name>

# For Clear Labs runs
bash run_Cecret_CL.sh <run_name>

```
## To submit passed samples from a completed run:
```bash
bash submit_to_Gisaid.sh <run_name>
bash submit_to_SRA.sh <run_name>
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

[MIT](https://choosealicense.com/licenses/mit/)
