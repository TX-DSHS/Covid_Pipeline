###########################################
#
# Post-processing of Covid Cecret pipeline
# Created by: Richard (Stephen) Bovio 
# Contact: richard.bovio@dshs.texas.gov
#
# Date Created: 2025-03-11
# Date Last Modified: 2025-06-03
# 
###########################################

# Load libraries
library(dplyr)
library(lubridate)

# Read command line arguements
args <- commandArgs(trailingOnly = TRUE)

# Set variables
run_name <- args[1]
base_dir <- "/bioinformatics/Covid/"
run_dir <- paste0(base_dir,"cecret_runs/",run_name,"/")
authors_path <- paste0(base_dir,"template/authors.txt")
authors <- readLines(authors_path)
authors <- gsub('^"|"$', '', authors)
string_to_remove <- "pass"
incorrect_county_string <- "0"
correct_county_string <- ""
incorrect_sex_string <- "0"
correct_sex_string <- "Unknown"
num_N_threshold_value <- 15000
data <- read.table(paste0(run_dir,"cecret/cecret_results.txt.tmp"), header = TRUE, sep = "\t")
demo <- read.csv(paste0(run_dir,"download/demo_",run_name,".txt"), sep = "\t", header = TRUE)
# demo <- read.csv(paste0(base_dir,"modified_demos/demo_",run_name,".txt"), sep = "\t", header = TRUE)

################################################################################
########################## PROCESS RESULTS #####################################
################################################################################

# Generate short data frame
data_short <- subset(data, select = c(sample,
                                      pangolin_lineage,
                                      num_N,
                                      pangolin_qc_status))
data_short$sample_id_with_suffix <- data_short$sample
data_short$sample <- sub("\\..*", "", data_short$sample) # Remove suffix
data_short <- data_short[order(data_short$sample), ] # Sort data_short
colnames(data_short)[colnames(data_short) == 'sample'] <- "TX_DSHS_ID" # Change column name

# Sort demos
demo <- demo[order(demo$TX_DSHS_ID), ]

# Merge data_short and demo data frames
merged_data <- merge(demo, data_short, by = "TX_DSHS_ID", all = TRUE) 

# Generate failed data frame
data_failed <- data_short %>%
  filter(!grepl(string_to_remove, pangolin_qc_status) | num_N >= num_N_threshold_value)

# Generate status data frame
data_status <- data.frame(TX_DSHS_ID = character(),
                          sample_MinION_id = character(),
                          status = character())
for(i in 1:nrow(data_short)){
  sample_status <- data_short$pangolin_qc_status[i]
  sample_num_N <- data_short$num_N[i]
  if(sample_status == "pass" & sample_num_N <= num_N_threshold_value){
    passing_sample <- data.frame(TX_DSHS_ID = data_short$TX_DSHS_ID[i],
                                 sample_MinION_id = data_short$sample_id_with_suffix[i],
                                 status = data_short$pangolin_qc_status[i])
    data_status <- rbind(data_status, passing_sample)
  }
}
rm(passing_sample)

# Merge merged_data and data_status data frames
merged_data_status <- merge(merged_data, data_status, by = "TX_DSHS_ID", all = TRUE)
merged_data_status <- subset(merged_data_status, select = -c(status)) # Remove unnecessary rows

# Generate merged_data_status data frame
merged_data_status$Sex <- gsub(incorrect_sex_string, correct_sex_string, merged_data_status$Sex)
merged_data_status$County <- gsub(incorrect_county_string, correct_county_string, merged_data_status$County)

# Generate Complete.Failed and C.F_Comments columns
controls <- c("Pos", "Neg", "PT")
for(i in 1:nrow(merged_data_status)){
  if(any(sapply(controls, function(x) grepl(x, merged_data_status$Sample_ID[i]))) == TRUE){
    merged_data_status$Complete.Failed[i] = "Control"
    merged_data_status$C.F_Comments[i] = ""
  }
  else if(merged_data_status$pangolin_qc_status[i] == "pass" & merged_data_status$num_N[i] < 15000){
    merged_data_status$Complete.Failed[i] = "Complete"
    merged_data_status$C.F_Comments[i] = ""
  }
  else{
    merged_data_status$Complete.Failed[i] = "Failed"
    merged_data_status$C.F_Comments[i] = "Failed Pangolin QC"
  }
}

# Rename merged_data_status data frame
data_final <- merged_data_status 

# Sort data_final
data_final <- data_final[order(data_final$TX_DSHS_ID), ] # Sort data_short

