#!/bin/sh

#################################################################################
#
# This script checks whether the demo file is properly formatted.
#
# Usage: bash check_demo_sb.sh <run_name>
# Example: bash check_demo_sb.sh TX-CL001-240820
#
# Created by: Megan Partridge (megan.partridge@dshs.texas.gov)
# Last updated by: Richared (Stephen) Bovio (richard.bovio@dshs.texas.gov)
# Last updated: 9/9/2024
#
#################################################################################

echo "Running check_demo_sb.sh..."
echo `date`
echo ""
echo "Checking if demo file exists and is formatted properly..."
echo ""

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <sample_name>"
    exit 1
fi

run_dir="/bioinformatics/Covid_Pipeline/cecret_runs/$1"
input_file="/bioinformatics/Covid_Pipeline/cecret_runs/$1/download/demo_$1.txt"
data_directory="/bioinformatics/Covid_Pipeline/cecret_runs/$1/reads/"
error_encountered=0

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found"
    error_encountered=1
else
    echo "Check: demo file exists"
fi

# Check if the data directory exists
if [ ! -d "$data_directory" ]; then
    echo "Error: Data directory '$data_directory' not found"
    error_encountered=1
else
    echo "Check: data directory exists"
fi

# Check if the file is tab-delimited
if grep -q $'\t' "$input_file"; then
    echo "Check: demo file is tab-delimited"
else
    echo "Error: demo file is not tab-delimited"
    error_encountered=1
fi

# Check if the file has exactly 9 fields or elements
first_row_fields=$(head -n 1 "$input_file" | awk -F'\t' '{print NF}')
if [ "$first_row_fields" -ne 9 ]; then
    echo "Error: The input file does not have exactly 9 fields"
    error_encountered=1
else
    echo "Check: The input file has exactly 9 fields"
fi

# Check date format
while IFS=$'\t' read -r -a fields; do
  date_value="${fields[3]}"  # 4th field (0-based indexing)
  if [ "$date_value" != "#N/A" ] && ! [[ "$date_value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && ! [[ "$date_value" == "Complete/Failed" ]]; then
    echo "Error: Date format '$date_value' is not YYYY-MM-DD"
    error_encountered=1
  elif [ "$date_value" == "Complete/Failed" ]; then
    echo "Check: column header exists"
    echo ""
  else 
	  # echo "$date_value is in the correct format YYYY-MM-DD or #N/A (control)."
    echo "Check: $date_value is in the correct format YYYY-MM-DD or #N/A (control)"
  fi
done < "$input_file"

echo ""

# Check if each ID has a corresponding file in the specified data directory
while IFS=$'\t' read -r id _; do
  # Use find to check for the existence of a file containing the ID in the data directory
  if find "$data_directory" -type f -name "*$id*" | grep -q .; then
    echo "Check: File containing ID '$id' exists in the directory"
  elif [ "$id" == "TX-DSHS-####" ]; then
    echo "Check: File containing ID '$id' exists in the directory"
  else
    echo "Error: File containing ID '$id' does not exist in the directory"
    error_encountered=1
  fi
done < "$input_file"

echo ""

# Check for the presence of "PositiveSARS" and any line in column 3 that begins with the word "Negative"
if grep -qE "PositiveSARS|Negative.*" "$input_file"; then
  echo "Check: 'PositiveSARS' and 'Negative' with variations are present among the ID names in column 3"
else
  echo "Error: 'PositiveSARS' and 'Negative' with variations must be present among the ID names in column 3"
  error_encountered=1
fi

echo ""

# Check if the last line is blank or contains only a tab
last_line=$(tail -n 1 "$input_file")
if [[ "$last_line" =~ ^[[:space:]]*$ ]]; then
  echo "WARNING: Last line is empty or consists solely of whitespace characters (which includes tabs) and will has been removed"
  echo ""
  # Remove the last line if it matches the criteria
  # Use `head` to keep all but the last line and overwrite the file
  head -n -1 "$input_file" > tmpfile && mv tmpfile "$input_file"
fi

if [ "$error_encountered" -eq 0 ]; then
  echo "All checks passed successfully!"
  echo ""
else
  echo "One or more checks failed"
  echo ""
  exit 1
fi
