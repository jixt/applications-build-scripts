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
    echo "Usage: $0 -t koomoda_account_token -a koomoda_app_token (-c configfile -an app_name -bi bundle_id)"
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
		-bi) BUNDLE_ID=$2; shift;;
        *)	usage;;
    esac
    shift
done

if [ "$K_ACCOUNT_TOKEN" == "" -o "$K_APP_TOKEN" == "" ]
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

# Koomoda

KOOMODA_API_URL="https://www.koomoda.com/app/upload"

# Set the short version number
CFBundleShortVersionString=$BUILD_NUMBER
$PLIST_BUDDY -c "Set :CFBundleShortVersionString $CFBundleShortVersionString" "$INFO_PLIST"

# Set the date
CFBuildDate=$(date +%d-%m-%Y)
$PLIST_BUDDY -c "Add :CFBuildDate string $CFBuildDate" "$INFO_PLIST"

# Set the settings values
if [ "$SETTINGS_BUNDLE" != "" ]
then
	$PLIST_BUDDY -c "Set :PreferenceSpecifiers:2:DefaultValue $CFBundleShortVersionString" "$WORKSPACE/$SETTINGS_BUNDLE/Root.plist"
fi

# Build the application for the several levels (Debug, Release, ...) &
# create an ipa out of them

for SDK in $SDKS; do
    for CONFIG in $CONFIGURATIONS; do
		# Set variables
		PROVISIONING=$(eval echo \$`echo Provision$CONFIG`)
		CODE_SIGN_IDENTITY=$(eval echo \$`echo Codesign$CONFIG`)
        CERTIFICATE="$PROVISIONING_PROFILE_PATH/$PROVISIONING.mobileprovision"
		if [ "$BUNDLE_ID" != "" ] 
        then
			BUNDLE_IDENTIFIER=$BUNDLE_ID
		else
			BUNDLE_IDENTIFIER=$(eval echo \$`echo BundleIdentifier$CONFIG`)
		fi
        # Set the bundle identifier
        $PLIST_BUDDY -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$INFO_PLIST"
		# Build
        if [ "$TARGET_NAME" != "" ] 
        then
            $XCODEBUILD -configuration $CONFIG -target "$TARGET_NAME" -sdk $SDK clean;
			if [ "$APP_NAME" != "" ] 
			then
				$XCODEBUILD -configuration $CONFIG -target "$TARGET_NAME" -sdk $SDK APP_NAME=$APP_NAME BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" || failed build;
			else
            	$XCODEBUILD -configuration $CONFIG -target "$TARGET_NAME" -sdk $SDK BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" || failed build;
			fi
        else
            $XCODEBUILD -configuration $CONFIG -sdk $SDK clean;
			if [ "$APP_NAME" != "" ] 
			then
            	$XCODEBUILD -configuration $CONFIG -sdk $SDK APP_NAME=$APP_NAME BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" || failed build;
			else
				$XCODEBUILD -configuration $CONFIG -sdk $SDK BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" || failed build;
			fi	 
        fi
		# Create ipa
		OTA_NAME="$APP_FILENAME-$CONFIG-manifest.plist"
		IPA_NAME="$APP_FILENAME-$CONFIG.ipa"
		OTA_URL="$(eval echo \$`echo OTAUrl$CONFIG`)"
		APP_FILE=`find "$WORKSPACE/build/$CONFIG-iphoneos" -name "*.app"`
        $XCRUN -sdk $SDK PackageApplication -v "$APP_FILE" -o "$OUTPUT/$IPA_NAME" --sign "$CODE_SIGN_IDENTITY" --embed "$CERTIFICATE";
        # Zip & Copy the dSYM file & remove the zip
        cd "$WORKSPACE/build/$CONFIG-iphoneos/"
        tar -pczf "$APP_FILENAME.tar.gz" "$APP_FILENAME.app.dSYM"
        cd "$WORKSPACE"
        cp "$WORKSPACE/build/$CONFIG-iphoneos/$APP_FILENAME.tar.gz" "$OUTPUT/$APP_FILENAME.tar.gz"
        rm "$WORKSPACE/build/$CONFIG-iphoneos/$APP_FILENAME.tar.gz"
        # Copy the icon files
		if [ -f "$WORKSPACE/$OTASmallIcon" ]; then
			cp "$WORKSPACE/$OTASmallIcon" "$OUTPUT/Icon-57.png"
		fi
		if [ -f "$WORKSPACE/$OTALargeIcon" ]; then
			cp "$WORKSPACE/$OTALargeIcon" "$OUTPUT/Icon-512.png"
		fi
        # Copy the release noteS
        if [ -f "$WORKSPACE/$RELEASENOTE" ]; then
            cp "$WORKSPACE/$RELEASENOTE" "$OUTPUT/$RELEASENOTE"
        fi
		# Create the manifest file
		bundle_version=$(defaults read "$WORKSPACE/$INFO_PLIST" CFBundleShortVersionString)
		bundle_id=$(defaults read "$WORKSPACE/$INFO_PLIST" CFBundleIdentifier)
		cat <<-EOF > $OUTPUT/$OTA_NAME
		<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict>
		   <key>items</key>
		   <array>
		       <dict>
		           <key>assets</key>
		           <array>
		               <dict>
		                   <key>kind</key>
		                   <string>software-package</string>
		                   <key>url</key>
		                   <string>{{ipa}}</string>
		               </dict>
		EOF
		if [ -f "$WORKSPACE/$OTASmallIcon" ]; then
			cat <<-EOF >> $OUTPUT/$OTA_NAME
		               <dict>
		                   <key>kind</key>
		                   <string>display-image</string>
		                   <key>needs-shine</key>
		                   <true/>
		                   <key>url</key>
		                   <string>{{icon57}}</string>
		               </dict>
		EOF
		fi
		if [ -f "$WORKSPACE/$OTALargeIcon" ]; then
			cat <<-EOF >> $OUTPUT/$OTA_NAME
		               <dict>
		                   <key>kind</key>
		                   <string>full-size-image</string>
		                   <key>needs-shine</key>
		                   <true/>
		                   <key>url</key>
		                   <string>{{icon512}}</string>
		               </dict>
		EOF
		fi
		cat <<-EOF >> $OUTPUT/$OTA_NAME
		           </array>
		           <key>metadata</key>
		           <dict>
		               <key>bundle-identifier</key>
		               <string>$bundle_id</string>
		               <key>bundle-version</key>
		               <string>$bundle_version</string>
		               <key>kind</key>
		               <string>software</string>
		               <key>title</key>
		               <string>$APP_FILENAME</string>
		           </dict>
		       </dict>
		   </array>
		</dict>
		</plist>
		EOF
		
		# Upload files to Koomoda
		
		LCASE_IPA_NAME=`lowerCase "$IPA_NAME"`
		LCASE_OTA_NAME=`lowerCase "$OTA_NAME"`
		mv "${OUTPUT}/${IPA_NAME}" "${OUTPUT}/${LCASE_IPA_NAME}"
		mv "${OUTPUT}/${OTA_NAME}" "${OUTPUT}/${LCASE_OTA_NAME}"
		curl -3 $KOOMODA_API_URL -F file=@"${OUTPUT}/${LCASE_IPA_NAME}" -F icon=@"${OUTPUT}/Icon-57.png" -F manifest=@"${OUTPUT}/${LCASE_OTA_NAME}" -F user_token="${K_ACCOUNT_TOKEN}" -F app_token="${K_APP_TOKEN}" -F app_version="${BUILD_NUMBER}"
    done
done

#Done!