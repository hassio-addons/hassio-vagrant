#!/usr/bin/env bash
# ==============================================================================
#
# Community Hass.io Add-ons: Vagrant
#
# Provisions a Vagrant guest with Hass.io
#
# ==============================================================================
set -o errexit  # Exit script when a command exits with non-zero status
set -o errtrace # Exit on error inside any functions or sub-shells
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed

# ==============================================================================
# GLOBALS
# ==============================================================================
readonly EX_OK=0
readonly HASSIO_INSTALLER="https://raw.githubusercontent.com/home-assistant/supervised-installer/master/installer.sh"
readonly DOCKER_DOWNLOAD="https://download.docker.com/linux"
readonly APT_REQUIREMENTS=(
    apparmor-utils
    apt-transport-https
    avahi-daemon
    ca-certificates
    curl
    dbus
    dkms
    jq
    network-manager
    socat
    software-properties-common
)

# ==============================================================================
# SCRIPT LOGIC
# ==============================================================================

# ------------------------------------------------------------------------------
# Installs all required software packages and tools
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
install_requirements() {
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_REQUIREMENTS[@]}"
}

# ------------------------------------------------------------------------------
# Installs the Docker engine
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
install_docker() {
    local os
    local lsb_release

    os=$(. /etc/os-release; echo "${ID}")
    lsb_release=$(lsb_release -cs)

    curl -fsSL "${DOCKER_DOWNLOAD}/${os}/gpg" | sudo apt-key add -
    
    add-apt-repository \
        "deb [arch=amd64] ${DOCKER_DOWNLOAD}/${os} ${lsb_release} stable"

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce

    usermod -aG docker ubuntu
}

# ------------------------------------------------------------------------------
# Installs and starts Hass.io
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
install_hassio() {
    curl -sL "${HASSIO_INSTALLER}" | bash -s
}

# ------------------------------------------------------------------------------
# Shows a message on how to connect to Home Assistant, including the
# dynamic IP the guest was given.
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
show_post_up_message() {
    local ip_public
    local ip_private
    
    ip_public=$(ip -4 -o addr s enp0s9|head -1|cut -d\  -f 7|cut -d/ -f 1)
    ip_private=$(ip -4 -o addr s enp0s8|head -1|cut -d\  -f 7|cut -d/ -f 1)

    echo '====================================================================='
    echo ' Community Hass.io Add-ons: Vagrant'
    echo ''
    echo ' Hass.io is installed & started! It may take a couple of minutes'
    echo ' before it is actually responding/available.'
    echo ''
    echo ' Home Assistant is running on the following links:'
    echo "  - http://${ip_private}:8123"
    echo "  - http://${ip_public}:8123"
    echo '====================================================================='
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
main() {
    install_requirements
    install_docker
    install_hassio
    show_post_up_message
    exit "${EX_OK}"
}
main "$@"
