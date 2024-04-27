#!/bin/bash

set -e

# MacOS bootable USB creator
# thanks to https://github.com/myspaghetti/macos-virtualbox/ for some commands I didn't know.
# Bash 3 sucks! macOS uses out-dated bash version 3.
# but I tried to implement using pure Bash 3 without GNU coreutils.
# - heinthanth ( Hein Thant Maung Maung )

CATALOG_URL="https://swscan.apple.com/content/catalogs/others/index-14seed-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"

printf "\n\e[33mDownload Install macOS [v1.0.1]\e[0m\n\n"

printf '\e[8;40;82t'

# Download Install macOS
# RELEASE AND BETA_Sonoma

# DOWNLOADING CATALOG
CATALOG="/Private/tmp/sucatalog.plist"
printf "[*] Downloading sucatalog.plist ...\n"
curl -L --progress-bar -o "$CATALOG" $CATALOG_URL
printf "\n"
#END OF DOWNLOADING CATALOG

#FINDING BASE URL - I DON'T KNOW HOW TO PARSE PLIST IN BASH
PARSER_PY_CODE=$(
    cat <<EOF
import plistlib
from urllib.request import urlretrieve
from os import path, remove
from sys import version_info

catalog = None
with open("$CATALOG", "rb") as plistFile:
    catalog = plistlib.load(plistFile)

macos_installer = []

if 'Products' in catalog:
    for k in catalog['Products'].keys():
        product = catalog['Products'][k]
        try:
            if product['ExtendedMetaInfo']['InstallAssistantPackageIdentifiers']:
                macos_installer.append(k)
        except KeyError:
            continue

macos_installer.reverse()
for product_id in macos_installer:
    distributionURL = catalog['Products'][product_id]['Distributions']['English']
    urlretrieve(distributionURL, "distribution.plist")
    with open("./distribution.plist", "rb") as plistFile:
        distribution = plistlib.load(plistFile)
        print("{version},{build},{baseURL}".format(build=distribution["BUILD"],
                                                   version=distribution["VERSION"], baseURL=path.dirname(distributionURL)))
    remove("./distribution.plist")
EOF
)
printf "[*] Searching available versions ... "
parsed_version="$(echo "$PARSER_PY_CODE" | /usr/bin/python3 -)"

supported_version=($(echo "$parsed_version" | while read -r line; do echo $line | awk -F, '{printf "%s:%s\n",  $1, $2}'; done | sort --version-sort -r))
# END OF FINDING BASE URL

# VERSION SELECTION
SELECTED_VERSION=""
SELECTED_BUILD=""

printf "\n\n"

