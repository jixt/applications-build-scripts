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