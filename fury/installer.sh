#!/bin/sh
#
# NeoBoot Smart Installer — AJPanel-friendly, left-aligned output.
# Created by Islam Salama
#
# Upload installer.sh and neoboot.ipk to:
# https://github.com/islam-2412/neoboot/tree/main/fury
#
# Install command:
# wget -q --no-check-certificate -O - https://raw.githubusercontent.com/islam-2412/neoboot/main/fury/installer.sh | /bin/sh
#

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;96m'  # Bright cyan: clearly readable on AJPanel / Telnet-7
CYAN='\033[1;36m'
NC='\033[0m'

REPO_BASE_URL='https://raw.githubusercontent.com/islam-2412/neoboot/main/fury'
FILE_NAME='neoboot.ipk'
DOWNLOAD_URL="${REPO_BASE_URL}/${FILE_NAME}"
PACKAGE_PATH="/tmp/${FILE_NAME}"
INSTALL_LOG='/tmp/neoboot_install.log'

print_info()    { printf '%b\n' "${BLUE}[ INFO ]${NC} $1"; }
print_success() { printf '%b\n' "${GREEN}[ OK ]${NC} $1"; }
print_error()   { printf '%b\n' "${RED}[ ERROR ]${NC} $1"; }
print_divider() { printf '%b\n' "${CYAN}----------------------------------------${NC}"; }

# Read a single line safely. Neither a Python nor an architecture check is
# required for the selection of the IPK.
read_first_line() {
    [ -r "$1" ] || return 0
    sed -n '1p' "$1" 2>/dev/null | tr -d '\000\r'
}

image_config_value() {
    [ -r /etc/image-version ] || return 0
    sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" /etc/image-version 2>/dev/null | head -n 1 | tr -d '\r'
}

# 1) Detect the receiver for display only. On many VU+ receivers,
#    /proc/stb/info/model is the generic value "dm8000" even on Duo 4K.
#    The actual VU+ model is reported by /proc/stb/info/vumodel.
DEVICE_MODEL=''
VU_MODEL=$(read_first_line /proc/stb/info/vumodel)
case "$VU_MODEL" in
    duo4k|vuduo4k|duo4kse|vuduo4kse|uno4k|vuuno4k|uno4kse|vuuno4kse|solo4k|vusolo4k|zero4k|vuzero4k|ultimo4k|vuultimo4k|duo2|vuduo2|solo2|vusolo2)
        DEVICE_MODEL="$VU_MODEL" ;;
esac

# Prefer the image's machine build ID over the generic /proc/stb/info/model.
if [ -z "$DEVICE_MODEL" ]; then
    for MODEL_KEY in machinebuild machine model boxtype; do
        DEVICE_MODEL=$(image_config_value "$MODEL_KEY")
        [ -n "$DEVICE_MODEL" ] && break
    done
fi

# Some VU+ images identify their hardware as the compatibility model "dm8000".
# If the hostname contains a known real receiver model (e.g. "vuduo4k"),
# use it instead. This is display-only; installation is never restricted.
case "$(printf '%s' "$DEVICE_MODEL" | tr '[:upper:]' '[:lower:]')" in
    ''|dm8000)
        for HOST_MODEL in "$(read_first_line /proc/sys/kernel/hostname)" \
                          "$(read_first_line /etc/hostname)" \
                          "$(uname -n 2>/dev/null)"; do
            case "$(printf '%s' "$HOST_MODEL" | tr '[:upper:]' '[:lower:]')" in
                vuduo4k|duo4k|vuduo4kse|duo4kse|vuuno4k|uno4k|vuuno4kse|uno4kse|\
                vusolo4k|solo4k|vuzero4k|zero4k|vuultimo4k|ultimo4k|\
                vuduo2|duo2|vusolo2|solo2|sf8008|octagonsf8008|\
                dmone|dreamone|dm900|dm920)
                    DEVICE_MODEL=$HOST_MODEL
                    break ;;
            esac
        done ;;
esac

if [ -z "$DEVICE_MODEL" ]; then
    for MODEL_FILE in /proc/stb/info/boxtype /proc/device-tree/model /proc/stb/info/model /etc/model; do
        DEVICE_MODEL=$(read_first_line "$MODEL_FILE")
        [ -n "$DEVICE_MODEL" ] && break
    done
fi
[ -n "$DEVICE_MODEL" ] || DEVICE_MODEL=$(uname -n 2>/dev/null)
[ -n "$DEVICE_MODEL" ] || DEVICE_MODEL='Unknown'

# Normalize common model IDs. No device is blocked based on its model.
case "$(printf '%s' "$DEVICE_MODEL" | tr '[:upper:]' '[:lower:]')" in
    duo4k|vuduo4k)         DEVICE_MODEL='VU+ Duo 4K' ;;
    duo4kse|vuduo4kse)     DEVICE_MODEL='VU+ Duo 4K SE' ;;
    uno4k|vuuno4k)         DEVICE_MODEL='VU+ Uno 4K' ;;
    uno4kse|vuuno4kse)     DEVICE_MODEL='VU+ Uno 4K SE' ;;
    solo4k|vusolo4k)       DEVICE_MODEL='VU+ Solo 4K' ;;
    zero4k|vuzero4k)       DEVICE_MODEL='VU+ Zero 4K' ;;
    ultimo4k|vuultimo4k)   DEVICE_MODEL='VU+ Ultimo 4K' ;;
    duo2|vuduo2)           DEVICE_MODEL='VU+ Duo2' ;;
    solo2|vusolo2)         DEVICE_MODEL='VU+ Solo2' ;;
    sf8008|octagonsf8008)  DEVICE_MODEL='Octagon SF8008' ;;
    dmone|dreamone|one)    DEVICE_MODEL='Dreambox One' ;;
    dm900)                  DEVICE_MODEL='Dreambox DM900' ;;
    dm920)                  DEVICE_MODEL='Dreambox DM920' ;;
    dm8000)                 DEVICE_MODEL='Dreambox DM8000' ;;
