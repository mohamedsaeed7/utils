#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -d <database_name> -h <host> -u <username> -p <password> -t <target_directory>"
    exit 1
}

# Default values for variables
current_date=$(date +"%Y%m%d_%H%M%S")

# Parsing command line options
while getopts ":d:h:u:p:t:" opt; do
    case $opt in
        h) host="$OPTARG" ;;
        d) database="$OPTARG" ;;
        u) username="$OPTARG" ;;
        p) password="$OPTARG" ;;
        t) target_dir="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2
            usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2
            usage ;;
    esac
done

# Check if mandatory options are provided
if [ -z "$host" ] || [ -z "$database" ] || [ -z "$username" ] || [ -z "$password" ] || [ -z "$target_dir" ]; then
    usage
fi

# Check if the database exists
if ! mysql -h "$host" -u "$username" -p"$password" -e "use $database" 2>/dev/null; then
    echo "Database does not exist"
    exit;
fi

# Record the start time
start_time=$(date +%s)

# Create date directory if it doesn't exist or remove if it exists
date_dir="$target_dir/$current_date"
if [ -d "$date_dir" ]; then
    rm -rf "$date_dir"
fi
mkdir -p "$date_dir"

# Create 'base' directory within the date directory
base_dir="$date_dir/base"
mkdir -p "$base_dir"

# Run xtrabackup with the 'base' directory and provided parameters
backup_dir=$base_dir
mkdir -p "$backup_dir"

# Record backup start time
backup_start_time=$(date +%s)
sudo xtrabackup --databases="$database" --backup -H "$host" -u"$username" -p"$password" --target-dir="$backup_dir"
backup_end_time=$(date +%s)

# Get directory size before compression
before_size=$(du -sh "$backup_dir" | awk '{print $1}')

# Record compression start time
compress_start_time=$(date +%s)
# Tar the 'base' directory
tar -czvf "./$target_dir/$current_date.tar.gz" "$backup_dir"
compress_end_time=$(date +%s)

# Get directory size after compression
after_size=$(du -sh "./$target_dir/$current_date.tar.gz" | awk '{print $1}')

# Record s3 upload start time
upload_start_time=$(date +%s)

# Upload the tar file to S3
aws s3 cp "./$target_dir/$current_date.tar.gz" s3://my-bucket/

# Record s3 upload end time
upload_end_time=$(date +%s)

# Record the end time
end_time=$(date +%s)

# Calculate and display the time taken
elapsed_time_backup=$((backup_end_time - backup_start_time))
total_compress_time=$((compress_end_time - compress_start_time))    
total_upload_time=$((upload_end_time - upload_start_time))
total_elapsed_time=$((end_time - start_time))

echo "Total size before compression: $before_size"
echo "Total size after compression: $after_size"
echo "Time taken for compression: $total_compress_time seconds"
echo "Time taken for upload: $total_upload_time seconds"
echo "Time taken for backup: $elapsed_time_backup seconds"
echo "Total time taken: $total_elapsed_time seconds"
