#!/bin/bash

PLNXCHECKSUM=24c032e24f0787e97a9fe51cc03f4d0d
VIVADO_VER=2023.2
INSTALLERCMD=$(basename "$0")
PLNXINSTALL_LOG="$(pwd)/petalinux_installation_log"

function usage {
	echo "PetaLinux installer.

Usage:
  ${INSTALLERCMD} [--log <LOGFILE>] [-d|--dir <INSTALL_DIR>] [options]

Options:
  --log <LOGFILE>     		specify where the logfile should be created.
				it will be petalinux_installation_log
				in your working directory by default.
  -d|--dir [INSTALL_DIR]       	specify the directory where you want to
				install the tool kit. If not specified,
				it will install to your working directory.
  -p|--platform <arch_name>	specify the architecture name.
				aarch64 	: sources for zynqMP and versal
				aarch64_dt	: system device-tree(SDT) sources for zynqMP and versal
				arm     	: sources for zynq
				microblaze      : sources for microblaze

EXAMPLES:

Install the tool in specified location:
 \$ $0 -d/--dir <INSTALL_DIR>

To get only desired sources:
 \$ $0 --dir <INSTALL_DIR>
	This will install the sources for all(zynq,zynqMP,versal,microblaze).

 \$ $0 --dir <INSTALL_DIR> --platform \"arm\"
	This will install the sources for zynq only.

 \$ $0 --dir <INSTALL_DIR> --platform \"arm aarch64\"
	This will install the sources for zynq,zynqMP and versal.

 \$ $0 --dir <INSTALL_DIR> --platform \"microblaze\"
	This will install the sources for microblaze

 \$ $0 --dir <INSTALL_DIR> --platform \"aarch64_dt\"
	This will install the system device-tree(SDT) sources for zynqMP and versal
"
}

# Parse command line options
function parse_args {
        # Default param values
	args=$(getopt -o "hd:p:" --long "help,log:,skip_license,dir:,platform:" -- "$@")
	[ $? -ne 0 ] && usage && exit 255

	eval set -- "${args}"
	while true; do
	case "$1" in
		-h|--help)
			usage; exit 0; ;;
		--log)
			tmplog="$2"
			tmplogdir=$(dirname "${tmplog}")
			if [ -z "${tmplogdir}" ]; then
				PLNXINSTALL_LOG="$(pwd)/${tmplog}"
			elif [ ! -d "${tmplogdir}" ]; then
				echo "ERROR: log file directory ${tmplogdir} doesn't exists!"
				usage;
				exit 255;
			else
				pushd "${tmplogdir}" 1>/dev/null
				PLNXINSTALL_LOG="$(pwd)"/$(basename "${tmplog}")
				popd 1>/dev/null
			fi
			shift; shift; ;;
		-d|--dir)
			PLNXINSTALLDIR="$(readlink -f $2)";shift; shift; ;;
		-p|--platform)
			PLATFORMS="$2";shift; shift; ;;
		--skip_license)
			SKIP_LICENSE="y"
			shift; ;;
		--) shift; break; ;;
		*) usage; exit 255; ;;
	esac
	done
	if [ ! $# -eq 0 ]; then
		error_msg "Invalid options: $@"
		usage
		exit 255
	fi
}


echo "" > "${PLNXINSTALL_LOG}"

function info_msg ()
{
	echo "INFO: $@" | tee -a "${PLNXINSTALL_LOG}"
}

function error_msg ()
{
	echo "ERROR: $@" | tee -a "${PLNXINSTALL_LOG}"
}


function warning_msg ()
{
	echo "WARNING: $@" | tee -a "${PLNXINSTALL_LOG}"
}

function add_file_cleanup ()
{
	CLEANUP_FILES="${CLEANUP_FILES} $@"
}

output_exit_counter=0
function do_file_cleanup ()
{
	ret=$1
	rm -rf ${CLEANUP_FILES}
	if [ ! ${ret} -eq 0 ] && [ ${output_exit_counter} -eq 0 ]; then
		echo ""
		echo "Please refer to the PetaLinux Tools Installation Guide.

Check the troubleshooting guide at the end of that manual, and if you are
unable to resolve the issue please contact customer support with file:
   ${PLNXINSTALL_LOG}
" | tee -a "${PLNXINSTALL_LOG}"
		output_exit_counter=$((${output_exit_counter}+1))
	fi
	return ${ret}
}

function get_plnx_installer ()
{
	tail -n +$SKIP "${PLNXINSTALLLER}"
}