if [ ${#supported_version[@]} -eq 0 ]; then
    printf "[*] \e[31mOops! No version available!\n\n"
    exit 0
fi

while :; do
    count=${#supported_version[@]}
    for ((i = 0; i < $count; i++)); do
        printf "[$(printf '%01d' $(($i + 1)))]\t$(echo ${supported_version[$i]} | awk -F: '{printf "'$'\e[33m''%s'$'\e[0m''\t    %s", $1, $2}')\n"
    done
    printf "\n\e[33mmacOS version for installation media [1 ~ ${count}]:\e[0m "
    read res
    if ! [[ "$res" =~ ^[0-9]+$ ]]; then
        printf "\n\e[31mInvalid Input\e[0m\n\n"
    else
        if [[ "$res" -lt 1 || "$res" -gt $count ]]; then
            printf "\n\e[31mInvalid Input\e[0m\n\n"
        else
            SELECTED_VERSION=${supported_version[$(($res - 1))]}
            break
        fi
    fi
done
# END OF VERSION SELECTION

# PRE DEFINING VARIABLES
SELECTED_BUILD=$(echo $SELECTED_VERSION | cut -d: -f2)
SELECTED_BUILD_INFO=$(printf "%s\n" $parsed_version | grep $SELECTED_BUILD)

MAJOR_VERSION=$(echo $SELECTED_BUILD_INFO | cut -d, -f1 | cut -d. -f1,2)
BASE_URL=$(echo $SELECTED_BUILD_INFO | cut -d, -f3)
MACOS_VERSION=""

if [[ "$MAJOR_VERSION" == "14."* ]]; then
    MACOS_VERSION="Sonoma"
elif [[ "$MAJOR_VERSION" == "13."* ]]; then
    MACOS_VERSION="Ventura"
elif [[ "$MAJOR_VERSION" == "12."* ]]; then
    MACOS_VERSION="Monterey"
elif [[ "$MAJOR_VERSION" == "11."* ]]; then
    MACOS_VERSION="BigSur"
elif [[ "$MAJOR_VERSION" == "10.15"* ]]; then
    MACOS_VERSION="Catalina"
elif [[ "$MAJOR_VERSION" == "10.14"* ]]; then
    MACOS_VERSION="Mojave"
elif [[ "$MAJOR_VERSION" == "10.13"* ]]; then
    MACOS_VERSION="HighSierra"
fi
# END OF PRE_DEFINING_VARIABLES

# DOWNLOADING_INSTALLATION_FILES
INSTALLATION_FILES=()
if [[ $MACOS_VERSION == "Sonoma" ]] || [[ "$MACOS_VERSION" == "Ventura" ]] || [[ "$MACOS_VERSION" == "Monterey" ]] || [[ "$MACOS_VERSION" == "BigSur" ]]; then
    INSTALLATION_FILES=("InstallAssistant.pkg")
else
    INSTALLATION_FILES=("BaseSystem.chunklist" "InstallInfo.plist" "AppleDiagnostics.dmg" "AppleDiagnostics.chunklist" "BaseSystem.dmg" "InstallESDDmg.pkg")
fi

#BASE_URL="http://localhost:8000"

OUTPUT_DIR="/Private/tmp/Install_macOS/${MACOS_VERSION}"
Sleep 1
mkdir -p $OUTPUT_DIR
printf "\n"
for filename in ${INSTALLATION_FILES[@]}; do
    printf "[*] Downloading ${filename}\n"
    curl -L --progress-bar -o "${OUTPUT_DIR}/${filename}" -C - "${BASE_URL}/${filename}"
    if [[ $? -ne 0 ]]; then
        printf "[*] \e[31mDownload Failed. PLEASE TRY AGAIN!\e[0m\n\n"
        exit 1
    fi
done
# END OF DOWNLOADING_INSTALLATION_FILES
# CREATING_INSTALLER_FILE_10.13_10.14_10.15
 BASE_DMG="/Private/tmp/BASE"
 #-------------------------
 if [[ $MACOS_VERSION == "Catalina" ]] || [[ "$MACOS_VERSION" == "Mojave" ]] || [[ "$MACOS_VERSION" == "HighSierra" ]]; then
 Sleep 2
 echo " "
 # ATTACH_IMAGE_FILE
 hdiutil attach -noverify -nobrowse -mountpoint $BASE_DMG "${OUTPUT_DIR}/BaseSystem.dmg"
 echo " "
 InstallMac(){
     for file in "$BASE_DMG"/*; do
       if [[ $file == *.app ]]; then
             let index=${#name_array[@]}
           name_array[$index]="${file##*/}"
         fi
     done
     echo ${name_array[0]}
 }
 BASE_APP=$(InstallMac)
 # EXTRACTING_APPNAME_10.13_10.14_10.15
 cp -Rp "$BASE_DMG/$BASE_APP" "${OUTPUT_DIR}/"
 Sleep 2
 printf "\n\e[31mBuilding $BASE_APP Wait . . .\e[0m"
 OUT_DIR="${OUTPUT_DIR}/$BASE_APP/Contents/SharedSupport"
 if [ ! -d "$OUT_DIR" ]; then 
    mkdir "$OUT_DIR"; 
 fi
 Sleep 2
 # BUILDING APP
 # RENAME PKG TO DMG
 mv "${OUTPUT_DIR}/InstallESDDmg.pkg" "${OUTPUT_DIR}/InstallESD.dmg"
 # USE SED TO ADJUST THE PLIST FILE
 sed -e "s/InstallESDDmg\.pkg/InstallESD.dmg/" -e "s/pkg\.InstallESDDmg/dmg.InstallESD/" -e "/InstallESD\.dmg/{n;N;N;N;d;}" "${OUTPUT_DIR}/InstallInfo.plist" > "${OUTPUT_DIR}/Install_Info.plist"
 echo " "
 # COPYING SOURCE_FILES
 cp -Rp "${OUTPUT_DIR}/BaseSystem.dmg" "$OUT_DIR"
 cp -Rp "${OUTPUT_DIR}/BaseSystem.chunklist" "$OUT_DIR"
 cp -Rp "${OUTPUT_DIR}/Install_Info.plist" "$OUT_DIR/InstallInfo.plist"
 cp -Rp "${OUTPUT_DIR}/InstallESD.dmg" "$OUT_DIR"
 cp -Rp "${OUTPUT_DIR}/AppleDiagnostics.dmg" "$OUT_DIR"
 cp -Rp "${OUTPUT_DIR}/AppleDiagnostics.chunklist" "$OUT_DIR"
 Sleep 3
 # DETTACH_IMAGE_FILE
 hdiutil detach -Force $BASE_DMG
 echo " "
 printf "\n\e[33mBuilding $BASE_AP Done!\e[0m"
 # REMOVE SOURCE__FILES
 rm -rf "${OUTPUT_DIR}/BaseSystem.dmg"
 rm -rf "${OUTPUT_DIR}/BaseSystem.chunklist"
 rm -rf "${OUTPUT_DIR}/InstallInfo.plist"
 rm -rf "${OUTPUT_DIR}/Install_Info.plist"
 rm -rf "${OUTPUT_DIR}/InstallESD.dmg"
 rm -rf "${OUTPUT_DIR}/AppleDiagnostics.dmg"
 rm -rf "${OUTPUT_DIR}/AppleDiagnostics.chunklist"
 fi
 Sleep 1
  Imagepath=`/usr/bin/osascript << SourceFolder
  set SourceFolder to "/Private/tmp/Install_macOS/"  set DestinationFolder to POSIX path of (choose folder with prompt "Please select the location to save it:")  set DestinationFolder to DestinationFolder & "Install macOS " & ((current date) as text)  do shell script "mv " & quoted form of SourceFolder & space & quoted form of DestinationFolder
      SourceFolder`

  # Cancel is user selects Cancel
  if [ ! "$Imagepath" ] ; then
    osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "User cancelled"'
    exit 0
  fi

 echo " "
 printf "\n\e[33mBackUp --> for macOS $MACOS_VERSION Done!\e[0m"
 # REMOVE CATALOG
 rm -rf "$CATALOG"
 # END OF CREATING_INSTALLER_FILE
