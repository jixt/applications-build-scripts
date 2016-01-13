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
    echo "Usage: $0 -xc xcode_config -t koomoda_account_token -a koomoda_app_token -an app_name (-c configfile -pp project_path -bn build_number)"
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
		-xc) XCODE_CONFIG=$2; shift;;
		-pp) PROJECT_PATH=$2; shift;;
		-bn) APP_BUILD_NUMBER=$2; shift;;
        *)	usage;;
    esac
    shift
done

if [ "$K_ACCOUNT_TOKEN" == "" -o "$K_APP_TOKEN" == "" -o "$XCODE_CONFIG" == ""  -o "$APP_NAME" == ""  -o "$XCODE_CONFIG" == ""]
then
	usage;
fi

set -ex

# Reset the workspace if needed

PROJECT_BASE=$WORKSPACE

if [ "$PROJECT_PATH" != "" ]; then
	PROJECT_BASE=$PROJECT_PATH
fi

# Setting the needed variables

clear
if [ "$BUILD_CONFIG_FILE" == "" ]; then
. "$PROJECT_BASE/build.config"
else
. "$PROJECT_BASE/$BUILD_CONFIG_FILE"
fi

export OUTPUT="$PROJECT_BASE/output"
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

#Set the build number if there is one set as parameter
if [ "$APP_BUILD_NUMBER" != "" ]; then
	BUILD_NUMBER=$APP_BUILD_NUMBER
fi

# Set the short version number
CFBundleShortVersionString=$BUILD_NUMBER
$PLIST_BUDDY -c "Set :CFBundleShortVersionString $CFBundleShortVersionString" "$APP_INFO_PLIST"
$PLIST_BUDDY -c "Set :CFBundleShortVersionString $CFBundleShortVersionString" "$WATCHEXTENSION_INFO_PLIST"
$PLIST_BUDDY -c "Set :CFBundleShortVersionString $CFBundleShortVersionString" "$WATCHAPP_INFO_PLIST"

# Set the version number
CFBundleVersion=$BUILD_NUMBER
$PLIST_BUDDY -c "Set :CFBundleVersion $CFBundleVersion" "$APP_INFO_PLIST"
$PLIST_BUDDY -c "Set :CFBundleVersion $CFBundleVersion" "$WATCHEXTENSION_INFO_PLIST"
$PLIST_BUDDY -c "Set :CFBundleVersion $CFBundleVersion" "$WATCHAPP_INFO_PLIST"

# Set the settings values
if [ "$SETTINGS_BUNDLE" != "" ]
then
	$PLIST_BUDDY -c "Set :PreferenceSpecifiers:2:DefaultValue $CFBundleShortVersionString" "$PROJECT_BASE/$SETTINGS_BUNDLE/Root.plist"
fi

# Build the application for the several levels (Debug, Release, ...) &
# create an ipa out of them

SDK="iphoneos"

# Set Provisioning profile
APP_PROVISIONING=$(eval echo \$`echo AppProvision$XCODE_CONFIG`)
WATCHEXTENSION_PROVISIONING=$(eval echo \$`echo WatchExtensionProvision$XCODE_CONFIG`)
WATCHAPP_PROVISIONING=$(eval echo \$`echo WatchAppProvision$XCODE_CONFIG`)

# Now build the application
if [ "$TARGET_NAME" != "" ] 
then
	$XCODEBUILD -configuration "$XCODE_CONFIG" -target "$TARGET_NAME" -sdk $SDK APP_NAME="$APP_NAME" APP_PROFILE="$APP_PROVISIONING" WATCH_EXTENSION_PROFILE="$WATCHEXTENSION_PROVISIONING" WATCH_APP_PROFILE="$WATCHAPP_PROVISIONING" build CONFIGURATION_BUILD_DIR="$PROJECT_BASE/build/$XCODE_CONFIG-iphoneos" || failed build;	 
fi
# Create the ipa file
OTA_NAME="$APP_FILENAME-$XCODE_CONFIG-manifest.plist"
IPA_NAME="$APP_FILENAME-$XCODE_CONFIG.ipa"
OTA_URL="$(eval echo \$`echo OTAUrl$XCODE_CONFIG`)"
APP_FILE=`find "$PROJECT_BASE/build/$XCODE_CONFIG-iphoneos" -name "*.app"`
$XCRUN -sdk $SDK PackageApplication -v "$APP_FILE" -o "$OUTPUT/$IPA_NAME" --embed "$CERTIFICATE";
# Zip & Copy the dSYM file & remove the zip
cd "$PROJECT_BASE/build/$XCODE_CONFIG-iphoneos/"
tar -pczf "$APP_FILENAME.tar.gz" "$TARGET_NAME.app.dSYM"
cd "$PROJECT_BASE"
cp "$PROJECT_BASE/build/$XCODE_CONFIG-iphoneos/$APP_FILENAME.tar.gz" "$OUTPUT/$APP_FILENAME.tar.gz"
rm "$PROJECT_BASE/build/$XCODE_CONFIG-iphoneos/$APP_FILENAME.tar.gz"
# Copy the icon files
	if [ -f "$PROJECT_BASE/$OTASmallIcon" ]; then
		cp "$PROJECT_BASE/$OTASmallIcon" "$OUTPUT/Icon-57.png"
	fi
	if [ -f "$PROJECT_BASE/$OTALargeIcon" ]; then
		cp "$PROJECT_BASE/$OTALargeIcon" "$OUTPUT/Icon-512.png"
	fi
	      # Copy the release noteS
	      if [ -f "$PROJECT_BASE/$RELEASENOTE" ]; then
	          cp "$PROJECT_BASE/$RELEASENOTE" "$OUTPUT/$RELEASENOTE"
	      fi
	# Create the manifest file
	bundle_version=$(defaults read "$PROJECT_BASE/$APP_INFO_PLIST" CFBundleShortVersionString)
	bundle_id=$(defaults read "$PROJECT_BASE/$APP_INFO_PLIST" CFBundleIdentifier)
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
	if [ -f "$PROJECT_BASE/$OTASmallIcon" ]; then
		cat <<-EOF >> $OUTPUT/$OTA_NAME
	               <dict>
	                   <key>kind</key>
	                   <string>display-image</string>
	                   <key>url</key>
	                   <string>{{icon57}}</string>
	               </dict>
	EOF
	fi
	if [ -f "$PROJECT_BASE/$OTALargeIcon" ]; then
		cat <<-EOF >> $OUTPUT/$OTA_NAME
	               <dict>
	                   <key>kind</key>
	                   <string>full-size-image</string>
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
curl -1 $KOOMODA_API_URL -F file=@"${OUTPUT}/${LCASE_IPA_NAME}" -F icon=@"${OUTPUT}/Icon-57.png" -F manifest=@"${OUTPUT}/${LCASE_OTA_NAME}" -F user_token="${K_ACCOUNT_TOKEN}" -F app_token="${K_APP_TOKEN}" -F app_version="${BUILD_NUMBER}"


# And now you're done!
