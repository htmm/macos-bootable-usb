#!/bin/bash

# MacOS bootable USB creator
# thanks to https://github.com/myspaghetti/macos-virtualbox/ for some commands I didn't know.
# Bash 3 sucks! macOS uses out-dated bash version 3.
# but I tried to implement using pure Bash 3 without GNU coreutils.
# - heinthanth ( Hein Thant Maung Maung )

CATALOG_URL="https://swscan.apple.com/content/catalogs/others/index-11-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"

printf "\n\e[33mMacOS Bootable USB creator\e[0m\n"

# DOWNLOADING CATALOG
printf "\n[*] Downloading sucatalog.plist ...\n"
curl -L --progress-bar -o "sucatalog.plist" $CATALOG_URL
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
with open("./sucatalog.plist", "rb") as plistFile:
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
while :; do
    count=${#supported_version[@]}
    for ((i = 0; i < $count; i++)); do
        printf "[$(printf '%02d' $(($i + 1)))]\t$(echo ${supported_version[$i]} | awk -F: '{printf "'$'\e[33m''%s'$'\e[0m''\t    %s", $1, $2}')\n"
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

if [[ "$MAJOR_VERSION" == "11."* ]]; then
    MACOS_VERSION="bigsur"
elif [[ "$MAJOR_VERSION" == "10.15"* ]]; then
    MACOS_VERSION="catalina"
elif [[ "$MAJOR_VERSION" == "10.14"* ]]; then
    MACOS_VERSION="mojave"
elif [[ "$MAJOR_VERSION" == "10.13"* ]]; then
    MACOS_VERSION="highsierra"
fi
# END OF PRE DEFINING VARIABLES

# DOWNLOADING INSTALLATION FILES
INSTALLATION_FILES=()
if [[ $MACOS_VERSION == "bigsur" ]]; then
    INSTALLATION_FILES=("InstallAssistant.pkg")
else
    INSTALLATION_FILES=("BaseSystem.chunklist" "InstallInfo.plist" "AppleDiagnostics.dmg" "AppleDiagnostics.chunklist" "BaseSystem.dmg" "InstallESDDmg.pkg")
fi

# TODO: REMOVE AFTER DEVELOPMENT
BASE_URL="http://localhost:8000"

OUTPUT_DIR="${MACOS_VERSION}-files"
mkdir -p $OUTPUT_DIR
printf "\n"
for filename in ${INSTALLATION_FILES[@]}; do
    printf "[*] Downloading ${filename}\n"
    curl -L --progress-bar -o "${OUTPUT_DIR}/${filename}" -C - "${BASE_URL}/${filename}"
done
# END OF DOWNLOADING INSTALLATION FILES

# DISK SELECTION
TARGET_DISK=""

external_disk=($(diskutil list external physical | grep -o '\(disk[0-9]*\)' | sort | uniq))
printf "\n"

if [ ${#external_disk[@]} -eq 0 ]; then
    printf "[*] \e[31mOops! no disk found!\n\n"
    exit 0
fi

deviceName=()
deviceSize=()

count=${#external_disk[@]}
for ((i = 0; i < $count; i++)); do
    current=${external_disk[$i]}
    deviceName+=("${current}:$(diskutil info /dev/$current | grep 'Device / Media Name:' | awk '{$1=$2=$3=$4=""; print $0}' | xargs)")
    deviceSize+=("${current}:$(diskutil info /dev/$current | grep 'Disk Size:' | awk '{print $3}')")
done

while :; do
    count=${#external_disk[@]}
    for ((i = 0; i < $count; i++)); do
        current=${external_disk[$i]}
        size=$(printf -- '%s\n' "${deviceSize[@]}" | grep $current | cut -d ':' -f 2)
        name=$(printf -- '%s\n' "${deviceName[@]}" | grep $current | cut -d ':' -f 2)
        printf "$(($i + 1))) /dev/${current} : $size GB\t[ $name ]\n"
    done
    printf "\n\e[33mDisk for installation media:\e[0m "
    read res

    if ! [[ "$res" =~ ^[0-9]+$ ]]; then
        printf "\n\e[31mInvalid Input\e[0m\n\n"
    else
        if [[ "$res" -lt 1 || "$res" -gt $count ]]; then
            printf "\n\e[31mInvalid Input\e[0m\n\n"
        else
            TARGET_DISK=${external_disk[$(($res - 1))]}
            break
        fi
    fi
done
# END OF DISK SELECTION

# PRE CHECKING
TARGET_SIZE=$(printf -- '%s\n' "${deviceSize[@]}" | grep $TARGET_DISK | cut -d ':' -f 2)
if [ $MACOS_VERSION == "bigsur" ] && (($(echo "${TARGET_SIZE} < 14" | bc -l))); then
    printf "\n[*] \e[31mmacOS Big Sur required installation with 14GB or above.\e[0m\n\n"
    exit 1
elif [ $MACOS_VERSION == "catalina" ] && (($(echo "${TARGET_SIZE} < 10" | bc -l))); then
    printf "\n[*] \e[31mmacOS Catalina required installation with 10GB or above.\e[0m\n\n"
    exit 1
fi
# END OF PRE CHECKING

# FORMAT DISK
# format disk as MacOS Extended (Journaled)
printf "\n\e[31mWARNING\e[0m the whole selected disk will be formatted and will cause to data loss.\n\n"
read -r -p "ARE YOU SURE? [y/N] " response
case "$response" in
[yY][eE][sS] | [yY])
    printf "\n"
    diskutil eraseDisk JHFS+ ${MACOS_VERSION}-installer $TARGET_DISK
    printf "\n"
    ;;
*)
    printf "\n\e[31mUser cancelled. Exiting\e[0m\n\n"
    exit 1
    ;;
esac
# END OF FORMAT DISK

MACOS_VERSION="catalina"

if [[ $MACOS_VERSION == "bigsur" ]]; then
    printf "Big Sur stuffs."
else
    # RESTORE DISK IMAGE
    if ! sudo -n true 2>/dev/null; then
        printf "[*] asking for sudo passwords. "
        sudo -v
        printf "\n"
    fi
    sudo asr restore --source "${OUTPUT_DIR}/BaseSystem.dmg" --target "/Volumes/${MACOS_VERSION}-installer" --noprompt --erase
    printf "\n"

    installer_path="$(ls -d '/Volumes/'*'Base System/Install'*'.app')"
    installer_path="${installer_path}/Contents/SharedSupport/"
    mkdir -p "${installer_path}"

    for filename in ${INSTALLATION_FILES[@]}; do
        rsync --progress "${OUTPUT_DIR}/${filename}" "${installer_path}"
    done

    mv "${installer_path}/InstallESDDmg.pkg" "${installer_path}/InstallESD.dmg"
    sed -i.bak -e "s/InstallESDDmg\.pkg/InstallESD.dmg/" -e "s/pkg\.InstallESDDmg/dmg.InstallESD/" "${installer_path}InstallInfo.plist"
    sed -i.bak2 -e "/InstallESD\.dmg/{n;N;N;N;d;}" "${installer_path}InstallInfo.plist"
    rm "${installer_path}InstallInfo.plist.bak"*
fi

printf "\n[*] Installation Media \e[32mOk!\e[31m Just go reboot now!\n\n"
