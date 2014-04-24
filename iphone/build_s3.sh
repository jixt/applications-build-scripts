#
# Copyright (C) 2014 BurnTide
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

#!/bin/sh
function failed() {
    echo "Failed: $@" >&2
    exit 1
}

function usage() {
    echo "Usage: $0 -xc xcode_config -s3b s3bucket (-c configfile -s3c s3configfile -an app_name -bi bundle_id -ci code_sign_identity)"
    exit 2
}

function lowerCase() {
	echo "$1" | tr -d "[:space:]" | tr "[:upper:]" "[:lower:]"
}

while [ $# -gt 0 ]
do
    case "$1" in
    	-s3c) S3_CMD_CONFIG_FILE=$2; shift;;
		-s3b) S3_BUCKET=$2; shift;;
        -c) BUILD_CONFIG_FILE=$2; shift;;
        -an) APP_NAME=$2; shift;;
		-bi) BUNDLE_IDENTIFIER=$2; shift;;
		-ci) CODE_SIGN_IDENTITY=$2; shift;;
		-xc) XCODE_CONFIG=$2; shift;;
        *)	usage;;
    esac
    shift
done

if [ "$S3_BUCKET" == "" -o "$XCODE_CONFIG" == ""]
then
	usage;
fi

set -ex

# Setting the needed variables

clear
if [ "$BUILD_CONFIG_FILE" == "" ]; then
. "$WORKSPACE/build.config"
else
. "$WORKSPACE/$BUILD_CONFIG_FILE"
fi

export OUTPUT="$WORKSPACE/output"
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"
PROVISIONING_PROFILE_PATH=~/Library/MobileDevice/Provisioning\ Profiles/
KEYCHAIN=~/Library/Keychains/login.keychain
XCODEBUILD="/usr/bin/xcodebuild"
XCRUN="/usr/bin/xcrun"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

# Create lowercase variables for client and project

LCASE_CLIENT_NAME=`lowerCase "$CLIENT_NAME"`
LCASE_PROJECT_NAME=`lowerCase "$PROJECT_NAME"`

# Amazon AWS

S3_CMD="/usr/local/bin/s3cmd"
S3_UPLOAD_LOCATION="s3://$S3_BUCKET/$LCASE_CLIENT_NAME/$LCASE_PROJECT_NAME/build/iphone/$BUILD_NUMBER"

# Add the build script core

source ./build_project_core.sh
		
# Upload files to Amazon S3
		
mv "${OUTPUT}/${IPA_NAME}" "${OUTPUT}/${LCASE_IPA_NAME}"
mv "${OUTPUT}/${OTA_NAME}" "${OUTPUT}/${LCASE_OTA_NAME}"
		
if [ "$S3_CMD_CONFIG_FILE" == "" ]; then
	$S3_CMD put -m "application/octet-stream" "$OUTPUT/$LCASE_IPA_NAME" "$S3_UPLOAD_LOCATION/$LCASE_IPA_NAME"
	$S3_CMD put -m "text/xml" "$OUTPUT/$LCASE_OTA_NAME" "$S3_UPLOAD_LOCATION/$LCASE_OTA_NAME"
	if [ "$OTASmallIcon" != "" ]
	then
		$S3_CMD put "$WORKSPACE/$OTASmallIcon" "$S3_UPLOAD_LOCATION/Icon-57.png"
	fi
else
	$S3_CMD put -c ~/.$S3_CMD_CONFIG_FILE -m "application/octet-stream" "$OUTPUT/$LCASE_IPA_NAME" "$S3_UPLOAD_LOCATION/$LCASE_IPA_NAME"
	$S3_CMD put -c ~/.$S3_CMD_CONFIG_FILE -m "text/xml" "$OUTPUT/$LCASE_OTA_NAME" "$S3_UPLOAD_LOCATION/$LCASE_OTA_NAME"
	if [ "$OTASmallIcon" != "" ]
	then
		$S3_CMD put -c ~/.$S3_CMD_CONFIG_FILE  "$WORKSPACE/$OTASmallIcon" "$S3_UPLOAD_LOCATION/Icon-57.png"
	fi
fi
		
# And now you're done!
