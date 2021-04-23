#!/bin/bash
#
# Installs Forge CLI ❤️
#
# This can be called using curl:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/ForgeCloud/public-scripts/master/install_forge.sh)"
#
# Optional Vars (the defaults will work for most):
# • ARTIFACTORY_API_KEY : API key for Artifactory auth
# • FORGE_VERSION       : Version to install
# • FRAAS_CONFIG_PATH   : Path to the FRaaS config file
# • INSTALL_PATH        : Path to save Forge to
# • VERIFY_INSTALL      : "yes" to verify before install, "no" to skip
#
set -e

ARTIFACTORY_URL="https://maven.forgerock.org"
FRAAS_CONFIG_PATH=${FRAAS_CONFIG_PATH:-"${HOME}/.fraas"}
INSTALL_PATH=${INSTALL_PATH:-"/usr/local/bin/forge"}
REPO_URL="${ARTIFACTORY_URL}/repo/fraas-generic/forge"
VERIFY_INSTALL=${VERIFY_INSTALL:-"yes"}

if [[ -f "${FRAAS_CONFIG_PATH}" ]]; then
  source "${FRAAS_CONFIG_PATH}"
fi

BLUE=$(printf '\033[34m')
RED=$(printf '\033[31m')
YELLOW=$(printf '\033[33m')
RESET=$(printf '\033[m')
info() { echo "🤓 ${BLUE}$*${RESET}"; }
warning() { echo "🔔 ${YELLOW}$*${RESET}" >&2; }
error() { echo "😭 ${RED}$*${RESET}" >&2; }

echo "🎉 Welcome to Forge CLI 🎉"

case "$(uname -s)" in
  Linux) OS="linux" ;;
  Darwin) OS="mac" ;;
  *) error "Unsupported OS"; exit 1 ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  error "Please install the curl command"
  exit 1
fi

# Append a default binary name if a directory was specified
if [[ -d "${INSTALL_PATH}" ]]; then
  INSTALL_PATH="${INSTALL_PATH}/forge"
fi

if [[ -z "${ARTIFACTORY_API_KEY}" ]]; then
  error "ARTIFACTORY_API_KEY not defined"
  cat << EOF
Steps to Fix:
• Create an Artifactory account:
  ${BLUE}Log into ${ARTIFACTORY_URL} using Backstage${RESET}
• Open the profile page:
  ${BLUE}Go to ${ARTIFACTORY_URL}/repo/webapp/#/profile${RESET}
• Generate an API Key:
  ${BLUE}Enter password, click "Unlock", click "Generate"/"Regenerate"${RESET}
• Save the API key to your machine:
  ${BLUE}echo ARTIFACTORY_API_KEY="${YELLOW}<API_KEY>${BLUE}" \
  >> ${FRAAS_CONFIG_PATH}${RESET}
EOF
  exit 1
fi

AUTH="X-JFrog-Art-Api:${ARTIFACTORY_API_KEY}"

# Grab the latest version if not specified
if [[ -z "${FORGE_VERSION}" ]]; then
  info "FORGE_VERSION not specified, finding the latest version..."
  FORGE_VERSION=$(curl -fsSL -H "${AUTH}" "${REPO_URL}/latest")
fi

cat << EOF
--- Forge Config ---
• Install Path : ${BLUE}${INSTALL_PATH}${RESET}
• OS           : ${BLUE}${OS}${RESET}
• Version      : ${BLUE}${FORGE_VERSION}${RESET}
--------------------
EOF

if [[ -f "${INSTALL_PATH}" ]]; then
  warning "The existing install will be replaced"
fi

if [[ "${VERIFY_INSTALL}" == "yes" ]]; then
  echo -n "🤩 Continue install? [y/N]: "
  read CONTINUE_YESNO
  if [[ "${CONTINUE_YESNO}" != "y" && "${CONTINUE_YESNO}" != "Y" ]]; then
    echo "😭 Forge was not installed"
    exit 0
  fi
fi

FORGE_BINARY="forge-${FORGE_VERSION}-${OS}"

info "Installing ${FORGE_BINARY}..."

curl -fL -# -O -H "${AUTH}" -o "${INSTALL_PATH}" "${REPO_URL}/${FORGE_BINARY}"
chmod +x "${INSTALL_PATH}"

cat << EOF
${BLUE}
   ▄████████  ▄██████▄     ▄████████    ▄██████▄     ▄████████
  ███    ███ ███    ███   ███    ███   ███    ███   ███    ███
  ███    █▀  ███    ███   ███    ███   ███    █▀    ███    █▀
 ▄███▄▄▄     ███    ███  ▄███▄▄▄▄██▀  ▄███         ▄███▄▄▄
▀▀███▀▀▀     ███    ███ ▀▀███▀▀▀▀▀   ▀▀███ ████▄  ▀▀███▀▀▀
  ███        ███    ███ ▀███████████   ███    ███   ███    █▄
  ███        ███    ███   ███    ███   ███    ███   ███    ███
  ███         ▀██████▀    ███    ███   ████████▀    ██████████
                          ███    ███
${RESET}
🎉 Install Successful! 🎉

❤️ Forge is your tool! ❤️
Ideas/Suggestions? 👉 Slack ${YELLOW}#fraas-devx${RESET}

Next Steps:
• Run ${BLUE}"forge doctor"${RESET} and follow the hints
• Run ${BLUE}"forge help"${RESET} or add ${BLUE}"--help"${RESET} to any command
EOF
