#!/usr/bin/env bash

# Created By Hein Thant (heinthanth)

set -e

# GLOBAL variables
MACOS_VERSION="catalina" # supported: "highsierra", "mojave", "catalina". "bigsur" coming soon!

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
curl -L -s -o 'sucatalog.plist' -C - "$CATALOG_URL"

if ! test -f "sucatalog.plist"; then
    printf "[*] ${red}Something went wrong while downloading plist"
else
    printf "${green}done${reset}\n"
fi

printf "[*] Finding macOS InstallAssistant download URL ... "
# TODO: apple csplit, expr not working, depends on GNU coreutils
tail -r "sucatalog.plist" | gcsplit - '/InstallAssistantAuto.smd/+1' '{*}' -f "_sucatalog_" -s
for catalog in _sucatalog_* "error"; do
    if [[ "${catalog}" == error ]]; then
        rm -rf _sucatalog*
        printf "${red}error${reset}\n"
        printf "[*] ${red}Something went wrong. Couldn't find URL${reset}"
        exit 1
    fi
    baseURL="$(tail -n 1 "${catalog}" 2>/dev/null)"
    baseURL="$(gexpr match "${baseURL}" '.*\(http://[^<]*/\)')"
    curl -s -L "${baseURL}InstallAssistantAuto.smd" -o "${catalog}_InstallAssistantAuto.smd"
    if [[ "$(cat "${catalog}_InstallAssistantAuto.smd")" =~ Beta ]]; then
        continue
    fi
    found_version="$(head -n 6 "${catalog}_InstallAssistantAuto.smd" | tail -n 1)"
    if [[ "${found_version}" == *${VERSION_STRING}* ]]; then
        printf "${green}done${reset}\n"
        printf "[*] Found download URL: ${orange}${baseURL}${reset}\n"
        rm _sucatalog*
        break
    fi
    baseURL=""
done
if [[ $baseURL == "" ]]; then
    rm _sucatalog*
    printf "${red}error${reset}\n"
    printf "[*] ${red}Couldn't find URL${reset}"
    exit 0
fi

printf "[*] Downloading macOS installation files ... "
# TODO: remove line 92 after development
baseURL="http://localhost:8000/"
for filename in "BaseSystem.chunklist" "InstallInfo.plist" "AppleDiagnostics.dmg" "AppleDiagnostics.chunklist" "BaseSystem.dmg" "InstallESDDmg.pkg"; do
    if test -f "${OUTPUT_DIR}/${filename}"; then
        aria2c --quiet=true --dir $OUTPUT_DIR --continue=true -x 5 "${baseURL}${filename}"
    else
        aria2c --quiet=true --dir $OUTPUT_DIR -x 5 "${baseURL}${filename}"
    fi
done
printf "${green}done${reset}\n"
