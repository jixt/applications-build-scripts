#
# Copyright (C) 2014 BurnTide
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#!/bin/sh


# Pre-configuration
source ./build_preconfig.sh

# Now build the application
echo "Build the application"

$XCODEBUILD -configuration "$XCODE_CONFIG" -sdk $SDK clean | xcpretty -c && exit ${PIPESTATUS[0]};
if [ "$APP_NAME" != "" ] 
then
	$XCODEBUILD -workspace "$WORKSPACE_NAME".xcworkspace -scheme "$SCHEME_NAME" -configuration "$XCODE_CONFIG" -sdk $SDK APP_NAME=$APP_NAME BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build | xcpretty -c;
else
	$XCODEBUILD -workspace "$WORKSPACE_NAME".xcworkspace -scheme "$SCHEME_NAME" -configuration "$XCODE_CONFIG" -sdk $SDK BUNDLE_ID=$BUNDLE_IDENTIFIER build PROVISIONING_PROFILE="$PROVISIONING" CODE_SIGN_IDENTITY="iPhone Distribution: $CODE_SIGN_IDENTITY" CONFIGURATION_BUILD_DIR="$WORKSPACE/build/$XCODE_CONFIG-iphoneos" || failed build | xcpretty -c && exit ${PIPESTATUS[0]};
fi

#Create IPA
source ./build_create_ipa.sh