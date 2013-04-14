#!/bin/sh
function failed()
{
    echo "Failed: $@" >&2
    exit 1
}

function usage()
{
    echo "Usage: $0 (-c configfile)"
    exit 2
}

function lowerCase() {
	echo "$1" | tr -d "[:space:]" | tr "[:upper:]" "[:lower:]"
}

while [ $# -gt 0 ]
do
    case "$1" in
        -c) BUILD_CONFIG_FILE=$2; shift;;
        *)	usage;;
    esac
    shift
done

set -ex

# Setting the needed variables

clear
if [ "$BUILD_CONFIG_FILE" == "" ]; then
. "$WORKSPACE/build.config"
else
. "$WORKSPACE/$BUILD_CONFIG_FILE"
fi

export OUTPUT=$WORKSPACE/output
rm -rf $OUTPUT
mkdir -p $OUTPUT
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
S3_UPLOAD_LOCATION="s3://burntide-clients/$LCASE_CLIENT_NAME/$LCASE_PROJECT_NAME/build/iphone/$BUILD_NUMBER"

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
        # Set the bundle identifier
        $PLIST_BUDDY -c "Set :CFBundleIdentifier $(eval echo \$`echo BundleIdentifier$CONFIG`)" "$INFO_PLIST"
        # Set variables
		PROVISIONING=$(eval echo \$`echo Provision$CONFIG`)
        CERTIFICATE="$PROVISIONING_PROFILE_PATH/$PROVISIONING.mobileprovision"
		# Build
        if [ "$TARGET_NAME" != "" ] 
        then
            $XCODEBUILD -configuration $CONFIG -target "$TARGET_NAME" -sdk $SDK clean;
            $XCODEBUILD -configuration $CONFIG -target "$TARGET_NAME" -sdk $SDK || failed build;
        else
            $XCODEBUILD -configuration $CONFIG -sdk $SDK clean;
            $XCODEBUILD -configuration $CONFIG -sdk $SDK || failed build;
        fi
		# Create ipa
		OTA_NAME="$APP_FILENAME-$CONFIG-manifest.plist"
		IPA_NAME="$APP_FILENAME-$CONFIG.ipa"
		OTA_URL="$(eval echo \$`echo OTAUrl$CONFIG`)"
		APP_FILE=`find "$WORKSPACE/build/$CONFIG-iphoneos" -name "*.app"`
        $XCRUN -sdk $SDK PackageApplication -v "$APP_FILE" -o "$OUTPUT/$IPA_NAME" --sign "$(eval echo \$`echo Codesign$CONFIG`)" --embed "$CERTIFICATE";
        # Zip & Copy the dSYM file & remove the zip
        cd "$WORKSPACE/build/$CONFIG-iphoneos/"
        tar -pczf "$APP_FILENAME.tar.gz" "$APP_FILENAME.app.dSYM"
        cd "$WORKSPACE"
        cp "$WORKSPACE/build/$CONFIG-iphoneos/$APP_FILENAME.tar.gz" "$OUTPUT/$APP_FILENAME.tar.gz"
        rm "$WORKSPACE/build/$CONFIG-iphoneos/$APP_FILENAME.tar.gz"
        # Copy the icon files
		if [ -f "$WORKSPACE/$OTASmallIcon" ]; then
			cp $WORKSPACE/$OTASmallIcon $OUTPUT/Icon-57.png
		fi
		if [ -f "$WORKSPACE/$OTALargeIcon" ]; then
			cp $WORKSPACE/$OTALargeIcon $OUTPUT/Icon-512.png
		fi
        # Copy the release noteS
        if [ -f "$WORKSPACE/$RELEASENOTE" ]; then
            cp $WORKSPACE/$RELEASENOTE $OUTPUT/$RELEASENOTE
        fi
		# Create the manifest file
		bundle_version=$(defaults read $WORKSPACE/$INFO_PLIST CFBundleShortVersionString)
		bundle_id=$(defaults read $WORKSPACE/$INFO_PLIST CFBundleIdentifier)
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
		                   <string>$OTA_URL/$BUILD_NUMBER/$IPA_NAME</string>
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
		                   <string>$OTA_URL/$BUILD_NUMBER/Icon-57.png</string>
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
		                   <string>$OTA_URL/$BUILD_NUMBER/Icon-512.png</string>
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
		
		# Upload files to Amazon S3
		
		LCASE_IPA_NAME=`lowerCase "$IPA_NAME"`
		LCASE_OTA_NAME=`lowerCase "$OTA_NAME"`

		$S3_CMD put -m "application/octet-stream" "$OUTPUT/$IPA_NAME" "$S3_UPLOAD_LOCATION/$LCASE_IPA_NAME"
		$S3_CMD put -m "text/xml" "$OUTPUT/$OTA_NAME" "$S3_UPLOAD_LOCATION/$LCASE_OTA_NAME"
		if [ "$OTASmallIcon" != "" ]
		then
			$S3_CMD put "$WORKSPACE/$OTASmallIcon" "$S3_UPLOAD_LOCATION/Icon-57.png"
		fi
		
    done
done
