#!/usr/bin/env bash

function set_vars()
{
	FRAAS_CONFIG_PATH=${FRAAS_CONFIG_PATH:-"${HOME}/.fraas"}
	INSTALL_PATH=${INSTALL_PATH:-"/usr/local/bin/fraas-logs"}
	ARTIFACTORY_URL="https://maven.forgerock.org"
	REPO_NAME="fraas-generic"
	REPO_PATH="fraas-logs"
	REPO_URL="${ARTIFACTORY_URL}/repo/${REPO_NAME}/${REPO_PATH}"
	GOOS=`uname -s | tr "[:upper:]" "[:lower:]"`
	GOARCH=`uname -m | sed 's/x86_64/amd64/g'`
	ARCH=${GOOS}-${GOARCH}
	source "${FRAAS_CONFIG_PATH}" 2>/dev/null
}

function current_ver()
{
	CURR_VER=`fraas-logs version 2>/dev/null | sed -n 's/.*"Version"[ ]*:[ ]*"\([^"]*\)",.*/\1/p'`
}

function latest_ver()
{
	LATEST_VER=`curl -fsSL $AUTH "${REPO_URL}/fraas-logs-latest.txt"`
	status=$?
	if [[ $status -ne 0 ]]; then
		echo "Error downloading latest version from ${REPO_URL}/fraas-logs-latest.txt"
		exit $status
	fi
}

function get_target()
{
	if [[ "$1" ]]; then
		TARGET_VER=$1
		return
	fi

	current_ver
	latest_ver

	if [[ "$CURR_VER" = "" ]]; then
		echo "Installing fraas-logs"
	else
		echo "Current version ${CURR_VER}, checking for updates"
	fi

	if [[ "$CURR_VER" = "$LATEST_VER" ]]; then
	        echo "Good news: fraas-logs is already up to date!"
	        exit 0
	else
	        echo "Newer version available: ${LATEST_VER}"
		TARGET_VER=$LATEST_VER
	fi
}

function get_install_path()
{
	if [[ "$1" ]]; then
		INSTALL_PATH=$1/fraas-logs
	fi
}

function get_auth()
{
	if [[ -z ${ARTIFACTORY_API_KEY} ]]; then
		echo "ARTIFACTORY_API_KEY not set in ~/.fraas, prompting for username and password"
		echo "Enter credentials for maven.forgerock.org"
		read -p "username: " ARTIFACTORY_USERNAME
		read -sp "password: " ARTIFACTORY_PASSWORD
		echo ""
		AUTH="-u ${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}"
	else
		AUTH="-H X-JFrog-Art-Api:${ARTIFACTORY_API_KEY}"
	fi
}

function check_arch()
{
	ARCH_FOUND=`echo $'darwin-amd64\nlinux-amd64' | egrep "^${ARCH}$"`
	if [[ "$ARCH_FOUND" = "" ]]; then
		echo "Architecture ${ARCH} not supported"
		exit 1
	fi
}

function download_binary()
{
	FRAAS_LOGS_BINARY=fraas-logs-${TARGET_VER}-${ARCH}

	echo -n "Downloading ${FRAAS_LOGS_BINARY}... "
	curl -fsSL $AUTH "${REPO_URL}/${FRAAS_LOGS_BINARY}" -o /tmp/${FRAAS_LOGS_BINARY}
	status=$?
	if [[ $status -ne 0 ]]; then
	        echo "Error downloading ${REPO_URL}/${FRAAS_LOGS_BINARY}!"
	        exit $status
	fi
	echo "done!"
}

function install_binary()
{
	if [[ $EUID -eq 0 ]] || [[ "${GOOS}" = "darwin" ]]; then
	        echo "Moving fraas-logs to ${INSTALL_PATH}"
	        chmod +x /tmp/${FRAAS_LOGS_BINARY} && mv /tmp/${FRAAS_LOGS_BINARY} ${INSTALL_PATH}
	        status=$?
	        if [[ $status -ne 0 ]]; then
	                echo "Error installing fraas-logs"
	                exit $status
	        fi
	elif [[ -x "$(command -v sudo)" ]]; then
	        echo "Moving fraas-logs to ${INSTALL_PATH} using sudo"
	        chmod +x /tmp/${FRAAS_LOGS_BINARY} && sudo mv /tmp/${FRAAS_LOGS_BINARY} ${INSTALL_PATH}
	        status=$?
	        if [[ $status -ne 0 ]]; then
	                echo "Error installing fraas-logs"
	                exit $status
	        fi
	else
	        echo "Failed to install: please try running script as root"
	        exit 1
	fi

	echo "Installed fraas-logs version ${TARGET_VER} at ${INSTALL_PATH}. Happy logging!"
}

function print_help()
{
	echo "get_fraas_logs.sh"
	echo ""
	echo "Installs a version of fraas-logs from artifactory. if a version is not"
	echo "specified, it will install or upgrade you to the latest."
	echo ""
	echo "usage: get_fraas_logs.sh <install_path> <version>"
	echo ""
	echo "examples:"
	echo "    ./get_fraas_logs.sh /usr/local/bin 1.2.0"
	echo "    ./get_fraas_logs.sh /tmp 1.3.1-FRAAS-1234_my-branch"
	echo "    ./get_fraas_logs.sh /home/username/bin"
	echo ""
}

function main()
{
	if [[ "$1" == "-h" ]]; then
		print_help
		exit 0
	fi

	ARG_PATH=$1
	ARG_VER=$2

	set_vars
	get_auth
	get_target $ARG_VER
	get_install_path $ARG_PATH
	check_arch
	download_binary
	install_binary
}

main $1 $2
