#
# Copyright (C) 2014 BurnTide
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

#!/bin/sh

function failed() {
    echo "Failed: $@"
    exit 2
}
function usage() {
	echo "Usage: $0  -bt build_type -an app_name -t koomoda_account_token -a koomoda_app_token (optional: -abn build_number)"
	exit 2
}
function lowerCase() {
	echo "$1" | tr -d "[:space:]" | tr "[:upper:]" "[:lower:]"
}

# Get the script parameters & check if all needed values are there.

while [ $# -gt 0 ]
do
    case "$1" in
		-t)	K_ACCOUNT_TOKEN=$2; shift;;
		-a)	K_APP_TOKEN=$2; shift;;
		-bt)BUILD_TYPE=$2; shift;;
		-an)APP_NAME=$2; shift;;
		-abn)APPLICATION_BUILD_NUMBER=$2; shift;;
		*)	usage;;
    esac
	shift
done

if [ "$K_APP_TOKEN" == "" -o "$K_APP_TOKEN" == "" -o "$BUILD_TYPE" == "" -o "$APP_NAME" == ""]
then
	usage;
fi

set -ex

export OUTPUT="$WORKSPACE/output"

# Set the application version number

APPLICATION_VERSION_NUMBER=$BUILD_NUMBER

if [ "$APPLICATION_BUILD_NUMBER" != "" ]
then
	APPLICATION_VERSION_NUMBER=$APPLICATION_BUILD_NUMBER
fi

# Create lowercase variables for client and project

# Upload files to Koomoda
#REPLACE_AMPESAND_STRING=""

APK_FILE=`find "${OUTPUT}" -name "*.apk"`
#FILE_NAME="$APP_NAME-$BUILD_TYPE.apk"
#LCASE_FILE_NAME=`lowerCase "$FILE_NAME"`
#LCASE_FILE_NAME=${LCASE_FILE_NAME//[&\']/$REPLACE_AMPESAND_STRING}

#mv "${OUTPUT}/${FILE_NAME}" "${OUTPUT}/${LCASE_FILE_NAME}"
mv "${OUTPUT}/logo.png" "${OUTPUT}/Icon-57.png"

# Koomoda

KOOMODA_API_URL="https://www.koomoda.com/app/upload"
curl -1 $KOOMODA_API_URL -F file=@"${APK_FILE}" -F icon=@"${OUTPUT}/Icon-57.png" -F user_token="${K_ACCOUNT_TOKEN}" -F app_token="${K_APP_TOKEN}" -F app_version="${APPLICATION_VERSION_NUMBER}" -F platform="android"


