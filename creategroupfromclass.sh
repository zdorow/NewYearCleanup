#!/bin/bash

####################################################################################################
#
# Copyright (c) 2018, JAMF Software, LLC.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the JAMF Software, LLC nor the
#                 names of its contributors may be used to endorse or promote products
#                 derived from this software without specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#   Authors: Mike Levenick, Tyrone Luedtke, Zach Dorow
#   Last Modified: 09/04/18
#   Version: 2.00
#
#   Description: This script will create a static user group containing all the users from a specified class 
#   Usage: sudo sh /path/to/creategroupfromclass.sh
#
#
####################################################################################################

status=6
until [ $status -eq 0 ]; do

#Username Entry
echo ""
echo "Please enter the Jamf Pro API username: "
read jssuser
echo ""
#Password Entry 
echo "Please enter the password for $jssuser: "
read -s jsspass
echo ""

#URL of Jamf Pro server entry
echo "Please enter the Jamf Pro URL including the port ex. https://jamfit.jamfsw.com:8443 if we are locally hosted"
echo "No port needed for cloud hosted instances ex. https://jamfit.jamfsw.com" 
read jssurl
echo ""

#Removal of trailing slash if found in url
if [ $(echo "${jssurl: -1}") = "/" ]; then
	jssurl=$(echo $jssurl | sed 's/.$//')
fi

test=$(/usr/bin/curl --fail -ksu "$jssuser":"$jsspass" "$jssurl/JSSResource/classes" -X GET)
status=$?
if [ $status -eq 6 ]; then
	echo ""
	echo "The Jamf Pro URL is reporting an error. Please try again." 
	echo "If the error persists please check permissions and internet connection." 
	echo ""
#	exit 99
elif [ $status -eq 22 ]; then
	echo ""
	echo "Username and/or password is incorrect."
	echo "If the error persists please check permissions and internet connection." 
	echo ""
#	exit 99
elif [ $status -eq 0 ]; then
    echo "Connection test successful!"
else
    echo ""
    echo "Something really went wrong,"
    echo "Lets try this again."
fi
done

file1=`mktemp /tmp/classToStatic.XXXXXXXXX` # Temp file used to create computer name variables
file2=`mktemp /tmp/classToStatic.XXXXXXXXX`
csvFile=`mktemp /tmp/classToStatic.XXXXXXXXX` # CSV file used as our counter and computer name variable for our CURL loop

# Getting ids of the classes
/usr/bin/curl -sk -u "$jssuser":"$jsspass" -H "Accept: application/xml" $jssurl/JSSResource/classes | xmllint --format - --xpath /id > $file1

/bin/cat $file1 | grep 'id' | cut -f2 -d">" | cut -f1 -d"<" >> $csvFile

count=`cat $csvFile | awk -F, '{print $1}'`

IFS=$'\n'

for i in ${count}; do
	echo ""
	echo "Converting Class $i"
	echo ""

	# Create a new group from a class
	classxml=`curl -ksu "$jssuser":"$jsspass" -H "Accept: text/xml" $jssurl/JSSResource/classes/id/$i`
	studentidlist=`echo $classxml | xpath //class/student_ids/id 2>/dev/null `
	classname=`echo $classxml | xpath //class/name 2>/dev/null `
	#echo $studentidlist
	#studentidlistwithusers=`echo $studentidlist | s/'</id><id>'/'</id></user><user><id>'/g`
	studentidlistwithusers=${studentidlist//<\/id><id>/<\/id><\/user><user><id>}
	newgroupname=${classname//<name>/}
	newgroupname=${newgroupname//<\/name>/}

	beginning="<?xml version=\"1.0\" encoding=\"utf-8\"?><user_group><name>$newgroupname</name><is_smart>false</is_smart><users><user>"
	ending="</user></users></user_group>"
	echo $newgroupname
	#usersection="<id>363</id></user><user><id>127</id>"
	#separator="</user><user>"

	#  Concatenate the whole thing 
	xmlput="$beginning$studentidlistwithusers$ending"

	# Create XML to upload
	echo > /tmp/put.xml "$xmlput"

	# Upload the XML
	echo ""
	curl -ksu "$jssuser":"$jsspass" -H "Content-type: text/xml" $jssurl/JSSResource/usergroups/id/0 -X POST -T /tmp/put.xml
	echo ""
done

# Cleanup 
rm -rf $file1
rm -rf $file2
rm -rf $csvFile
rm -rf /tmp/put.xml

echo ""
echo ""
echo "-----------------End of script------------------------------------------"
echo ""
echo "We have successfully attempted to turn all classes into static groups."
echo ""
echo "If any returned something other than the following:"
echo ""
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><static_user_group><id>XX</id></static_user_group>"
echo ""
echo "the group might not have been created."
echo "Read the output for more information."
echo ""
exit 0