esac

# 2) Identify image name/version for display only.
IMAGE_NAME=$(image_config_value distro)
[ -n "$IMAGE_NAME" ] || IMAGE_NAME=$(image_config_value creator)
[ -n "$IMAGE_NAME" ] || IMAGE_NAME=$(image_config_value imagedistro)
IMAGE_VERSION=$(image_config_value imageversion)
[ -n "$IMAGE_VERSION" ] || IMAGE_VERSION=$(image_config_value distroversion)
[ -n "$IMAGE_VERSION" ] || IMAGE_VERSION=$(image_config_value version)

if [ -n "$IMAGE_NAME" ]; then
    case "$IMAGE_NAME" in
        openatv|Openatv) IMAGE_NAME='OpenATV' ;;
        openpli|Openpli) IMAGE_NAME='OpenPLi' ;;
        openbh|Openbh)   IMAGE_NAME='OpenBH' ;;
        pure2|Pure2)     IMAGE_NAME='Pure2' ;;
        egami|Egami)     IMAGE_NAME='EGAMI' ;;
        openspa|OpenSpa|OpenSPA) IMAGE_NAME='OpenSPA' ;;
    esac
    [ -n "$IMAGE_VERSION" ] && IMAGE_NAME="$IMAGE_NAME $IMAGE_VERSION"
else
    if [ -r /etc/os-release ]; then
        IMAGE_NAME=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | head -n 1 | sed 's/^"//;s/"$//')
    fi
    if [ -z "$IMAGE_NAME" ] && [ -r /etc/issue ]; then
        IMAGE_NAME=$(read_first_line /etc/issue | sed -e 's/[Ww]elcome to //g' -e 's/\\n//g' -e 's/\\l//g')
    fi
fi
[ -n "$IMAGE_NAME" ] || IMAGE_NAME='Unknown'

# 3) Show receiver Python version; it does NOT determine which IPK to install.
PYTHON_VERSION=''
if command -v python >/dev/null 2>&1; then
    PYTHON_VERSION=$(python -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null)
fi
if [ -z "$PYTHON_VERSION" ] && command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null)
fi
[ -n "$PYTHON_VERSION" ] || PYTHON_VERSION='Not detected'

# Left-aligned, short lines for AJPanel and basic Telnet terminals.
print_divider
printf '%b\n' "${GREEN}NEOBOOT INSTALLER${NC}"
printf '%b\n' "${YELLOW}Created by Islam Salama${NC}"
print_divider
printf '%b\n' "${YELLOW}SYSTEM INFORMATION${NC}"
printf '%s\n' "Device Model   : $DEVICE_MODEL"
printf '%s\n' "Image Name     : $IMAGE_NAME"
printf '%s\n' "Python Version : $PYTHON_VERSION"
print_divider
printf '%b\n' "${YELLOW}INSTALLATION STATUS${NC}"

if ! command -v opkg >/dev/null 2>&1; then
    print_error 'opkg not found. This image cannot install IPK packages.'
    exit 1
fi

print_info "Downloading ${FILE_NAME} ..."
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

if ! download_file "$DOWNLOAD_URL" "$PACKAGE_PATH"; then
    print_error "Download failed: $DOWNLOAD_URL"
    print_error 'Installed NeoBoot has not been changed.'
    exit 1
fi

if [ "$(wc -c < "$PACKAGE_PATH")" -lt 1000 ]; then
    rm -f "$PACKAGE_PATH"
    print_error "Invalid or too-small package: $FILE_NAME"
    print_error 'Installed NeoBoot has not been changed.'
    exit 1
fi
print_success 'Download completed'
print_info 'Installing NeoBoot ...'

# Never uninstall the old version first; leave any other plugins untouched.
opkg install --force-reinstall --force-overwrite "$PACKAGE_PATH" > "$INSTALL_LOG" 2>&1
INSTALL_RESULT=$?
if [ "$INSTALL_RESULT" -ne 0 ]; then
    print_error "NeoBoot installation failed (code $INSTALL_RESULT)."
    if grep -qi 'Boot the Flash image' "$INSTALL_LOG" 2>/dev/null; then
        print_error 'NeoBoot requires installation from the internal FLASH image.'
        print_error 'Boot your FLASH image, then run this installer again.'
        print_error 'The package safety check was NOT bypassed.'
    fi
    cat "$INSTALL_LOG"
    rm -f "$PACKAGE_PATH"
    print_error "Log: $INSTALL_LOG"
    exit 1
fi

rm -f "$PACKAGE_PATH" "$INSTALL_LOG"
print_success 'Installation successful'
print_success 'Temporary files cleaned'
print_divider
printf '%b\n' "${GREEN}NEOBOOT INSTALLED SUCCESSFULLY!${NC}"
printf '%b\n' "${YELLOW}LONG LIFE EGYPT${NC}"
printf '%b\n' "${CYAN}Restarting Enigma2 GUI...${NC}"
print_divider
sleep 3
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart enigma2 || killall -9 enigma2
else
    killall -9 enigma2
fi
exit 0