# Generate exclude data frame
data_exclude <- data_final %>% 
  filter(grepl("^Pos|Neg|PT|SWAB|Swab", Sample_ID)) %>% 
  select(Sample_ID)

# Generate passing year file
data_passing <- data_final %>% 
  filter(!Sample_ID %in% data_exclude$Sample_ID & pangolin_qc_status == "pass" & num_N <= num_N_threshold_value) %>% 
  select(c(TX_DSHS_ID, Sample_ID, sample_MinION_id, Collection_date))
data_passing$Collection_date <- as.Date(data_passing$Collection_date)

# Generate passing final file
passing_samples <- data_passing$Sample_ID

data_passing_final <- data_final[data_final$Sample_ID %in% passing_samples, ]
data_passing_final$Collection_date <- as.Date(data_passing_final$Collection_date)
data_passing_final <- data_passing_final %>% 
  mutate(Year = year(Collection_date),
         Month = month(Collection_date),
         Day = day(Collection_date))


################################################################################
#################### GENERATE SRA METADATA & ATTRIBUTES ########################
################################################################################

if(nrow(data_passing_final) > 0){
  # Generate SRA metadata file
  sra_metadata <- data.frame(sample_name = character(),
                             library_ID = character(),
                             title = character(),
                             library_strategy = character(),
                             library_source = character(),
                             library_selection = character(),
                             library_layout = character(),
                             platform = character(),
                             instrument_model = character(),
                             design_description = character(),
                             filetype = character(),
                             filename = character(),
                             filename2 = character(),
                             filename3 = character(),
                             filename4 = character(),
                             assembly = character(),
                             fasta_file = character())
                             
  for(i in 1:nrow(data_passing_final)){
    current_sample = data.frame(sample_name = data_passing_final$TX_DSHS_ID[i],
                                library_ID = data_passing_final$TX_DSHS_ID[i],
                                title = "PCR Tiled Amplification of SARS-CoV-2",
                                library_strategy = "AMPLICON",
                                library_source = "VIRAL RNA",
                                library_selection = "PCR",
                                library_layout = "single",
                                platform = "OXFORD_NANOPORE",
                                instrument_model = "MinION",
                                design_description = "Clear Dx SARS-CoV-2 WGS v3.0",
                                filetype = "fastq",
                                filename = paste0(data_passing_final$sample_MinION_id[i],".fastq"),
                                filename2 = "",
                                filename3 = "",
                                filename4 = "",
                                assembly = "",
                                fasta_file = "")
    sra_metadata <- rbind(sra_metadata, current_sample)
  }
  rm(current_sample)
  write.table(sra_metadata, paste0(run_dir,run_name,"_SRA_metadata_submission.txt"), sep = "\t", row.names = FALSE, quote = FALSE)
  
  # Generate attribute file
  sra_attribute <- data.frame(sample_name = character(),
                              sample_title = character(),
                              bioproject_accession = character(),
                              organism = character(),
                              strain = character(),
                              collected_by = character(),
                              collection_date = character(),
                              geo_loc_name = character(),
                              host = character(),
                              host_disease = character(),
                              isolate = character(),
                              isolation_source = character(),
                              antiviral_treatment_agent = character(),
                              collection_device = character(),
                              collection_method = character(),
                              date_of_prior_antiviral_treat = character(),
                              date_of_prior_sars_cov_2_infection = character(),
                              date_of_sars_cov_2_vaccination = character(),
                              exposure_event = character(),
                              geo_loc_exposure = character(),
                              gisaid_accession = character(),
                              gisaid_virus_name = character(),
                              host_age = character(),
                              host_anatomical_material = character(),
                              host_anatomical_part = character(),
                              host_body_product = character(),
                              host_disease_outcome = character(),
                              host_health_state = character(),
                              host_recent_travel_loc = character(),
                              host_recent_travel_return_date = character(),
                              host_sex = character(),
                              host_specimen_voucher = character(),
                              host_subject_id = character(),
                              lat_lon = character(),
                              passage_method = character(),
                              passage_number = character(),
                              prior_sars_cov_2_antiviral_treat = character(),
                              prior_sars_cov_2_infection = character(),
                              prior_sars_cov_2_vaccination = character(),
                              purpose_of_sampling = character(),
                              purpose_of_sequencing = character(),
                              sars_cov_2_diag_gene_name_1 = character(),
                              sars_cov_2_diag_gene_name_2 = character(),
                              sars_cov_2_diag_pcr_ct_value_1 = character(),
                              sars_cov_2_diag_pcr_ct_value_2 = character(),
                              sequenced_by = character(),
                              vaccine_received = character(),
                              virus_isolate_of_prior_infection = character(),
                              description = character())
  
  for(i in 1:nrow(data_passing_final)){
    current_sample <- data.frame(sample_name = data_passing_final$TX_DSHS_ID[i],
                                 sample_title = "",
                                 bioproject_accession = "PRJNA639066",
                                 organism = "Severe acute respiratory syndrome coronavirus 2",
                                 strain = paste0("SARS-CoV-2/USA/",data_passing_final$TX_DSHS_ID[i],"/",data_passing_final$Year[i]),
                                 collected_by = "Texas Department of State Health Services",
                                 collection_date = data_passing_final$Collection_date[i],
                                 geo_loc_name = "USA: Texas",
                                 host = "Homo sapiens",
                                 host_disease = "COVID-19",
                                 isolate = "missing",
                                 isolation_source = data_passing_final$Source[i],
                                 antiviral_treatment_agent = "",
                                 collection_device = "",
                                 collection_method = "",
                                 date_of_prior_antiviral_treat = "",
                                 date_of_prior_sars_cov_2_infection = "",
                                 date_of_sars_cov_2_vaccination = "",
                                 exposure_event = "",
                                 geo_loc_exposure = "",
                                 gisaid_accession = "",
                                 gisaid_virus_name = paste0("hCoV-19/USA/",data_passing_final$TX_DSHS_ID[i],"/",data_passing_final$Year[i]),
                                 host_age = "",
                                 host_anatomical_material = "",
                                 host_anatomical_part = "",
                                 host_body_product = "",
                                 host_disease_outcome = "",
                                 host_health_state = "",
                                 host_recent_travel_loc = "",
                                 host_recent_travel_return_date = "",
                                 host_sex = data_passing_final$Sex[i],
                                 host_specimen_voucher = "",
                                 host_subject_id = "",
                                 lat_lon = "missing",
                                 passage_method = "",
                                 passage_number = "",
                                 prior_sars_cov_2_antiviral_treat = "",
                                 prior_sars_cov_2_infection = "",
                                 prior_sars_cov_2_vaccination = "",
                                 purpose_of_sampling = "",
                                 purpose_of_sequencing = "",
                                 sars_cov_2_diag_gene_name_1 = "",
                                 sars_cov_2_diag_gene_name_2 = "",
                                 sars_cov_2_diag_pcr_ct_value_1 = "",
                                 sars_cov_2_diag_pcr_ct_value_2 = "",
                                 sequenced_by = "TXDSHS",
                                 vaccine_received = "",
                                 virus_isolate_of_prior_infection = "",
                                 description = "")
    sra_attribute <- rbind(sra_attribute, current_sample)
  }
  rm(current_sample)
  write.table(sra_attribute, paste0(run_dir,run_name,"_SRA_attribute_submission.txt"), sep = "\t", row.names = FALSE, quote = FALSE)
}




