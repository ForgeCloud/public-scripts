#!/usr/bin/env bash

FRAAS_CONFIG_PATH=${FRAAS_CONFIG_PATH:-"${HOME}/.fraas"}
INSTALL_PATH=${INSTALL_PATH:-"/usr/local/bin/fraas-logs"}

source "${FRAAS_CONFIG_PATH}" 2>/dev/null

CURR_VER=`fraas-logs version 2>/dev/null | sed -n 's/.*"Version"[ ]*:[ ]*"\([^"]*\)",.*/\1/p'`
if [ "$CURR_VER" = "" ]; then
	echo "Installing fraas-logs"
else
	echo "Current version ${CURR_VER}, checking for updates"
fi

AUTH=""

if [ -z ${ARTIFACTORY_API_KEY} ]
then
	echo "ARTIFACTORY_API_KEY not set in ~/.fraas, prompting for username and password"
	echo "Enter credentials for maven.forgerock.org"
	read -p "username: " ARTIFACTORY_USERNAME
	read -sp "password: " ARTIFACTORY_PASSWORD
	echo ""
	AUTH="-u ${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}"
else
	AUTH="-H X-JFrog-Art-Api:${ARTIFACTORY_API_KEY}"
fi

ARTIFACTORY_URL="https://maven.forgerock.org"
REPO_NAME="fraas-generic"
REPO_PATH="fraas-logs"
REPO_URL="${ARTIFACTORY_URL}/repo/${REPO_NAME}/${REPO_PATH}"

LATEST_VER=`curl -fsSL $AUTH "${REPO_URL}/fraas-logs-latest.txt"`
status=$?
if [ $status -ne 0 ]; then
	echo "Error downloading latest version from ${REPO_URL}/fraas-logs-latest.txt"
	exit $status
fi

if [ "$CURR_VER" = "$LATEST_VER" ]; then
	echo "Good news: fraas-logs is already up to date!"
	exit 0
else
	echo "Newer version available: ${LATEST_VER}"
fi

GOOS=`uname -s | tr "[:upper:]" "[:lower:]"`
GOARCH=`uname -m | sed 's/x86_64/amd64/g'`
ARCH=${GOOS}-${GOARCH}
ARCH_FOUND=`echo $'darwin-amd64\nlinux-amd64' | egrep "^${ARCH}$"`
if [ "$ARCH_FOUND" = "" ]; then
	echo "Architecture ${ARCH} not supported"
	exit 1
fi

FRAAS_LOGS_BINARY=fraas-logs-${LATEST_VER}-${ARCH}

echo -n "Downloading ${FRAAS_LOGS_BINARY}... "
curl -fsSL $AUTH "${REPO_URL}/${FRAAS_LOGS_BINARY}" -o /tmp/${FRAAS_LOGS_BINARY}
status=$?
if [ $status -ne 0 ]; then
        echo "Error downloading ${REPO_URL}/${FRAAS_LOGS_BINARY}!"
        exit $status
fi
echo "done!"

if [ "${GOOS}" = "darwin" ]; then
	echo "Moving fraas-logs to ${INSTALL_PATH}"
	chmod +x /tmp/${FRAAS_LOGS_BINARY} && mv /tmp/${FRAAS_LOGS_BINARY} ${INSTALL_PATH}
	status=$?
	if [ $status -ne 0 ]; then
		echo "Error installing fraas-logs"
		exit $status
	fi
else
	echo "Moving fraas-logs to ${INSTALL_PATH} using sudo"
	chmod +x /tmp/${FRAAS_LOGS_BINARY} && sudo mv /tmp/${FRAAS_LOGS_BINARY} ${INSTALL_PATH}
	status=$?
	if [ $status -ne 0 ]; then
		echo "Error installing fraas-logs"
		exit $status
	fi
fi

echo "Installed fraas-logs version ${LATEST_VER} at ${INSTALL_PATH}. Happy logging!"
