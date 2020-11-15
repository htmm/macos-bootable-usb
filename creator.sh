#!/usr/bin/env bash

# Created By Hein Thant (heinthanth)
# Modified version of macos-guest-virtualbox.sh

set -e

# GLOBAL variables
MACOS_VERSION="catalina" # supported: "highsierra", "mojave", "catalina". "bigsur" coming soon!
TARGET_DISK=""           # warning ... the whole disk will be formatted.

# utils
red="\e[31m"
orange="\e[33m"
green="\e[32m"
reset="\e[0m"

# dynamic variables
OUTPUT_DIR="${MACOS_VERSION}-installer"
CATALOG_URL=""
VERSION_STRING=""
HTTP_CLIENT="aria2c" # recommended
VERBOSE_MODE=true

CURL_OPTION="-L"
ARIA2_OPTION="-x 5"
DISKUTIL_OPTION=""

if [[ $1 == "--quiet" ]]; then
    VERBOSE_MODE=false
    CURL_OPTION="-L -s"
    ARIA2_OPTION="--quiet=true -x 5"
    DISKUTIL_OPTION="quiet"
fi

disksize=$(diskutil info $TARGET_DISK | grep "Disk Size" | awk '{ print $3 }')

if [ $MACOS_VERSION == "catalina" ] && (($(echo "$disksize < 10" | bc -l))); then
    printf "[*] ${red}macOS Catalina required installation with 10GB or above.${reset}\n"
fi

printf "[*] Checking for ${orange}coreutils${reset} ...\n"
if ! command -v gcsplit &>/dev/null; then
    printf "[*] ${red}coreutils not installed${reset}. checking whether package manager exists ...\n"
    if command -v "port" &>/dev/null; then
        printf "[*] Found MacPorts. Using MacPorts to install coreutils\n"
        sudo port install coreutils
    elif command -v "brew" &>/dev/null; then
        printf "[*] Found HomeBrew. Using HomeBrew to install coreutils\n"
        brew install coreutils
    else
        printf "[*] ${red}There's no package manager I know!${reset} Please install a package manager!\n"
        printf "[*] ${orange}https://macports.org${reset} or ${orange}https://brew.sh${reset}\n"
        exit 0
    fi
fi

printf "[*] Checking for ${orange}aria2c${reset} ...\n"
if ! command -v $HTTP_CLIENT &>/dev/null; then
    printf "[*] ${red}aria2 not installed${reset}. checking whether package manager exists ...\n"
    if command -v "port" &>/dev/null; then
        printf "[*] Found MacPorts. Using MacPorts to install aria2\n"
        sudo port install aria2
    elif command -v "brew" &>/dev/null; then
        printf "[*] Found HomeBrew. Using HomeBrew to install aria2\n"
        brew install aria2
    else
        printf "[*] ${red}There's no package manager I know!${reset} Using ${orange}curl${reset} as HTTP client\n"
        HTTP_CLIENT="curl"
    fi
fi

if [[ $MACOS_VERSION == "catalina" ]]; then
    VERSION_STRING="10.15"
    CATALOG_URL="https://swscan.apple.com/content/catalogs/others/index-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
elif [[ $MACOS_VERSION == "mojave" ]]; then
    VERSION_STRING="10.14"
    CATALOG_URL="https://swscan.apple.com/content/catalogs/others/index-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
elif [[ $MACOS_VERSION == "highsierra" ]]; then
    VERSION_STRING="10.13"
    CATALOG_URL="https://swscan.apple.com/content/catalogs/others/index-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
fi

printf "[*] Downloading Catalog ... "
if [[ $VERBOSE_MODE == true ]]; then
    printf "\n"
fi
curl $CURL_OPTION -o 'sucatalog.plist' -C - "$CATALOG_URL"

if ! test -f "sucatalog.plist"; then
    printf "[*] \n${red}Something went wrong while downloading plist"
else
    if [[ $VERBOSE_MODE == false ]]; then
        printf "${green}done${reset}\n"
    fi
fi

printf "[*] Finding macOS InstallAssistant download URL ... "
if [[ $VERBOSE_MODE == true ]]; then
    printf "\n"