function accept_license {
	local license_files="${plnxinstallerdir}/${PLNX_TOOLS_LICENSE_FILE}"
	license_files="${license_files} ${plnxinstallerdir}/${THRID_PARTY_LICENSE_FILE}"
	echo ""
	echo "LICENSE AGREEMENTS"
	echo ""
	echo "PetaLinux SDK contains software from a number of sources.  Please review"
	echo "the following licenses and indicate your acceptance of each to continue."
	echo ""
	echo "You do not have to accept the licenses, however if you do not then you may "
	echo "not use PetaLinux SDK."
	echo ""
	echo "Use PgUp/PgDn to navigate the license viewer, and press 'q' to close"
	echo ""
	read -p "Press Enter to display the license agreements" dummy

	for l in ${license_files}; do
		local fprompt="the license"
		if [ $(basename "${l}") == "${PLNX_TOOLS_LICENSE_FILE}" ]; then
			fprompt="Xilinx End User License Agreement"
		else
			fprompt="Third Party End User License Agreement"
		fi
		less "${l}"
		while true; do
		read -p "Do you accept ${fprompt}? [y/N] > " accept
		case "$(echo ${accept} | tr [A-Z] [a-z])" in
		y|Y|yes|Yes|YEs|YES) break; ;;
		n|N|no|NO|No|nO) echo; info_msg " Installation aborted: License not accepted";exit 255; ;;
		* );;
	esac
	done
	done

	return 0
}

function getfilefrominstaller {
	sed -n -e "$1,$2 p" "${PLNXINSTALLLER}" > "${plnxinstallerdir}"/$3
}

# validate the esdk platform
DEFAULT_PLATFORM="aarch64 arm microblaze aarch64_dt"
function validate_esdk {
	[ -z "${PLATFORMS}" ] && PLATFORMS=${DEFAULT_PLATFORM}
	for platform in ${PLATFORMS}; do
		if ! echo $DEFAULT_PLATFORM | grep -w $platform > /dev/null; then
			error_msg "Provided esdk $platform is not supported"
			exit 255
		fi
	done
}
CLEANUP_FILES=""
PLNXINSTALLDIR=""
PLATFORMS=""

trap 'do_file_cleanup $?' EXIT KILL QUIT SEGV INT HUP TERM ERR

parse_args "$@"

validate_esdk
[ $? -ne 0 ] && warning_msg "This is not a supported architecture"
# Locate the tar ball
PLNXINSTALLLER="$0"

if [ "$UID" == 0 ]; then
    error_msg "Exiting Installer: Cannot install as root user !"
    exit
fi

plnxinstallerdir=$(mktemp -d)
if [ $? -ne 0 ]; then
        error_msg "Unable to create tmp Directory"
        error_msg "/tmp is not accessible and exiting the installation"
        exit 255
fi

add_file_cleanup "${plnxinstallerdir}"

PLNX_TOOLS_LICENSE_FILE=Petalinux_EULA.txt
THRID_PARTY_LICENSE_FILE=Third_Party_Software_End_User_License_Agreement.txt
PLNX_ENVCHECK=petalinux-env-check
PLNX_INSTALLER=petalinux-install

info_msg "Checking installation environment requirements..."
if ! command -v gawk > /dev/null; then
	echo "ERROR: The installer requires gawk, please install it first"
	exit 225
fi

INITSETUP=$(awk '/^##__INITSETUP__/ { print NR + 1; exit 0; }' "${PLNXINSTALLLER}")
SKIP=$(awk '/^##__PLNXSDK_FOLLOWS__/ { print NR + 1; exit 0; }' "${PLNXINSTALLLER}")

getfilefrominstaller $INITSETUP "$(($SKIP-2))" "initsetup.tar.xz"
truncate -s -1 ${plnxinstallerdir}/initsetup.tar.xz
tar -xf ${plnxinstallerdir}/initsetup.tar.xz -C ${plnxinstallerdir}

chmod +x "${plnxinstallerdir}"/${PLNX_ENVCHECK}
"${plnxinstallerdir}"/${PLNX_ENVCHECK} 2>&1 | tee -a "${PLNXINSTALL_LOG}"
if [ "${PIPESTATUS[0]}" -ne "0" ]; then
	warning_msg "Please install required packages."
	exit 255
fi

info_msg "Checking installer checksum..."
plnx_checksum=$(get_plnx_installer | md5sum | awk '{print $1}')
if [ ! "${PLNXCHECKSUM}" == "${plnx_checksum}" ]; then
	error_msg "Failed to install PetaLinux. Installer checksum checking failed!"
	error_msg "Expected checksum is \"${PLNXCHECKSUM}\", actual checksum is \"${plnx_checksum}\""
	exit 255
fi

info_msg "Extracting PetaLinux installer..."

[ ! "${SKIP_LICENSE}" == "y" ] && accept_license

chmod +x "${plnxinstallerdir}"/${PLNX_INSTALLER}
export PLNXINSTALLLER PLNXINSTALLDIR PLNXINSTALL_LOG PLATFORMS PLNXCHECKSUM VIVADO_VER
info_msg "Installing PetaLinux..."
"${plnxinstallerdir}"/${PLNX_INSTALLER}

exit $?
##__INITSETUP__
