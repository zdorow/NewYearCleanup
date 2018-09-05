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
#   Version: 2.0
#
#   Description: This script will delete all static user groups
#   Usage: sudo sh /path/to/deleteStaticUserGroups.sh
#   
#   CAUTION:This script uses hardcoded variables. Please check them before running.
#
#   Examples: 
#   jssURL="jamf.jamfcloud.com" or jss.company.com:8443
#   apiUserAndPass="admin:jamf1234"
#
####################################################################################################

##### VALUES THAT NEED TO BE FILLED IN!
jssURL="" # jss.company.com:8443
apiUserAndPass="" # apiUserAndPass="admin:jamf1234"

# File creation
userList=`mktemp /tmp/deleteStatic.XXXXXXXXX`
xslt=`mktemp /tmp/deleteStatic.XXXXXXXXX`

# Building XML
cat << EOF > "$xslt"
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text"/>
<xsl:template match="/user_groups">
<xsl:for-each select="user_group">
<xsl:value-of select="id"/>
<xsl:text>&#9;</xsl:text>
<xsl:value-of select="is_smart"/>
<xsl:text>&#xa;</xsl:text>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
EOF
curl -sku "$apiUserAndPass" https://"$jssURL"/JSSResource/usergroups -H "content-type: text/xml" | xsltproc "$xslt" - > "$userList"
# if [ -s $xslt ];then
# echo ""
# echo "There are already no static user groups."
# echo "Nothing to delete exiting script...."
# echo ""
# exit 99
# fi
while read id is_smart;do
  if [[ "$is_smart" == "false" ]];then
    echo ""
    echo "$id is a static group that is being deleted"
    echo ""
    curl -sku "$apiUserAndPass" https://"$jssURL"/JSSResource/usergroups/id/$id -X DELETE
    echo ""
  fi
done < "$userList"
rm "$xslt"
rm "$userList"
echo ""
echo ""
echo "-----------------End of script------------------------------------------"
echo ""
echo "All static groups have been attempted to be deleted!"
echo ""
echo "If any returned something other than the folling:"
echo ""
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><static_user_group><id>XX</id></static_user_group>"
echo ""
echo "the group might not have been deleted."
echo "Read the output for more information."
echo ""
exit 0
