#!/usr/bin/env bash
#
# Maintainer: Neeraj Mittal

set -e

TERRAFORM_DOCS_VERSION="${VERSION:-"latest"}"
TERRAFORM_DOCS_SHA256="${SHA256:-"automatic"}"

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

# Checks if packages are instalGOMPLATE_VERSIONled and installs them if not
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


# Check and install component
install_from_git_release() {
    local component=$1
    local version_variable_name=$2
    local sha256_variable_name=$3
    local github_repo=$4

    # Install component, verify signature and checksum
    echo "Downloading ${component}..."
    find_version_from_git_tags ${version_variable_name} "https://github.com/${github_repo}"

    local requested_version=${!version_variable_name}
    local component_filename="${component}-v${requested_version}-linux-${architecture}.tar.gz"
    local tmp_component_filename="/tmp/${component}/${component_filename}"

    mkdir -p /tmp/${component}
    curl -sSL "https://github.com/${github_repo}/releases/download/v${requested_version}/${component_filename}" -o "${tmp_component_filename}"

    local requested_sha256=${!sha256_variable_name}
    if [ "$requested_sha256" = "automatic" ]; then
        curl -sSL "https://github.com/${github_repo}/releases/download/v${requested_version}/${component}-v${requested_version}.sha256sum" -o /tmp/${component}/checksums

        requested_sha256="$(grep -m 1 "${component_filename}" /tmp/${component}/checksums | awk '{print $1}' )"
        echo "SHA256: ${requested_sha256}"
    fi
    ([ "${requested_sha256}" = "dev-mode" ] || (echo "${requested_sha256} ${tmp_component_filename}" | sha256sum -c -))

    tar xf "${tmp_component_filename}" -C /tmp/${component}
    mv -f "/tmp/${component}/${component}" /usr/local/bin/
    chmod 0755 /usr/local/bin/${component}

    rm -rf /tmp/${component}

    if ! type ${component} > /dev/null 2>&1; then
        echo "(!) ${component} installation failed!"
        exit 1
    fi
}



install_from_git_release terraform-docs TERRAFORM_DOCS_VERSION TERRAFORM_DOCS_SHA256 "terraform-docs/terraform-docs"


echo -e "\nDone!"