#!/bin/bash
###
### q4maxupdater.sh
###
### Author: Kevin Laude <klaude@theplanet.com>
### Last Modified: 11/13/2005
###
### This script will install and update Q4Max for the Linux Quake 4 server.
###
### This script is free for all to use. If you have any questions or
### suggestions for it please email me. Remember to buy lots of servers from
### Insomnia365 <http://www.insomnia365.com> . :)

###
### ChangeLog
###

# 11/13/2005 - This script used to run PK++ updates. It's been renamed and
#              modified to work with Q4Max now.
#            - Added a byte counter to the report at the end.
#            - Now displays total file size when downloading a file.

# 04/11/2005 - Simplified a bunch of confusing sed statements when getting
#              local file size.

###
### Requirements
###

# This script has been tested to work on the following platforms:
#
#  - RedHat Enterprise Linux v3
#  - RedHat Enterprise Linux v4
#  - FreeBSD v4.11
#  - FreeBSD v5.3
#
# This should however work on most other Linux distributions or any
# environment with a BASH shell. It is assumed that the common UNIX tools mv,
# rm, cp, sed, grep, ls, awk, tr, bc, and cut all exist on the system and can
# be executed without having to invoke the full path to the program.
#
# This script uses the GNU wget utility to download the Q4Max file list and the
# individual update files. This is already installed on most UNIX systems.
# Run the command 'whereis wget' to check your system. If no path is returned
# then you'll need to install wget. The following commands will install wget
# for you:
#
#  - Redhat:  'up2date wget'
#  - Debian:  'apt-get wget'
#  - Gentoo:  'emerge wget'
#  - FreeBSD: 'cd /usr/ports/ftp/wget && make all install clean'
#
# If your distribution isn't listed above or you want to install wget manually
# head to the GNU wget homepage at
# <http://www.gnu.org/software/wget/wget.html>.

###
### Installation
###

# 1) Copy this script to your Quake 4 server's root directory.
# 2) Change directory to your Quake 4 server's root directory.
# 3) Run the command 'chmod u+x ./q4maxupdater.sh' to make the script
#    executable.
# 4) Look further down in this file for the Variables section. The default
#    values for these variables should be fine, but it never hurts to double-
#    check.

###
### Usage
###

# 1) Shut down your Quake 4 server
# 2) Change directory to your Quake 4 server's root directory.
# 3) Run the command './q4maxupdater.sh'.
#
# That's it. Once it's done start your Quake 4 server back up and you're good to
# go. Remember to add the line '+set fs_game q4max' to your server's command
# line to start up your server using Q4Max.
#
# If you haven't done so you should probably edit the Q4Max config file. It's
# located at q4max/server.cfg .

###
### Variables. **** SET THESE ****
###

# The path to the wget program. Run 'whereis wget' to find out where it is on
# your system.
wget_bin="/usr/local/bin/wget"

###
### The script starts here. Please don't change anything below this line.
###

###
### Welcome Message
###

echo
echo "Welcome to the Linux Q4Max update tool."
echo

###
### Initial Error Checking
###
### Make sure the system and Q4 environment is set up.
###

# Make sure wget exists.

echo -n "Checking for wget... "
if [ -e $wget_bin ]
then
	echo "OK"
else
	echo "Failed"
	echo
	echo "Unable to locate the wget program."
	echo "Please verify the path to the wget program in this script is correct or contact the system administrator."
	echo
	exit 1
fi

# Make sure we're running the script from the right directory (the Q4 server's
# root directory).

echo -n "Verifying current directory... "
if [ -e "./q4ded.x86" ]
then
	echo "OK"
else
	echo "Failed"
	echo
	echo "Please run this update script from your Quake 4 server's root directory."
	echo
	exit 1
fi

# Make sure the q4max directory exists. If its not there then create it.

echo -n "Checking for q4max directory... "
if [ -d "./q4max" ]
then
	echo "Found"
else
	echo "Not Found"
	echo "Creating q4max directory... OK"
	mkdir ./q4max
fi

###
### Fetch the Q4Max index.
###

echo -n "Downloading the latest Q4Max file list... "
$wget_bin -q -nc http://q4max.fnatic.com/q4max/index.idx
if [ -e "./index.idx" ]
then
	echo "OK"
