# Create samplesheet for Clinical Clear Labs Covid

args <- commandArgs(trailingOnly = TRUE)

run_name <- args[1]
s <- args[2]

samples <- read.delim(s, header = FALSE)

samples <- samples$V1

fastq_dir <- paste0("/bioinformatics/Covid/cecret_runs/",run_name,"/reads/")

data = data.frame(sample = character(),
                  fastq_1 = character(),
                  ont = character())

for(i in 1:length(samples)){
  tmp <- data.frame(sample = samples[i],
                    fastq_1 = paste0(fastq_dir,samples[i],".fasta"),
                    ont = "ont")
  data = rbind(data,tmp)
}

write.csv(data, paste0("samplesheets/",run_name,"_samplesheet.csv"), row.names = FALSE, quote = FALSE)
