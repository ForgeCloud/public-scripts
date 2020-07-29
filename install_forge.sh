#!/bin/bash
#
# Installs Forge CLI ❤️
#
# This can be called using curl:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/ForgeCloud/public-scripts/master/install_forge.sh)"
#
# Optional Vars (the defaults will work for most):
# • ARTIFACTORY_API_KEY : API key for Artifactory auth
# • FORGE_VERSION       : Version to install (i.e, 2.1.0, 2.1.*, 2.*, *)
# • FRAAS_CONFIG_PATH   : Path to the FRaaS config file
# • INSTALL_PATH        : Path to save Forge to
#
# Pass "-y" or "--yes" to skip user prompts:
#   bash forge_intall.sh -y
#
set -e

FORGE_VERSION=${FORGE_VERSION:-"*"}
FRAAS_CONFIG_PATH=${FRAAS_CONFIG_PATH:-"${HOME}/.fraas"}
INSTALL_PATH=${INSTALL_PATH:-"/usr/local/bin/forge"}
VERIFY_INSTALL="yes"

ARTIFACTORY_URL="https://maven.forgerock.org"
REPO_NAME="fraas-generic"
REPO_PATH="forge"
REPO_URL="${ARTIFACTORY_URL}/repo/${REPO_NAME}/${REPO_PATH}"

BLUE=$(printf '\033[34m')
RED=$(printf '\033[31m')
YELLOW=$(printf '\033[33m')
RESET=$(printf '\033[m')

info() {
  echo "🤓 ${BLUE}$*${RESET}"
}

warning() {
  echo "🔔 ${YELLOW}$*${RESET}" >&2
}

error() {
  echo "😭 ${RED}$*${RESET}" >&2
}

echo "🎉 Welcome to Forge CLI 🎉"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    -y|--yes) VERIFY_INSTALL="no" ;;
    *)
      error "Unknown argument: ${1}"
      exit 1
      ;;
  esac
  shift
done

if [[ -f "${FRAAS_CONFIG_PATH}" ]]; then
  source "${FRAAS_CONFIG_PATH}"
fi

case "$(uname -s)" in
  Linux) OS="linux" ;;
  Darwin) OS="mac" ;;
  *)
    error "Unsupported OS"
    exit 1
    ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  error "Please install the curl command"
  exit 1
fi

# Avoid confusion when installing the latest binary
DISPLAY_VERSION="latest"
if [[ "${FORGE_VERSION}" != "*" ]]; then
  DISPLAY_VERSION="${FORGE_VERSION}"
fi

cat << EOF
--- Forge Config ---
• Install Path : ${BLUE}${INSTALL_PATH}${RESET}
• OS           : ${BLUE}${OS}${RESET}
• Version      : ${BLUE}${DISPLAY_VERSION}${RESET}
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

info "Searching for the Forge binary..."

QUERY_VERSION="forge-${FORGE_VERSION}-${OS}"
AQL_QUERY=$(cat << EOF
items.find({"\$and":[
  {"repo":{"\$match":"${REPO_NAME}"}},
  {"path":{"\$match":"${REPO_PATH}"}},
  {"name":{"\$match":"${QUERY_VERSION}"}}
]})
.sort({"\$desc": ["name"]})
.limit(1)
EOF
)

QUERY_RESULT=$(curl -fsSL -X POST "${ARTIFACTORY_URL}/repo/api/search/aql" \
  -H "X-JFrog-Art-Api:${ARTIFACTORY_API_KEY}" \
  -H "Content-Type: text/plain" \
  -d "${AQL_QUERY}")

# Using sed to avoid requiring a json parser to install Forge
FORGE_BINARY=$(echo "${QUERY_RESULT}" | sed -n 's/.*"name" : "\(.*\)",/\1/p')

if [[ -z "${FORGE_BINARY}" ]]; then
  error "Could not find the Forge version specified"
  error "Verify the binary is available at ${REPO_URL}"
  exit 1
fi

info "Installing ${FORGE_BINARY}..."

curl -fsSL "${REPO_URL}/${FORGE_BINARY}" \
  -H "X-JFrog-Art-Api:${ARTIFACTORY_API_KEY}" \
  -o "${INSTALL_PATH}"

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
