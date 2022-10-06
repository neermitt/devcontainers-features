#!/usr/bin/env bash
#
# Maintainer: Neeraj Mittal

set -e

HELMFILE_VERSION="${VERSION:-"latest"}"

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

apt_get_update()
{
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


# Install Helmfile, verify signature and checksum
echo "Downloading Helmfile..."
find_version_from_git_tags HELMFILE_VERSION "https://github.com/helmfile/helmfile"

mkdir -p /tmp/helmfile
helmfile_filename="helmfile_${HELMFILE_VERSION}_linux_${architecture}.tar.gz"
tmp_helmfile_filename="/tmp/helmfile/${helmfile_filename}"
curl -sSL "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/${helmfile_filename}" -o "${tmp_helmfile_filename}"

tar xf "${tmp_helmfile_filename}" -C /tmp/helmfile
mv -f "/tmp/helmfile/helmfile" /usr/local/bin/
chmod 0755 /usr/local/bin/helmfile
rm -rf /tmp/helm
if ! type helmfile > /dev/null 2>&1; then
    echo '(!) Helmfile installation failed!'
    exit 1
fi

if ! type helm > /dev/null 2>&1; then
    echo -e '\n(*) Warning: The helm command was not found.\n\nYou can use one of the following scripts to install it:\n\nhttps://github.com/microsoft/vscode-dev-containers/blob/main/script-library/docs/kubectl-helm.md'
else
    helm plugin install https://github.com/databus23/helm-diff 
fi

echo -e "\nDone!"