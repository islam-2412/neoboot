#!/bin/sh
#
# NeoBoot Direct IPK Installer
# Place installer.sh and neoboot.ipk together in the GitHub fury folder.
# Run:
# wget -q --no-check-certificate -O - https://raw.githubusercontent.com/islam-2412/neoboot/main/fury/installer.sh | /bin/sh
#

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# One fixed file: no CPU architecture or Python detection.
REPO_BASE_URL='https://raw.githubusercontent.com/islam-2412/neoboot/main/fury'
FILE_NAME='neoboot.ipk'
DOWNLOAD_URL="${REPO_BASE_URL}/${FILE_NAME}"
PACKAGE_PATH="/tmp/${FILE_NAME}"
INSTALL_LOG='/tmp/neoboot_install.log'

print_info()    { printf '%b\n' "${BLUE}[ INFO ]${NC} $1"; }
print_success() { printf '%b\n' "${GREEN}[ SUCCESS ]${NC} $1"; }
print_error()   { printf '%b\n' "${RED}[ ERROR ]${NC} $1"; }
print_divider() { printf '%b\n' "${CYAN}========================================================================${NC}"; }

download_file() {
    URL="$1"
    OUT_FILE="$2"
    rm -f "$OUT_FILE"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL -k "$URL" -o "$OUT_FILE" && [ -s "$OUT_FILE" ]; then
            return 0
        fi
        rm -f "$OUT_FILE"
    fi

    if command -v wget >/dev/null 2>&1; then
        if wget -q --no-check-certificate -O "$OUT_FILE" "$URL" && [ -s "$OUT_FILE" ]; then
            return 0
        fi
        rm -f "$OUT_FILE"
    fi

    return 1
}

clear 2>/dev/null || true
print_divider
printf '%b\n' "${GREEN}                       Installing NeoBoot Plugin${NC}"
printf '%b\n' "${YELLOW}                          Created by Islam Salama${NC}"
print_divider
printf '\n'

# IPK packages use opkg. No check of Python version or CPU type.
if ! command -v opkg >/dev/null 2>&1; then
    print_error 'opkg is not available. This image cannot install IPK packages with this installer.'
    exit 1
fi

print_info "Downloading ${FILE_NAME} ..."
if ! download_file "$DOWNLOAD_URL" "$PACKAGE_PATH"; then
    print_error "Download failed: ${DOWNLOAD_URL}"
    print_error 'The currently installed NeoBoot has not been changed.'
    exit 1
fi

if [ "$(wc -c < "$PACKAGE_PATH")" -lt 1000 ]; then
    print_error "Downloaded file is too small to be a valid IPK: ${FILE_NAME}"
    rm -f "$PACKAGE_PATH"
    print_error 'The currently installed NeoBoot has not been changed.'
    exit 1
fi

print_success "Downloaded ${FILE_NAME}."
print_info 'Installing NeoBoot directly ...'

# Do not uninstall or delete existing plugin files before the new package is installed.
opkg install --force-reinstall --force-overwrite "$PACKAGE_PATH" > "$INSTALL_LOG" 2>&1
INSTALL_RESULT=$?

if [ "$INSTALL_RESULT" -ne 0 ]; then
    print_error "NeoBoot installation failed (exit code ${INSTALL_RESULT})."
    cat "$INSTALL_LOG"
    rm -f "$PACKAGE_PATH"
    print_error "Log saved: ${INSTALL_LOG}"
    exit 1
fi

rm -f "$PACKAGE_PATH" "$INSTALL_LOG"
print_success 'NeoBoot installed successfully.'
print_success 'Temporary files cleaned.'
printf '\n'
print_divider
printf '%b\n' "${GREEN}                     NeoBoot Installed Successfully!${NC}"
printf '%b\n' "${CYAN}                       Restarting Enigma2 GUI...${NC}"
print_divider
sleep 3
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart enigma2 || killall -9 enigma2
else
    killall -9 enigma2
fi
exit 0
