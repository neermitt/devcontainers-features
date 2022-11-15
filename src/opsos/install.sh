#!/usr/bin/env bash
#
# Maintainer: Neeraj Mittal

set -e

OPSOS_VERSION="${VERSION:-"latest"}"

OPSOS_SHA256="${OPSOS_SHA256:-"automatic"}"
USERNAME=${USERNAME:-"automatic"}

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

USERHOME="/home/$USERNAME"
if [ "$USERNAME" = "root" ]; then
    USERHOME="/root"
fi

# Figure out correct version of a three part version number is not passed
find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"tags/v"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"false"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
        local version_list="$(git ls-remote --tags ${repository} | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" > /dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}

apt_get_update() {
    echo "Running apt-get update..."
    apt-get update -y
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Install dependencies
check_packages curl ca-certificates
if ! type git > /dev/null 2>&1; then
    apt_get_update
    apt-get -y install --no-install-recommends git
fi


architecture="$(uname -m)"
case $architecture in
    x86_64) architecture="amd64";;
    aarch64 | armv8*) architecture="arm64";;
    i?86) architecture="386";;
    *) echo "(!) Architecture $architecture unsupported"; exit 1 ;;
esac


# Install OPSOS, verify signature and checksum
echo "Downloading opsos..."
find_version_from_git_tags OPSOS_VERSION "https://github.com/neermitt/opsos"

mkdir -p /tmp/opsos
opsos_filename="opsos_${OPSOS_VERSION}_linux_${architecture}"
tmp_opsos_filename="/tmp/opsos/opsos"
curl -sSL "https://github.com/neermitt/opsos/releases/download/v${OPSOS_VERSION}/${opsos_filename}" -o "${tmp_opsos_filename}"


mv -f "${tmp_opsos_filename}" /usr/local/bin/
chmod 0755 /usr/local/bin/opsos


if [ "$OPSOS_SHA256" = "automatic" ]; then
    curl -sSL "https://github.com/neermitt/opsos/releases/download/v${OPSOS_VERSION}/opsos_${OPSOS_VERSION}_SHA256SUMS" -o /tmp/opsos/checksums

    grep -m 1 "${opsos_filename}" /tmp/opsos/checksums

    OPSOS_SHA256="$(grep -m 1 "${opsos_filename}" /tmp/opsos/checksums | awk '{print $1}' )"
    echo "SHA256: ${OPSOS_SHA256}"
fi
([ "${OPSOS_SHA256}" = "dev-mode" ] || (echo "${OPSOS_SHA256} */usr/local/bin/opsos" | sha256sum -c -))


rm -rf /tmp/opsos


if ! type opsos > /dev/null 2>&1; then
    echo '(!) opsos installation failed!'
    exit 1
fi

echo -e "\nDone!"
