#!/bin/sh

# Installation script for autorate
#
# See https://github.com/mattytap/bakesale/README_autorate for more details

# This needs to be encapsulated into a function so that we are sure that
# sh reads all the contents of the shell file before we potentially erase it.
#
# Otherwise the read operation might fail and it won't be able to proceed with
# the script as expected.
main() {
	# Set correctness options
	set -eu

	# Check if OS is OpenWRT
	unset ID_LIKE
	. /etc/os-release 2>/dev/null || true
	tainted=1
	for x in ${ID_LIKE:-}
	do
		[ "${x}" = "openwrt" ] && tainted=0
	done
	if [ "${tainted}" -eq 1 ]
	then
		printf "This script requires OpenWrt.\n" >&2
		return 1
	fi
	unset tainted

	# Setup dependencies to check for
	DEPENDENCIES="jsonfilter uclient-fetch tar grep"

	# Set up remote locations and branch
	BRANCH="${AUTORATE_BRANCH:-${2-main}}"
	REPOSITORY="${AUTORATE_REPO:-${1-mattytap/bakesale}}"
	SRC_DIR="https://github.com/${REPOSITORY}/archive/"
	API_URL="https://api.github.com/repos/${REPOSITORY}/commits/${BRANCH}"
	DOC_URL="https://github.com/${REPOSITORY}/tree/${BRANCH}#autorate-Installation"

	# Check if an instance of autorate is already running and exit if so
	if [ -d /var/run/bakesale ]
	then
		printf "At least one instance of autorate appears to be running - exiting\n" >&2
		printf "If you want to install a new version, first stop any running instance of autorate\n" >&2
		printf "If you are sure that no instance of autorate is running, delete the /var/run/bakesale directory\n" >&2
		exit 1
	fi

	# Retrieve required packages if not present
	# shellcheck disable=SC2312
	if [ "$(opkg list-installed | grep -Ec '^(bash|iputils-ping|fping) ')" -ne 3 ]
	then
		printf "Running opkg update to update package lists:\n"
		opkg update
		printf "Installing bash, iputils-ping and fping packages:\n"
		opkg install bash iputils-ping fping
	fi

	exit_now=0
	for dep in ${DEPENDENCIES}
	do
		if ! type "${dep}" >/dev/null 2>&1; then
			printf >&2 "%s is required, please install it and rerun the script!\n" "${dep}"
			exit_now=1
		fi
	done
	[ "${exit_now}" -ge 1 ] && exit "${exit_now}"

	# Set up autorate files
	# Set up autorate files in /usr/lib
	cd /usr/lib/ || exit 1
	[ -d bakesale ] || mkdir bakesale || exit 1
	cd bakesale/ || exit 1

	# Set up directory in /etc
	cd /etc/ || exit 1
	[ -d bakesale.d ] || mkdir bakesale.d || exit 1
	cd bakesale.d/ || exit 1

	# Get the latest commit to download
	commit=$(uclient-fetch -qO- "${API_URL}" | jsonfilter -e @.sha)
	if [ -z "${commit:-}" ];
	then
		printf >&2 "Invalid operation occurred, commit variable should not be empty"
		exit 1
	fi

	printf "Installing autorate in /usr/lib/bakesale...\n"

	# Download the files to a temporary directory, so we can move them to the autorate directory
	tmp=$(mktemp -d)
	trap 'rm -rf "${tmp}"' EXIT INT TERM
	uclient-fetch -qO- "${SRC_DIR}/${commit}.tar.gz" | tar -xozf - -C "${tmp}"
	mv "${tmp}/bakesale-"*/usr/lib/bakesale/* "${tmp}"
	mv "${tmp}/bakesale-"*/etc/bakesale.d/config* "${tmp}"

	# Check if a configuration file exists, and ask whether to keep it
	editmsg="\nNow edit the config.primary.sh file as described in:\n   ${DOC_URL}"
	if [ -f config.primary.sh ]
	then
		printf "Previous configuration present - keep it? [Y/n] "
		read -r keepIt
		if [ "${keepIt}" = "N" ] || [ "${keepIt}" = "n" ]; then
			mv "${tmp}/config.primary.sh" /etc/bakesale.d/config.primary.sh
			rm -f /etc/bakesale.d/config.primary.sh.new   # delete config.primary.sh.new if exists
		else
			editmsg="Using prior configuration"
			mv "${tmp}/config.primary.sh" /etc/bakesale.d/config.primary.sh.new
		fi
	else
		mv "${tmp}/config.primary.sh" /etc/bakesale.d/config.primary.sh
	fi

	# remove old program files from autorate directory
	old_fnames="autorate.sh autorate_defaults.sh autorate_launcher.sh autorate_lib.sh autorate_setup.sh"
	for file in ${old_fnames}
	do
		rm -f "${file}"
	done

	# move the program files to the autorate directory
	# scripts that need to be executable are already marked as such in the tarball
	files="autorate.sh defaults.sh launcher.sh lib.sh setup_autorate.sh uninstall_autorate.sh"
	for file in ${files}
	do
		mv "${tmp}/${file}" "${file}"
	done

	# Get version and generate a file containing version information
	version=$(grep -m 1 ^autorate_version= /usr/lib/bakesale/autorate.sh | cut -d= -f2 | cut -d'"' -f2)
	cat > version.txt <<-EOF
		version=${version}
		commit=${commit}
	EOF

	# Also copy over the service file but DO NOT ACTIVATE IT
	mv "${tmp}/bakesale-"*/etc/init.d/autorate /etc/init.d/autorate
	chmod +x /etc/init.d/autorate

	# Tell how to handle the config file - use old, or edit the new one
	# shellcheck disable=SC2059
	printf "${editmsg}\n"

	printf '\n%s\n\n' "${version} successfully installed, but not yet running"
	printf '%s\n' "Start the software manually with:"
	printf '%s\n' "   cd /usr/lib/bakesale; ./autorate.sh"
	printf '%s\n' "Run as a service with:"
	printf '%s\n\n' "   service autorate enable; service autorate start"
}

# Now that we are sure all code is loaded, we could execute the function
main "${@}"
