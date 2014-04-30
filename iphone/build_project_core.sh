#
# Copyright (C) 2014 BurnTide
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#!/bin/sh

# Set the short version number
echo "Set the short version number"

CFBundleShortVersionString=$BUILD_NUMBER
$PLIST_BUDDY -c "Set :CFBundleShortVersionString $CFBundleShortVersionString" "$INFO_PLIST"

# Set the date
echo "Set the date"

CFBuildDate=$(date +%d-%m-%Y)
$PLIST_BUDDY -c "Add :CFBuildDate string $CFBuildDate" "$INFO_PLIST"

# Set the settings values
echo "Set the settings values"
if [ "$SETTINGS_BUNDLE" != "" ]
then
	$PLIST_BUDDY -c "Set :PreferenceSpecifiers:2:DefaultValue $CFBundleShortVersionString" "$WORKSPACE/$SETTINGS_BUNDLE/Root.plist"
fi

# Build the application for the several levels (Debug, Release, ...) &
# create an ipa out of them

SDK="iphoneos"

# Set Provisioning profile
echo "Set the provisioning profile"

PROVISIONING=$(eval echo \$`echo Provision$XCODE_CONFIG`)
# Set Code Sign Identity (if not already set with parameter)
if [ "$CODE_SIGN_IDENTITY" == "" ] 
then
	CODE_SIGN_IDENTITY=$(eval echo \$`echo Codesign$XCODE_CONFIG`)
fi	

# Set the certificate
echo "Set the certificate"

CERTIFICATE="$PROVISIONING_PROFILE_PATH/$PROVISIONING.mobileprovision"

# Set the bundle identifier in the info.plist (if not already set with parameter)
echo "Set the bundle identifier in the info.plist"

if [ "$BUNDLE_IDENTIFIER" == "" ] 
then
	BUNDLE_IDENTIFIER=$(eval echo \$`echo BundleIdentifier$XCODE_CONFIG`)
fi
$PLIST_BUDDY -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$INFO_PLIST"

# Now build the application
echo "Build the application"

if [ "$TARGET_NAME" != "" ] 
then
	if [ "$XCODE_PROJECT_NAME" != "" ] 
	then
		$XCODEBUILD -project "$XCODE_PROJECT_NAME".xcodeproj -configuration "$XCODE_CONFIG" -target "$TARGET_NAME" -sdk $SDK clean;
	else
		$XCODEBUILD -configuration "$XCODE_CONFIG" -target "$TARGET_NAME" -sdk $SDK clean;
	fi
	if [ "$APP_NAME" != "" ] 
	then
		if [ "$XCODE_PROJECT_NAME" != "" ] 
		then
			$XCODEBUILD -project "$XCODE_PROJECT_NAME".xcodeproj -configuration "$XCODE_CONFIG" -target "$TARGET_NAME" -sdk $SDK APP_NAME=$APP_NAME BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build;
		else
			$XCODEBUILD -configuration "$XCODE_CONFIG" -target "$TARGET_NAME" -sdk $SDK APP_NAME=$APP_NAME BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build;
		fi
	else
		if [ "$XCODE_PROJECT_NAME" != "" ] 
		then
      		$XCODEBUILD -project "$XCODE_PROJECT_NAME".xcodeproj -configuration "$XCODE_CONFIG" -target "$TARGET_NAME" -sdk $SDK BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build;
		else
			$XCODEBUILD -configuration "$XCODE_CONFIG" -target "$TARGET_NAME" -sdk $SDK BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build;
		fi
	fi
else
	$XCODEBUILD -configuration "$XCODE_CONFIG" -sdk $SDK clean;
	if [ "$APP_NAME" != "" ] 
	then
    	if [ "$XCODE_PROJECT_NAME" != "" ] 
		then
			$XCODEBUILD -project "$XCODE_PROJECT_NAME".xcodeproj -configuration "$XCODE_CONFIG" -sdk $SDK APP_NAME=$APP_NAME BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build;
		else
			$XCODEBUILD -configuration "$XCODE_CONFIG" -sdk $SDK APP_NAME=$APP_NAME BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build;
		fi
	else
		if [ "$XCODE_PROJECT_NAME" != "" ] 
		then
			$XCODEBUILD -project "$XCODE_PROJECT_NAME".xcodeproj -configuration "$XCODE_CONFIG" -sdk $SDK BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build;
		else
			$XCODEBUILD -configuration "$XCODE_CONFIG" -sdk $SDK BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build;
		fi
	fi	 
fi

# Create the ipa file
echo "Create the IPA file"

OTA_NAME="$PROJECT_NAME-$XCODE_CONFIG-manifest.plist"
IPA_NAME="$PROJECT_NAME-$XCODE_CONFIG.ipa"
OTA_URL="$(eval echo \$`echo OTAUrl$XCODE_CONFIG`)"
APP_FILE=`find "$WORKSPACE/build/$XCODE_CONFIG-iphoneos" -name "*.app"`
DSYM_FILE=`find "$WORKSPACE/build/$XCODE_CONFIG-iphoneos" -name "*.app.dSYM"`
$XCRUN -sdk $SDK PackageApplication -v "$APP_FILE" -o "$OUTPUT/$IPA_NAME" --sign "$CODE_SIGN_IDENTITY" --embed "$CERTIFICATE";

# Zip & Copy the dSYM file & remove the zip
echo "Zip and Copy the dSYM file"

cd "$WORKSPACE/build/$XCODE_CONFIG-iphoneos/"
tar -pczf "$PROJECT_NAME.tar.gz" "$DSYM_FILE"
cd "$WORKSPACE"
cp "$WORKSPACE/build/$XCODE_CONFIG-iphoneos/$PROJECT_NAME.tar.gz" "$OUTPUT/$PROJECT_NAME.tar.gz"
rm "$WORKSPACE/build/$XCODE_CONFIG-iphoneos/$PROJECT_NAME.tar.gz"

# Copy the icon files
echo "Copy the icon files"

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
	               <string>$PROJECT_NAME</string>
	           </dict>
	       </dict>
	   </array>
	</dict>
	</plist>
	EOF
	
LCASE_IPA_NAME=`lowerCase "$IPA_NAME"`
LCASE_OTA_NAME=`lowerCase "$OTA_NAME"`