#
# Copyright (C) 2014 BurnTide
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#!/bin/sh

# Create the ipa file
echo "Create the IPA file"

if [ "$APP_NAME" != "" ] 
then
	OTA_NAME="$APP_NAME-$XCODE_CONFIG-manifest.plist"
	IPA_NAME="$APP_NAME-$XCODE_CONFIG.ipa"
	DSYM_NAME="$APP_NAME-$XCODE_CONFIG.tar.gz"
else
	OTA_NAME="$PROJECT_NAME-$XCODE_CONFIG-manifest.plist"
	IPA_NAME="$PROJECT_NAME-$XCODE_CONFIG.ipa"
	DSYM_NAME="$PROJECT_NAME-$XCODE_CONFIG.tar.gz"
fi
OTA_URL="$(eval echo \$`echo OTAUrl$XCODE_CONFIG`)"
APP_FILE=`find "$WORKSPACE/build/$XCODE_CONFIG-iphoneos" -name "*.app"`
DSYM_FILE=`find "$WORKSPACE/build/$XCODE_CONFIG-iphoneos" -name "*.app.dSYM"`
$XCRUN -sdk $SDK PackageApplication -v "$APP_FILE" -o "$OUTPUT/$IPA_NAME" --sign "$CODE_SIGN_IDENTITY" --embed "$CERTIFICATE" | xcpretty -c;

# Zip & Copy the dSYM file & remove the zip
echo "Zip and Copy the dSYM file"

cd "$WORKSPACE/build/$XCODE_CONFIG-iphoneos/"
tar -pczf "$DSYM_NAME" "$DSYM_FILE"
cd "$WORKSPACE"
cp "$WORKSPACE/build/$XCODE_CONFIG-iphoneos/$DSYM_NAME" "$OUTPUT/$DSYM_NAME"
rm "$WORKSPACE/build/$XCODE_CONFIG-iphoneos/$DSYM_NAME"

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
LCASE_DSYM_NAME=`lowerCase "$DSYM_NAME"`
LCASE_OTA_NAME=`lowerCase "$OTA_NAME"`
