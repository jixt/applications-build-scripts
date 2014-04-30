#
# Copyright (C) 2013 BurnTide
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#!/bin/sh

function failed()
{
    echo "Failed: $@" >&2
    exit 1
}

function usage()
{
    echo "Usage: $0 -xc xcode_config -t koomoda_account_token -a koomoda_app_token (-c configfile -an app_name -bi bundle_id -ci code_sign_identity)"
    exit 2
}

function lowerCase() {
	echo "$1" | tr -d "[:space:]" | tr "[:upper:]" "[:lower:]"
}

while [ $# -gt 0 ]
do
    case "$1" in
		-t)	K_ACCOUNT_TOKEN=$2; shift;;
		-a)	K_APP_TOKEN=$2; shift;;
        -c) BUILD_CONFIG_FILE=$2; shift;;
		-an) APP_NAME=$2; shift;;
		-bi) BUNDLE_IDENTIFIER=$2; shift;;
		-ci) CODE_SIGN_IDENTITY=$2; shift;;
		-xc) XCODE_CONFIG=$2; shift;;
        *)	usage;;
    esac
    shift
done

if [ "$K_ACCOUNT_TOKEN" == "" -o "$K_APP_TOKEN" == "" -o "$XCODE_CONFIG" == ""]
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

# Koomoda

KOOMODA_API_URL="https://www.koomoda.com/app/upload"

# Add the build script core

if [ "$WORKSPACE_NAME" == ""]; then
	echo "Project build!"
	source ./build_project_core.sh
else
	echo "Workspace build!"
	source ./build_workspace_core.sh
fi	

# Upload files to Koomoda

LCASE_IPA_NAME=`lowerCase "$IPA_NAME"`
LCASE_OTA_NAME=`lowerCase "$OTA_NAME"`
mv "${OUTPUT}/${IPA_NAME}" "${OUTPUT}/${LCASE_IPA_NAME}"
mv "${OUTPUT}/${OTA_NAME}" "${OUTPUT}/${LCASE_OTA_NAME}"
curl -3 $KOOMODA_API_URL -F file=@"${OUTPUT}/${LCASE_IPA_NAME}" -F icon=@"${OUTPUT}/Icon-57.png" -F manifest=@"${OUTPUT}/${LCASE_OTA_NAME}" -F user_token="${K_ACCOUNT_TOKEN}" -F app_token="${K_APP_TOKEN}" -F app_version="${BUILD_NUMBER}"


# And now you're done!