fi
# TODO: apple csplit, expr not working, depends on GNU coreutils
tail -r "sucatalog.plist" | gcsplit - '/InstallAssistantAuto.smd/+1' '{*}' -f "_sucatalog_" -s
for catalog in _sucatalog_* "error"; do
    if [[ "${catalog}" == error ]]; then
        rm -rf _sucatalog*
        if [[ $VERBOSE_MODE == false ]]; then
            printf "${red}error${reset}\n"
        fi
        printf "[*] ${red}Something went wrong. Couldn't find URL${reset}"
        exit 1
    fi
    baseURL="$(tail -n 1 "${catalog}" 2>/dev/null)"
    baseURL="$(gexpr match "${baseURL}" '.*\(http://[^<]*/\)')"
    curl $CURL_OPTION "${baseURL}InstallAssistantAuto.smd" -o "${catalog}_InstallAssistantAuto.smd"
    if [[ "$(cat "${catalog}_InstallAssistantAuto.smd")" =~ Beta ]]; then
        continue
    fi
    found_version="$(head -n 6 "${catalog}_InstallAssistantAuto.smd" | tail -n 1)"
    if [[ "${found_version}" == *${VERSION_STRING}* ]]; then
        if [[ $VERBOSE_MODE == false ]]; then
            printf "${green}done${reset}\n"
        fi
        printf "[*] Found download URL: ${orange}${baseURL}${reset}\n"
        rm _sucatalog*
        break
    fi
    baseURL=""
done
if [[ $baseURL == "" ]]; then
    rm _sucatalog*
    if [[ $VERBOSE_MODE == false ]]; then
        printf "${red}error${reset}\n"
    fi
    printf "[*] ${red}Couldn't find URL${reset}"
    exit 0
fi

printf "[*] Downloading macOS installation files ... "
if [[ $VERBOSE_MODE == true ]]; then
    printf "\n"
fi
for filename in "BaseSystem.chunklist" "InstallInfo.plist" "AppleDiagnostics.dmg" "AppleDiagnostics.chunklist" "BaseSystem.dmg" "InstallESDDmg.pkg"; do
    if [[ $HTTP_CLIENT == "aria2c" ]]; then
        if test -f "${OUTPUT_DIR}/${filename}"; then
            aria2c $ARIA2_OPTION --dir $OUTPUT_DIR --continue=true "${baseURL}${filename}"
        else
            aria2c $ARIA2_OPTION --dir $OUTPUT_DIR "${baseURL}${filename}"
        fi
    else
        curl $CURL_OPTION -o "${OUTPUT_DIR}/${filename}" -C - "${baseURL}${filename}"
    fi
done
if [[ $VERBOSE_MODE == false ]]; then
    printf "${green}done${reset}\n"
fi

printf "[*] Formatting ... "
if [[ $VERBOSE_MODE == true ]]; then
    printf "\n"
fi
diskutil $DISKUTIL_OPTION eraseDisk JHFS+ ${MACOS_VERSION}-installer $TARGET_DISK
if [[ $VERBOSE_MODE == false ]]; then
    printf "${green}done${reset}\n"
fi

printf "[*] asking sudo passwords ... \n"
sudo -v

printf "[*] Restoring Base Image ... "
if [[ $VERBOSE_MODE == true ]]; then
    printf "\n"
    sudo asr restore --source "${OUTPUT_DIR}/BaseSystem.dmg" --target "/Volumes/${MACOS_VERSION}-installer" --noprompt --erase
else
    sudo asr restore --source "${OUTPUT_DIR}/BaseSystem.dmg" --target "/Volumes/${MACOS_VERSION}-installer" --noprompt --erase >/dev/null
    printf "${green}done${reset}\n"
fi

installer_path="$(ls -d '/Volumes/'*'Base System/Install'*'.app')"
installer_path="${installer_path}/Contents/SharedSupport/"
mkdir -p "${installer_path}"
printf "[*] Copying Installation Packages ... "
if [[ $VERBOSE_MODE == true ]]; then
    printf "\n"
fi
for filename in "BaseSystem.chunklist" "InstallInfo.plist" "AppleDiagnostics.dmg" "AppleDiagnostics.chunklist" "BaseSystem.dmg" "InstallESDDmg.pkg"; do
    if [[ $VERBOSE_MODE == true ]]; then
        /bin/cp -v "${OUTPUT_DIR}/${filename}" "${installer_path}"
    else
        /bin/cp "${OUTPUT_DIR}/${filename}" "${installer_path}"
    fi
done
if [[ $VERBOSE_MODE == false ]]; then
    printf "${green}done${reset}\n"
fi

printf "[*] Preparing Installation Packages ... "
mv "${installer_path}/InstallESDDmg.pkg" "${installer_path}/InstallESD.dmg"
sed -i.bak -e "s/InstallESDDmg\.pkg/InstallESD.dmg/" -e "s/pkg\.InstallESDDmg/dmg.InstallESD/" "${installer_path}InstallInfo.plist"
sed -i.bak2 -e "/InstallESD\.dmg/{n;N;N;N;d;}" "${installer_path}InstallInfo.plist"
rm "${installer_path}InstallInfo.plist.bak"*
printf "${green}done${reset}\n"

printf "[*] Installation Media ${green}Ok!${reset} Just go reboot now!\n"
