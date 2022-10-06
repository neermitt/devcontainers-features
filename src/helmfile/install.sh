#!/usr/bin/env bash
#
# Maintainer: Neeraj Mittal

set -e

HELMFILE_VERSION="${VERSION:-"latest"}"

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

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

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
fi

echo -e "\nDone!"