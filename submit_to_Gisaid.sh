cd /bioinformatics/Covid_Pipeline/cecret_runs/$1
/home/dnalab/.local/bin/cli2 upload --metadata $1_GISAID_submission.csv --fasta $1.fasta --frameshift catch_novel --token /home/dnalab/gisaid_cli2/gisaid.authtoken --database EpiCoV