################################################################################
############################### GENERATE GISAID ################################
################################################################################

# GISAID file (30 fields):
# 1 submitter  fn  covv_virus_name  covv_type
# 5 covv_passage  covv_collection_date  covv_location  covv_add_location  covv_host
# 10 covv_add_host_info  covv_sampling_strategy  covv_gender  covv_patient_age  covv_patient_status
# 15 covv_specimen  covv_outbreak  covv_last_vaccinated  covv_treatment  covv_seq_technology
# 20 covv_assembly_method  covv_coverage  covv_orig_lab  covv_orig_lab_addr  covv_provider_sample_id
# 25 covv_subm_lab  covv_subm_lab_addr  covv_subm_sample_id  covv_authors  covv_comment comment_type

# Generate GISAID file
gisaid <- data.frame(submitter = character(),
                     fn = character(),
                     covv_virus_name = character(),
                     covv_type = character(),
                     covv_passage = character(),
                     covv_collection_date = character(),
                     covv_location = character(),
                     covv_add_location = character(),
                     covv_host = character(),
                     covv_add_host_info = character(),
                     covv_sampling_strategy = character(),
                     covv_gender = character(),
                     covv_patient_age = character(),
                     covv_patient_status = character(),
                     covv_specimen = character(),
                     covv_outbreak = character(),
                     covv_last_vaccinated = character(),
                     covv_treatment = character(),
                     covv_seq_technology = character(),
                     covv_assembly_method = character(),
                     covv_coverage = character(),
                     covv_orig_lab = character(),
                     covv_orig_lab_addr = character(),
                     covv_provider_sample_id = character(),
                     covv_subm_lab = character(),
                     covv_subm_lab_addr = character(),
                     covv_subm_sample_id = character(),
                     covv_authors = character(),
                     covv_comment = character(),
                     comment_type = character())