else
	echo "Failed"
	echo
	echo "Unable to download the Q4Max file list. Please try again later."
	echo
	exit 1
fi

###
### Verify the index header.
###

# Remove Windows line breaks in the index.idx file first.
tr -d '\15\32' < ./index.idx > ./index.idx.tmp
mv ./index.idx.tmp ./index.idx

header=`head -n 1 ./index.idx | sed -e 's/[^A-Z_]//g'`
echo -n "Verifying the Q4Max file list... "
if [ "$header" == "STEAMFISH_HEADER" ]
then
	echo "OK"
else
	echo "Failed"
	echo
	echo "The Q4Max file list appears to be corrupted. Please try again."
	echo

	rm -f ./index.idx
	exit 1
fi

###
### Parse the file and download the files.
###

counter="2"
num_lines=`wc -l ./index.idx | sed -e 's/^[ ]*//g' | cut -d " " -f 1`
updated_files="0"
ignored_updated_files="0"
ignored_windows_files="0"
bytes_downloaded="0"

echo
echo "Downloading Q4Max files"
echo

while [ "$counter" -le "$num_lines" ]
do
	# Get the next three lines of the file. The first line should be the
	# URL of the file, the second is where to put it, and the third is
	# the size of the file.

	file_url=`sed -n "${counter}p" ./index.idx`
	counter=`echo $counter+1 | bc -l`

	file_target=`sed -n "${counter}p" ./index.idx`
	file_target=`echo "$file_target" | sed -e 's/\\\\/\\//g'`
	counter=`echo $counter+1 | bc -l`

	file_size=`sed -n "${counter}p" ./index.idx`
	counter=`echo $counter+1 | bc -l`

	# Ignore Windows specific files.
	file_name=`echo "$file_url" | sed -e 's/^http:\/\/\([a-zA-Z.0-9_-]*\/\)*//'`
	file_extension=`echo $file_name | sed -e 's/^\([a-zA-Z.0-9_-]*\.\)*//'`

	if [[ $file_extension = "exe" || $file_extension = "bat" || $file_extension = "dll" ]]
	then
		echo "Ignoring:    $file_name... OK (Windows only file)"
		ignored_windows_files=`echo $ignored_windows_files+1 | bc -l`
	else
		# Ignore files whose size matches the current file.
		current_size=`ls -l $file_target 2>/dev/null | awk '{print $5}'`

		if [ "$current_size" == "$file_size" ]
		then
			echo "Ignoring:    $file_name... OK (Up to date)"
			ignored_updated_files=`echo $ignored_updated_files+1 | bc -l`
		else
			# Download the file
			echo -n "Downloading: $file_name ($file_size bytes)... "

			# Backup the original file.
			if [ -e ./$file_name ]
			then
				mv -f ./$file_name ./$file_name.bak
			fi

			$wget_bin -q -O $file_name $file_url

			echo "OK"

			# Verify the file
			new_size=`ls -l $file_name 2>/dev/null | awk '{print $5}'`

			echo -n "Verifying:   $file_name... "
			if [ "$new_size" == "$file_size" ]
			then
				echo "OK"

				# increment the bytes downloaded count.
				bytes_downloaded=`echo $bytes_downloaded+$file_size | bc -l`
				# Delete the unused backup.
				rm -f ./$file_name.bak
			else
				echo
				echo "There was a problem downloading the file $file_name. Please try again later"
				echo

				# Restore the backed up file.
				mv -f ./$file_name.bak ./$file_name
				rm -f ./index.idx
				exit 1
			fi

			# Copy the file to the right location if it needs to
			# go anywhere other than the current directory.

			need_to_copy=`echo "$file_target" | grep -c ^..`

			if [ "$need_to_copy" == "1" ]
			then
				mv -f $file_name $file_target 2>/dev/null
			fi

			updated_files=`echo $updated_files+1 | bc -l`
		fi
	fi
done

###
### Delete the index file
###

rm -f ./index.idx

###
### All done!
###

echo
echo "Q4Max has been updated."
echo "$updated_files file(s) updated."
echo "$ignored_updated_files file(s) ignored. Already up to date."
echo "$ignored_windows_files file(s) ignored. Windows only."
echo "$bytes_downloaded bytes downloaded."
echo

exit 0
