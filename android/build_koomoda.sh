#
# Copyright (C) 2013 BurnTide
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
	echo "Usage: $0 -ac android_config -asdk android_sdk_path -akey android_keystore_path -t koomoda_account_token -a koomoda_app_token -ksa keystore_alias -ksp keystore_password"
	exit 2
}
function lowerCase() {
	echo "$1" | tr -d "[:space:]" | tr "[:upper:]" "[:lower:]"
}

# Build functions

function deleteAutoGenFoldersForFolder() {
	if [ -d "$1/bin" ]; then
		rm -rf "$1/bin"
	fi
	
	if [ -d "$1/gen" ]; then
		rm -rf "$1/gen"
	fi
}
function addBuildAndLocalPropertyFilesToProject() {
	
	if [ ! -d "$1" ]; then
		echo "No valid directory was given: $1"
		return
	fi
	
	#Create build.xml in the directory
	cat <<-EOF > $1/build.xml
	<?xml version="1.0" encoding="UTF-8"?>
	<project name="projectName">
	    <loadproperties srcFile="local.properties" />
	    <loadproperties srcFile="project.properties" />
		<fail
			message="sdk.dir is missing. Make sure to generate local.properties using 'android update project'"
			unless="sdk.dir" />

		<!-- version-tag: custom -->
	    <import file="\${sdk.dir}/tools/ant/build.xml" />
	</project>
	EOF
	
	#create local.properties
	cat <<-EOF > $1/local.properties
	sdk.dir=/Library/Android/Home
	EOF
}
function cleanProject() {
	
	# Check if there are project properties
	
	if [ ! -f "$1/project.properties" ]; then 
		return
	fi
	
	# Delete auto generated folders of project
	
	deleteAutoGenFoldersForFolder "$1"
	
	# Delete auto generated folders of libraries
	
	for lib in $(cat "$1/project.properties" | grep -o 'android.library.reference.[0-9]\+=.\+$' | sed 's/.*=//g')
	do
		deleteAutoGenFoldersForFolder "$1/$lib"
		# Recursive call to the libraries
		cleanProject "$1/$lib"
	done
}
function setProject() {
	
	# Check if there are project properties
	
	if [ ! -f "$1/project.properties" ]; then 
		return
	fi
	
	# Set build file for liberaries
	
	for lib in $(cat "$1/project.properties" | grep -o 'android.library.reference.[0-9]\+=.\+$' | sed 's/.*=//g')
	do
		addBuildAndLocalPropertyFilesToProject "$1/$lib"
		# Recursive call to the libraries
		setProject "$1/$lib"
	done
}
function setRevision() {
	REVISION=$2
	
	if [ ! -f "$1" ]; then
		return
	fi
	
	COUNT_VERSION=`grep -c "versionName" "$1"`
	
	if [ $COUNT_VERSION -eq 0 ]; then
		exit 2;
	else
		OLD_VERSION=":versionName=\"\([^\"]*\)\""
		NEW_VERSION=":versionName=\"\1 \($REVISION\)\""	
		sed "s/$OLD_VERSION/$NEW_VERSION/g" "$1" > "$1.temp"
		mv "$1.temp" "$1"
	fi
}

# Get the script parameters & check if all needed values are there.

while [ $# -gt 0 ]
do
    case "$1" in
		-t)	K_ACCOUNT_TOKEN=$2; shift;;
		-a)	K_APP_TOKEN=$2; shift;;
        -ksa) KEYSTORE_ALIAS=$2; shift;;
		-ksp) KEYSTORE_PASSWORD=$2; shift;;
		-ac) ANDROID_CONFIG=$2; shift;;
		-asdk) PATH_ANDROID_SDK=$2; shift;;
		-akey) PATH_KEYSTORE=$2; shift;;
		*)	usage;;
    esac
	shift
done

if [ "$K_APP_TOKEN" == "" -o "$XCODE_CONFIG" == "" -o "$KEYSTORE_ALIAS" == "" -o "$KEYSTORE_PASSWORD" == "" -o "$ANDROID_CONFIG" == "" ]
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
PATH_ANT="/usr/bin/ant"
BUILD_DATE=$(date +%d-%m-%Y) #the current builddate

# Create lowercase variables for client and project

LCASE_CLIENT_NAME=`lowerCase "$CLIENT_NAME"`
LCASE_PROJECT_NAME=`lowerCase "$PROJECT_NAME"`
FILE_NAME="$PROJECT_NAME-$ANDROID_CONFIG.apk"
LCASE_FILE_NAME=`lowerCase "$FILE_NAME"`


# Koomoda

KOOMODA_API_URL="https://www.koomoda.com/app/upload"

# Clean the project

cleanProject "$WORKSPACE"

# Set the project (build and local properties files)

setProject "$WORKSPACE"

# Set the build number

setRevision "$WORKSPACE/AndroidManifest.xml" $BUILD_NUMBER

# Create sepecific build.xml

cat <<-EOF > $TRUNK/build.xml
<?xml version="1.0" encoding="UTF-8"?>
<project name="$LCASE_PROJECT_NAME">
    <loadproperties srcFile="local.properties" />
    <loadproperties srcFile="project.properties" />
	<fail
		message="sdk.dir is missing. Make sure to generate local.properties using 'android update project'"
		unless="sdk.dir" />
	
	<!-- version-tag: custom -->
    <import file="\${sdk.dir}/tools/ant/build.xml" />
</project>
EOF

# Create local properties file
cat <<-EOF > $WORKSPACE/local.properties
sdk.dir=$PATH_ANDROID_SDK
key.store=$PATH_KEYSTORE
key.alias=$KEYSTORE_ALIAS
key.store.password=$KEYSTORE_PASSWORD
key.alias.password=$KEYSTORE_PASSWORD
out.dir=../output
EOF

# Build
$PATH_ANT $ANDROID_CONFIG -v -f $WORKSPACE/build.xml;

if [ -f "$OUTPUT/$LCASE_FILE_NAME" ]
then
	curl -3 $KOOMODA_API_URL -F file=@"${OUTPUT}/${LCASE_FILE_NAME}" -F user_token="${K_ACCOUNT_TOKEN}" -F app_token="${K_APP_TOKEN}" -F app_version="${BUILD_NUMBER}"
else
	#file doesn't exist
	exit 2
fi
