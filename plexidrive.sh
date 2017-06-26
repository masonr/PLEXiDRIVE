#!/bin/bash

##################### PLEXiDRIVE #####################
## This script automates using a single or multiple ##
## Google Drive accounts as storage for a Plex      ##
## server.                                          ##
######################################################

# Make sure that this the ONLY instance of this script running 
for pid in $(pidof -x plexidrive.sh); do
    if [ $pid != $$ ]; then
        echo "This script is already running, exiting to avoid duplicate uploads."
        exit 1
    fi
done

# Directory where this file exists
plexidrive_dir=`dirname $(realpath -s $0)`
cd "$plexidrive_dir"

# Read in configuration file
if [ -e ./plexidrive.conf ] ; then
	source ./plexidrive.conf
else
	echo "Configuration file - plexidrive.conf - not found."
	echo "$(date +%F_%T) Configuration file - plexidrive.conf - not found." >> "$plexidrive_dir/upload-error"
	exit 1
fi

# Create blank files if they don't exist yet
touch plex-scan
touch plex-scan.log
touch upload-error

# Check variables
if [ "$num_of_gdrives" -ne ${#drive_names[@]} ] || [ "$num_of_gdrives" -ne ${#gdrive_mount_paths[@]} ] ; then
	echo "gdrive variables are not set up correctly! Exiting..."
	echo "$(date +%F_%T) gdrive variables are not set up correctly! Exiting." >> "$plexidrive_dir/upload-error"
	exit 1
fi

# Upload tv shows, if enabled
if [ "$enable_show_uploads" = true ] ; then
	# Run the show upload script
	./upload-shows.sh

	# Check if script succeeded
	if [ $? -ne 0 ]
	then
		echo "Upload shows script was unsuccessful, exiting plexidrive script."
		exit 1
	fi
fi

# Upload movies, if enabled
if [ "$enable_movie_uploads" = true ] ; then
	# Run the movie upload script
	./upload-movies.sh

	# Check if script succeeded
	if [ $? -ne 0 ]
	then
		echo "Upload movies script was unsuccessful, exiting plexidrive script."
		exit 1
	fi
fi

# # Scan new media folders with Plex CLI Scanner tool, if enabled
# if [ "$plex_scan_after_upload" = true ] ; then
# 	# Run the Plex scan script
# 	# If scanning enabled, must be ran as root user to execute the plex scanning script as the plex user
# 	sudo su -c './plex-scan.sh' plex
# fi
