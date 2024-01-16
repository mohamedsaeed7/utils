#!/bin/bash

# Define default values
baseDir=""

# Parse arguments
while getopts "b:i:" opt; do
  case $opt in
    b)
      baseDir="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Check if baseDir is provided
if [ -z "$baseDir" ]; then
  echo "Base directory not provided. Please use -b option to specify base directory."
  exit 1
fi

# Record start time
start_time=$(date +%s)

# Stop MySQL server
systemctl stop mysql

# Move contents of /var/lib/mysql to temp directory
tempDir="/tmp/mysql_temp"
rm -rf "$tempDir"
mkdir -p "$tempDir"
cp -rf /var/lib/mysql/* "$tempDir/"

# Remove tmp directory if exists
tmpFolder="/tmp/mysql_backup"
if [ -d "$tmpFolder" ]; then
    rm -rf "$tmpFolder";
fi

# Create tmp directory
mkdir -p "$tmpFolder"

# Copy base dir to tmp folder 
cp -r "$baseDir/base" "$tmpFolder"

# Prepare base dir
xtrabackup --prepare --apply-log-only --target-dir="$tmpFolder/base"

# Measure time for preparation
preparation_time=$(( $(date +%s) - $start_time ))

# Measure time for MySQL stop
stop_time=$(( $(date +%s) - $start_time ))

# Restore backup using rsync
mkdir -p /var/lib/mysql

rsync -avrP "$tmpFolder/base/" /var/lib/mysql/

# Measure time for copying and restoration
copy_restore_time=$(( $(date +%s) - $start_time ))

sudo chown -R mysql:mysql /var/lib/mysql

# Start MySQL server
systemctl start mysql

# Measure time for MySQL start
start_time=$(( $(date +%s) - $start_time ))

# Check if MySQL started successfully
if service mysql status | grep -q "active (running)"; then
  # MySQL started successfully, remove the temp directory
  rm -rf "$tempDir"
  echo "MySQL started successfully. Safe backup removed."
else
  # MySQL start failed, return contents back
  echo "MySQL start failed. Safe Backup will be returned to /var/lib/mysql/."

  echo "Removing datadir";
  rm -rf /var/lib/mysql/

  echo "Restore the last datadir from safe backup"
  cp "$tempDir"/* /var/lib/mysql/

  echo "Update mysql datadir permisisons";
  chown -R mysql:mysql /var/lib/mysql

  echo "Start MySQL again with last working datadir"
  systemctl start mysql
fi

# Calculate times in readable format
echo "Time taken for preparation: $preparation_time seconds"
echo "Time taken for MySQL stop: $stop_time seconds"
echo "Time taken for copying and restoration: $copy_restore_time seconds"
echo "Time taken for MySQL start: $start_time seconds"