if(nrow(data_passing_final) > 0){
  for(i in 1:nrow(data_passing_final)){
    current_sample <- data.frame(submitter = "TXWGS",
                                 fn = paste0(data_passing_final$sample_MinION_id[i],".fasta"),
                                 covv_virus_name = paste0("hCoV-19/USA/",data_passing_final$TX_DSHS_ID[i],"/",data_passing_final$Year[i]),
                                 covv_type = "betacoronavirus",
                                 covv_passage = "Original",
                                 #2
                                 covv_collection_date = data_passing_final$Collection_date[i],
                                 covv_location = paste0("North America/USA/Texas/", data_passing_final$County[i]),
                                 covv_add_location = "unknown",
                                 covv_host = "Human",
                                 covv_add_host_info = "",
                                 #3
                                 covv_sampling_strategy = data_passing_final$Reason_for_sequencing[i],
                                 covv_gender = data_passing_final$Sex[i],
                                 covv_patient_age = "unknown",
                                 covv_patient_status = "unknown",
                                 covv_specimen = data_passing_final$Source[i],
                                 #4
                                 covv_outbreak = "unknown",
                                 covv_last_vaccinated = "unknown",
                                 covv_treatment = "unknown",
                                 covv_seq_technology = "OXFORD NANOPORE MinION",
                                 covv_assembly_method = "Minimap2/Medaka",
                                 #5
                                 covv_coverage = "",
                                 covv_orig_lab = "TXDSHS",
                                 covv_orig_lab_addr = "1100 W 49th Street, Austin TX 78756",
                                 covv_provider_sample_id = "",
                                 covv_subm_lab = "TXDSHS",
                                 #6
                                 covv_subm_lab_addr = "1100 W 49th Street, Austin TX 78756",
                                 covv_subm_sample_id = "",
                                 covv_authors = authors,
                                 covv_comment = "",
                                 comment_type = "")
    gisaid <- rbind(gisaid, current_sample)
  }
  rm(current_sample)
  gisaid$covv_sampling_strategy <- gsub("Surveillance", "Baseline surveillance", gisaid$covv_sampling_strategy)
  write.csv(gisaid, paste0(run_dir,run_name,"_GISAID_submission.csv"), row.names = FALSE, quote = TRUE)
}

################################################################################
############################### GENERATE FASTA/FASTQ SUBMISSIONS ###############
################################################################################

if(nrow(data_passing_final) > 0){
  # FASTQ
  write.table(data_passing_final$TX_DSHS_ID, paste0(run_dir,run_name,"_SRA_fastq_samples_to_submit.txt"), sep = "\t", row.names = FALSE, quote = FALSE, col.names = FALSE)
  
  # FASTA
  SRA_fasta_samples_to_submit <- data.frame(fasta_fn = data_passing_final$sample_MinION_id,
                                            sample_id = data_passing_final$TX_DSHS_ID,
                                            Year = data_passing_final$Year)
  write.table(SRA_fasta_samples_to_submit, paste0(run_dir,run_name,"_SRA_fasta_samples_to_submit.txt"), sep = "\t", row.names = FALSE, quote = FALSE, col.names = FALSE)
}

################################################################################
############################### GENERATE RUNLIST ###############################
################################################################################

runlist <- data.frame(TEXAS_DSHS = character(),
                      Sequencing_Run = character(),
                      Sequencing_ID = character(),
                      Sample_Type = character(),
                      Lineage = character(),
                      num_N = character(),
                      Pangolin_Status = character(),
                      Pangolin_Status_Comments = character())

for(i in 1:nrow(data_final)){
  current_sample <- data.frame(TEXAS_DSHS = data_final$TX_DSHS_ID[i],
                               Sequencing_Run = data_final$Sequencing_Run[i],
                               Sequencing_ID = data_final$Sample_ID[i],
                               Sample_Type = data_final$Complete.Failed[i],
                               Lineage = data_final$pangolin_lineage[i],
                               num_N = data_final$num_N[i],
                               Pangolin_Status = data_final$pangolin_qc_status[i],
                               Pangolin_Status_Comments = data_final$C.F_Comments[i])
  runlist <- rbind(runlist, current_sample)
}
rm(current_sample)
write.table(runlist, paste0(run_dir,run_name,"_runlist.txt"), sep = "\t", row.names = FALSE, quote = FALSE)

