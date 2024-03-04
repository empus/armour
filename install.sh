#!/bin/bash

# -------------------------------------------------------------------------------
# Armour install script
# -------------------------------------------------------------------------------
# 
# Usage:
#         ./install.sh [option]
#
#           -i              Install Armour (and optionally, eggdrop)
#           -a              Add a new bot to existing Armour install
#           -h, --help      Display script options
#
# -------------------------------------------------------------------------------
#
# Tested on:
#           - Debian 12
#           - CentOS 9
#           - Ubuntu 23.10
#           - FreeBSD 
#           - macOS 14.3
#
# -------------------------------------------------------------------------------
# https://armour.bot/setup 
# -------------------------------------------------------------------------------


ARMOUR_VER="v4.0"
ARMOUR_GIT="https://github.com/empus/armour"
EGGDROP_VER="1.9.5"
EGGDROP_URL="https://ftp.eggheads.org/pub/eggdrop/source/1.9/eggdrop-1.9.5.tar.gz"

set -u
shopt -s nocasematch # -- case insensitive matching
stty erase '^?'      # -- fix backspace with 'read'

abort() {
    printf "%s\n" "$@" >&2
    exit 1
}

# -- bash required
if [ -z "${BASH_VERSION:-}" ]
then
    abort "Bash is required to interpret this script."
fi



# -- string formatters
if [[ -t 1 ]]; then
    tty_escape() { printf "\033[%sm" "$1"; }
else
    tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_red="$(tty_mkbold 31)"
tty_green="$(tty_mkbold 32)"
tty_yellow="$(tty_mkbold 33)"
tty_blue="$(tty_mkbold 34)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
    local arg
    printf "%s" "$1"
    shift
    for arg in "$@"
    do
        printf " "
        printf "%s" "${arg// /\ }"
    done
}

chomp() {
    printf "%s" "${1/"$'\n'"/}"
}

ohai() {
    printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

warn() {
    printf "${tty_yellow}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
}

# -- error checker
check_error() {
    if [ $? -ne 0 ]; then
        ring_bell
        return 1
    else
        return 0
    fi
}

# -- check the OS
OS="$(uname)"
if [[ "${OS}" == "Linux" ]]; then
    ARMOUR_ON_LINUX=1
elif [[ "${OS}" == "FreeBSD" ]]; then
    SYSTEM="FreeBSD"
    ARMOUR_ON_BSD=1
elif [[ "${OS}" == "OpenBSD" ]]; then
    ARMOUR_ON_BSD=1
    SYSTEM="OpenBSD"
elif [[ "${OS}" == "NetBSD" ]]; then
    ARMOUR_ON_BSD=1
    SYSTEM="NetBSD"
elif [[ "${OS}" == "Darwin" ]]; then
    ARMOUR_ON_MACOS=1
else
    echo "${tty_red}Error:${tty_reset} Armour install script is only supported on Linux, FreeBSD, NetBSD, OpenBSD, and macOS"
    abort
fi

# -- set OS specific package manager and packages
MD5="md5"
PKG_OATHTOOL="oathtool"
PKG_IMAGEMAGICK="imagemagick"
if [[ -n "${ARMOUR_ON_LINUX-}" ]]; then
    # -- Linux default to apt-get
    SYSTEM="Linux"
    PKGMGR="apt-get"
    PKGMGR_ARGS="install -y"
    PACKAGES="gcc curl git tcl tcl-dev tcllib tcl-tls sqlite3 libsqlite3-tcl"
    if [ -f /etc/centos-release ]; then
        # -- CentOS
        SYSTEM="CentOS"
        PKGMGR="yum"
        PKGMGR_ARGS="install -y"
        PACKAGES="gcc epel-release curl git tcl tcl-devel tcltls sqlite-devel"
        PKG_IMAGEMAGICK="ImageMagick"
    else
        if [ -f "/etc/os-release" ]; then
            if grep -q "^ID=ubuntu" "/etc/os-release"; then
                # -- Ubuntu
                SYSTEM="Ubuntu"
                PKGMGR="apt-get"
                PKGMGR_ARGS="install -y"
                PACKAGES="gcc make curl git tcl tcl-dev tcllib tcl-tls sqlite3 libsqlite3-tcl"
            fi
        fi        
    fi
elif [[ -n "${ARMOUR_ON_BSD-}" ]]
then
    PKGMGR="pkg"
    PKGMGR_ARGS="install -y"
    PACKAGES="curl git tcl tcllib tcl-tls sqlite3 libsqlite3-tcl"
    PKG_IMAGEMAGICK="ImageMagick7"
    MD5="md5sum"
elif [[ -n "${ARMOUR_ON_MACOS-}" ]]
then
    SYSTEM="macOS"
    PKGMGR="brew"
    PKGMGR_ARGS="install"
    #PACKAGES="curl git tcl tcllib tcltls sqlite3 tcl-sqlite3 oath-toolkit imagemagick"
    PACKAGES="curl git tcl sqlite3 oath-toolkit imagemagick"
    PKG_OATHTOOL="oath-toolkit"
fi

execute() {
    if ! "$@"
    then
        abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
    fi
}

# -- read user input
getc() {
    local save_state
    save_state="$(/bin/stty -g)"
    /bin/stty raw -echo
    IFS='' read -r -n 1 -d '' "$@"
    /bin/stty "${save_state}"
}

# -- ring audible shell bell
ring_bell() {
    if [[ -t 1 ]]
    then
        printf "\a"
    fi
}

wait_for_user() {
    local c
    echo
    echo "Press ${tty_bold}RETURN${tty_reset}/${tty_bold}ENTER${tty_reset} to begin, or any other key to abort:"
    getc c
    # -- test for \r and \n because some stuff does \r instead
    if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]
    then
        exit 1
    fi
}

# -- check if prerequisites will be installed
ASKED=0
ask_for_prereq() {
    local input
    echo
    ohai "Do you wish to install prerequisite packages and tools? (${tty_green}Y${tty_reset})es or (${tty_green}N${tty_reset})o"
    echo
    echo "    sudo ${PKGMGR} ${PKGMGR_ARGS} ${PACKAGES}"
    echo 
    getc input
    if [[ "${input}" == 'y' ]]
    then
        install_prereq
    elif [[ "${input}" == 'n' ]]
    then
        warn "Not installing prerequisite TCL packages and tools.  Armour will not run if these are not already installed."
        if [[ "${ASKED}" -eq 1 ]]
        then
            echo
            echo "${tty_red}Error:${tty_reset} You must install the prerequisites before installing Armour. See:"
            echo "       ${tty_underline}https://armour.bot/setup/install/#requirements${tty_reset}"
            abort
        fi
        echo
    else
        ring_bell
        warn "Invalid input, please select (Y)es or (N)o"
        echo
        ask_for_prereq
    fi
}

# -- check for sudo
check_sudo() {
    if ! command -v sudo >/dev/null
    then
        ring_bell
        echo "${tty_red}Error:${tty_reset} You must install ${tty_bold}sudo${tty_reset} to install prerequisites from this script."
        abort
    fi
}

# -- install the prerequisites
install_prereq() {
    check_sudo
    ohai "Installing prerequisites..."
    if [[ "${SYSTEM}" != "macOS" ]]; then
        ohai "sudo ${PKGMGR} ${PKGMGR_ARGS} ${PACKAGES}"
        sudo ${PKGMGR} ${PKGMGR_ARGS} ${PACKAGES}
        return_code=$?
    else
        # -- macOS: don't run brew as root
        ohai "${PKGMGR} ${PKGMGR_ARGS} ${PACKAGES}"
        ${PKGMGR} ${PKGMGR_ARGS} ${PACKAGES}
        return_code=$?
    fi
    if [ ! $return_code -eq 0 ]; then
        echo
        echo "${tty_red}Error:${tty_reset} failed package install.  Please correct and try again."
        echo
        abort
    fi
    echo
    ohai "Done!"
    echo
}

# -- check if prerequisites exist
check_prereqs() {
    # -- check for cURL
    CURL=`command -v curl`
    ohai "CURL: ${CURL}"
    if [ "${CURL}" == "" ]; then
        ring_bell
        echo
        echo "${tty_red}Error:${tty_reset} You must install ${tty_bold}cURL${tty_reset} before installing Armour. See:"
        echo "       ${tty_underline}https://armour.bot/setup/install/#requirements${tty_reset}"
        ask_for_prereq
    fi

    # -- check for Git
    GIT=`command -v git`
    ohai "GIT: ${GIT}"
    if [ "${GIT}" == "" ]; then
        ring_bell
        echo
        echo "${tty_red}Error:${tty_reset} You must install ${tty_bold}Git${tty_reset} before installing Armour. See:"
        echo "       ${tty_underline}https://armour.bot/setup/install/#requirements${tty_reset}"
        ASKED=1
        ask_for_prereq
    fi

    # -- check for oathtool
    OATHTOOL=`command -v oathtool`
    ohai "OATHTOOL: ${OATHTOOL}"
    #if [ "${OATHTOOL}" == "" ]; then
    #    ring_bell
    #    echo
    #    echo "${tty_red}Error:${tty_reset} You must install ${tty_bold}oathtool${tty_reset} before installing Armour. See:"
    #    echo "       ${tty_underline}https://armour.bot/setup/install/#requirements${tty_reset}"
    #    ASKED=1
    #    ask_for_prereq
    #fi

    # -- check for ImageMagick
    CONVERT=`command -v convert`
    ohai "CONVERT: ${CONVERT}"
    #if [ ${CONVERT} == "" ]; then
    #    ring_bell
    #    ehco
    #    echo "${tty_red}Error:${tty_reset} You must install ${tty_bold}ImageMagick7${tty_reset} before installing Armour. See:"
    #    echo "       ${tty_underline}https://armour.bot/setup/install/#requirements${tty_reset}"
    #    ASKED=1
    #    ask_for_prereq
    #fi
}


# -- check if eggdrop needs installing
NEW_EGGDROP=false
ask_for_eggdrop() {
    local input
    echo
    ohai "Is this for a (${tty_green}N${tty_reset})ew or (${tty_green}E${tty_reset})xisting ${tty_bold}eggdrop${tty_reset} installation?"
    echo
    echo "    Selecting ${tty_green}N${tty_reset} will download, install, and configure ${tty_bold}eggdrop ${EGGDROP_VER}${tty_reset} before then downloading, installing, and configuring Armour ${ARMOUR_VER}"
    echo "    Selecting ${tty_green}E${tty_reset} will install Armour ${ARMOUR_VER} to an ${tty_bold}existing${tty_reset} eggdrop installation."
    echo 
    getc input
    if [[ "${input}" == 'n' ]]
    then
        NEW_EGGDROP=true
        download_eggdrop
    elif [[ "${input}" == 'e' ]]
    then
        existing_eggdrop
    else
        ring_bell
        warn "Invalid input, please select (${tty_green}N${tty_reset})ew or (${tty_green}E${tty_reset})xisting"
        echo
        ask_for_eggdrop
    fi
}

# -- check which eggdrop install directory to use
ask_for_eggdrop_dir() {
    local input
    ohai "What eggdrop installation directory should be used? [${tty_green}${HOME}/bots${tty_reset}]"
    echo
    read input
    EGGDROP_INSTALL_DIR=${input}
    if [ "${EGGDROP_INSTALL_DIR}" == "" ]; then
        EGGDROP_INSTALL_DIR="${HOME}/bots"
    fi
    echo
    ohai "Using eggdrop install directory: ${tty_green}${EGGDROP_INSTALL_DIR}${tty_reset}"
    if [ -d ${EGGDROP_INSTALL_DIR} ]; then
        # -- chosen eggdrop install directory exists
        if [ ${NEW_EGGDROP} == true ]; then
            # -- new eggdrop install but directory already exists
            ring_bell
            echo
            echo "${tty_red}Error:${tty_reset} new eggdrop install directory ${EGGDROP_INSTALL_DIR} already exists.  Please either:"
            echo "         - Delete, move or rename this directory; ${tty_bold}or${tty_reset}"
            echo "         - Run this script for an ${tty_green}existing${tty_reset} eggdrop installation; ${tty_bold}or${tty_reset}"
            echo "         - Choose another eggdrop installation directory."
            echo
            ask_for_eggdrop_dir
        elif [ ! -f "${EGGDROP_INSTALL_DIR}/eggdrop" ]; then
            # -- install directory exists but eggdrop binary does not
            ring_bell
            echo
            echo "${tty_red}Error:${tty_reset} chosen eggdrop install directory ${EGGDROP_INSTALL_DIR} does not contain ${tty_bold}eggdrop${tty_reset} binary.  Please either:"
            echo "         - Choose another eggdrop installation directory; ${tty_bold}or${tty_reset}"
            echo "         - Run this script again after eggdrop is propery installed; ${tty_bold}or${tty_reset}"
            echo "         - Run this script again and select to create a ${tty_green}new${tty_reset} eggdrop install"
            echo
            ask_for_eggdrop_dir   
        fi
    else
        if [ ${NEW_EGGDROP} == false ]; then
            # -- existing eggdrop, but directory doesn't exist
            ring_bell
            echo
            echo "${tty_red}Error:${tty_reset} existing eggdrop install directory ${EGGDROP_INSTALL_DIR} doesn't exist.  Please either:"
            echo "         - Choose another eggdrop installation directory; ${tty_bold}or${tty_reset}"
            echo "         - Run this script again and select a new eggdrop installation"
            echo
            ask_for_eggdrop_dir 
        fi
    fi
    echo
}

# -- user has selected to use an existing eggdrop installation
existing_eggdrop() {
    ask_for_eggdrop_dir
    ask_for_botname
    install_armour
}

# -- new eggdrop installation
download_eggdrop() {
    ohai "Installing ${tty_bold}eggdrop ${EGGDROP_VER}${tty_reset}..."
    echo
    EGGDROP_FILE=$(basename ${EGGDROP_URL})
    if [ ! -f ${EGGDROP_FILE} ]; then
        ohai "Downloading ${tty_bold}eggdrop ${EGGDROP_VER}${tty_reset} from ${EGGDROP_URL}"
        echo
        curl --progress-bar ${EGGDROP_URL} --output ${EGGDROP_FILE}
        echo
        ohai "Done!"
        echo
    else
        ohai "${tty_bold}${EGGDROP_FILE}${tty_reset} already exists in this directory..."
        echo
    fi
    EGGDROP_DIR="${EGGDROP_FILE%.tar.gz}"
    if [ -d ${EGGDROP_DIR} ]; then
        ring_bell
        echo "${tty_red}Error:${tty_reset} directory ${EGGDROP_DIR} already exists in this location.  Please either:"
        echo "         - Delete, move or rename this directory; ${tty_bold}or${tty_reset}"
        echo "         - Run this script for an existing eggdrop installation; ${tty_bold}or${tty_reset}"
        echo "         - Run this script from another location."
        abort
    fi
    ohai "Extracting ${EGGDROP_FILE}..."
    tar -xf ${EGGDROP_FILE}
    echo
    ohai "Done!"
    echo
    build_eggdrop
}

# -- configure, compile, and install eggdrop
build_eggdrop() {
    ask_for_eggdrop_dir
    ohai "Building ${tty_bold}eggdrop ${EGGDROP_VER}${tty_reset} ..."
    cd ${EGGDROP_DIR}
    ./configure --prefix=${EGGDROP_INSTALL_DIR}
    return_code=$?
    if [ ! $return_code -eq 0 ]; then
        echo
        echo "${tty_red}Error:${tty_reset} eggdrop configure script failed.  Please check logs and try again.  Delete the ${EGGDROP_DIR} directory to allow retry."
        echo
        abort
    fi
    echo
    ohai "Compiling ${tty_bold}eggdrop ${EGGDROP_VER}${tty_reset} ..."
    echo
    make config && make
    return_code=$?
    if [ ! $return_code -eq 0 ]; then
        echo
        echo "${tty_red}Error:${tty_reset} eggdrop compilation failed.  Please check logs and try again.  Delete the ${tty_bold}${EGGDROP_DIR}${tty_reset} directory to allow retry."
        echo
        abort
    fi
    echo
    ohai "Installing ${tty_bold}eggdrop ${EGGDROP_VER}${tty_reset} to ${tty_bold}${EGGDROP_INSTALL_DIR}${tty_reset} ..."
    echo
    make install
    return_code=$?
    if [ ! $return_code -eq 0 ]; then
        echo
        echo "${tty_red}Error:${tty_reset} eggdrop installation failed.  Please check logs and try again.  Delete the ${tty_bold}${EGGDROP_DIR}${tty_reset} directory to allow retry."
        echo
        abort
    fi
    echo
    ask_for_botname
    install_armour
    configure_eggdrop
}

# -- get the name of the bot
ask_for_botname() {
    local input
    ohai "What is the name of your bot?"
    echo
    read input
    BOTNAME=${input}
    if [ "${BOTNAME}" == "" ]; then
        ask_for_botname
    fi
    ARMOUR_INSTALL_DIR="${EGGDROP_INSTALL_DIR}/armour"
    if [ -f "${ARMOUR_INSTALL_DIR}/${BOTNAME}.conf" ]; then
        echo
        echo "${tty_red}Error:${tty_reset} Armour configuration file ${tty_green}${ARMOUR_INSTALL_DIR}/${BOTNAME}.conf${tty_reset} already exists.  Please choose another bot name."
        echo
        ask_for_botname
    fi
}

# -- ask for network to automate some settings
ask_for_network() {
    local input
    ohai "Which IRC network is this bot connecting to?"
    echo "        ${tty_green}1${tty_reset}: Undernet"
    echo "        ${tty_green}2${tty_reset}: DALnet"
    echo "        ${tty_green}3${tty_reset}: Other"
    echo
    getc input
    if [ "${input}" == '1' ]; then
        NETWORK="Undernet"
        IRCU=1
    elif [ "${input}" == '2' ]; then
        NETWORK="DALnet"
    elif [ "${input}" == '3' ]; then
        NETWORK="Other"
    else
        ring_bell
        warn "IRC network must be set.  Please try again."
        echo
        ask_for_network
    fi
    ohai "Set network to: ${tty_green}${NETWORK}${tty_reset}"
    echo
}

# -- setup eggdrop config file
configure_eggdrop() {
    cd ${EGGDROP_INSTALL_DIR}
    ohai "Configuring ${tty_bold}eggdrop${tty_reset} ..."
    echo
    ohai "Copying ${tty_green}armour/eggdrop.conf.sample${tty_reset} to ${tty_green}./${BOTNAME}.conf${tty_reset} ..."
    cp armour/eggdrop.conf.sample ./${BOTNAME}.conf
    echo
}

# -- clone Armour from GitHub
install_armour() {
    cd ${EGGDROP_INSTALL_DIR}
    if [ -d "armour" ]; then
        # -- armour directory already exists
        ring_bell
        echo
        echo "${tty_red}Error:${tty_reset} the directory ${tty_green}armour${tty_reset} already exists."
        local input
        echo
        ohai "Do you wish to ${tty_green}D${tty_reset})elete the directory, (${tty_green}B${tty_reset})ackup the directory, or (${tty_green}E${tty_reset})xit?"
        echo
        getc input
        if [ "${input}" == 'e' ]; then
            echo "${tty_red}Error:${tty_reset} Armour installation halted."
            echo
            abort
        elif [ "${input}" == 'd' ]; then
            rm -rf armour
        elif [ "${input}" == 'b' ]; then
            mv armour armour-old
            warn "Created backup of original ${tty_green}armour${tty_reset} directory to ${tty_green}armour-old${tty_reset}"
            echo
        else
            install_armour
        fi
    fi
    echo
    ohai "Cloning ${tty_green}Armour ${ARMOUR_VER}${tty_reset} from GitHub..."
    echo
    ${GIT} clone ${ARMOUR_GIT}
    echo
    cd armour
    ohai "Copying ${tty_green}armour/armour.conf.sample${tty_reset} to ${tty_green}armour/${BOTNAME}.conf${tty_reset} ..."
    echo
    cp armour.conf.sample ${BOTNAME}.conf
    configure_armour
}

# -- configure Armour *.conf settings
configure_armour() {
    ohai "Configuring settings in ${tty_green}armour/${BOTNAME}.conf${tty_reset} ..."
    echo
}


# -- describe Armour config settings
armour_setting() {
    # -- value validation
    BINARY=0
    NOEMPTY=0
    NUMERIC=0

    echo
    if [ $1 == "botname" ]; then
        NOEMPTY=1
        new_value="${BOTNAME}"
    else
        ohai "[${tty_blue}Setting${tty_reset}] ${tty_green}$setting_name${tty_reset}:"
    fi
    if [ $1 == "md5" ]; then
        echo "    The md5 utility on the machine for password hashing."
        echo "    Use md5 for ${tty_green}Linux${tty_reset} or ${tty_green}md5sum${tty_reset} for BSD machines"
        NOEMPTY=1
        
    elif [ $1 == "register" ]; then
        echo "    Allow users to register their own bot usernames using the ${tty_green}register${tty_reset} command? Enter ${tty_green}1${tty_reset} to enable or ${tty_green}0${tty_reset} to disable:"
        echo "    If the next ${tty_green}cfg(register:inchan)${tty_reset} setting includes channels, this command will only work for users inside the beloe channels."
        NOEMPTY=1
        BINARY=1

    elif [ $1 == "register:inchan" ]; then
        echo "    If the above ${tty_green}cfg(register)${tty_reset} setting is set to ${tty_green}1${tty_reset}, only users in this space delimited list of channels can use the ${tty_green}register${tty_reset} command."

    elif [ $1 == "ircd" ]; then
        echo "    The type of ircd used by servers on the IRC network this bot will connect to."
        echo "        ${tty_green}1${tty_reset}: ircu (Undernet/Quakenet)"
        echo "        ${tty_green}2${tty_reset}: DALnet/IRCnet/EFnet"
        NOEMPTY=1

    elif [ $1 == "znc" ]; then
        echo "    Does this bot connect to IRC using a znc bouncer? Enter ${tty_green}1${tty_reset} for yes, or ${tty_green}0${tty_reset} for no."
        echo "    This setting controls how the bot will change servers using the ${tty_green}jump${tty_reset} command."
        BINARY=1
        NOEMPTY=1

    elif [ $1 == "realname" ]; then
        echo "    The IRC realname that the bot will display in /WHOIS"

    elif [ $1 == "servicehost" ]; then
        echo "    The service host of network services such as X!cservice@undernet.org on Undernet"
        NOEMPTY=1

    elif [ $1 == "prefix" ]; then
        echo "    The character used to command the bot in channels."
        echo "    If, for example, the ${tty_green}prefix${tty_reset} was ${tty_green}c${tty_reset}, commands could be issued as: ${tty_green}c op MrBob${tty_reset}"
        echo "    ${tty_yellow}Tip${tty_reset}: do not use vowels for this command prefix as the bot could be too easily triggered inadvertently."
        NOEMPTY=1

    elif [ $1 == "chan:nocmd" ]; then
        echo "    Space delimited list of channels where the use of public commands is disallowed."

   elif [ $1 == "chan:def" ]; then
        echo "    The default channel applied with applicabkle commands that do not specify a channel and the command was typed in privmsg, or from an unregistered channel"
        echo "    Consider this as your primary registered bot channel."
        NOEMPTY=1

   elif [ $1 == "chan:report" ]; then
        echo "    Reporting & diagnostic channel for the bot to send command usage, errors, and other information."
        echo "    This channel is intended to be private and mostly useful to only the bot owner.  Leave unset if uninterested in this output."

    elif [ $1 == "auth:user" ]; then
        echo "    The network username (or nickname where NickServ exists) that the bot uses to authenticate with networks services." 
        echo "    Leave this value empty if the bot does not authenticate to network services."

    elif [ $1 == "auth:pass" ]; then
        echo "    If ${tty_green}cfg(auth:user)${tty_reset} is set, what password is used for the bot to authenticate with network services."
        NOEMPTY=1

    elif [ $1 == "auth:totp" ]; then
        echo "    If ${tty_green}cfg(auth:user)${tty_reset} is set, this setting holds the 2FA secret key for network accounts using TOTP."

    elif [ $1 == "auth:mech" ]; then
        echo "    If ${tty_green}cfg(auth:user)${tty_reset} is set, this setting specifies the mechanism to authenticate with network services,"
        echo "        ${tty_green}gnuworld${tty_reset}: GNUWorld services (such as X on Undernet)"
        echo "        ${tty_green}nickserv${tty_reset}: Networks that use nick registration with NickServ"
        NOEMPTY=1

    elif [ $1 == "auth:serv:nick" ]; then
        echo "    If ${tty_green}cfg(auth:user)${tty_reset} is set, this setting specifies the nickname of the service to authenticate to"
        echo "    e.g., ${tty_green}X${tty_reset} for Undernet or ${tty_green}NickServ${tty_reset} for a network such as DALnet"
        NOEMPTY=1
    
    elif [ $1 == "auth:serv:host" ]; then
        echo "    If ${tty_green}cfg(auth:user)${tty_reset} is set, this setting specifies the host of the {tty_green}cfg(auth:serv:nick)${tty_reset} service."
        echo "    e.g., ${tty_green}channels.undernet.org${tty_reset} for Undernet or ${tty_green}services.dal.net${tty_reset} DALnet"
        NOEMPTY=1
    
    elif [ $1 == "xhost:ext" ]; then
        echo "    The network username's hostname extension given to users with hidden hosts via the +x user mode."
        echo "    Only relevant when ${tty_green}cfg(auth:mech)${tty_reset} is set to ${tty_green}gnuworld${tty_reset}"
        echo "    e.g., Use ${tty_green}users.undernet.org${tty_reset} for Undernet"
        NOEMPTY=1
    
    elif [ $1 == "auth:hide" ]; then
        echo "    If ${tty_green}cfg(auth:mech)${tty_reset} is set to ${tty_green}gnuworld${tty_reset}, this setting defines whether or not to set usermode ${tty_green}+x${tty_reset} for host hiding."
        echo "        ${tty_green}1${tty_reset}: Enable host hiding"
        echo "        ${tty_green}0${tty_reset}: Disable host hiding"
        NOEMPTY=1
        BINARY=1

    elif [ $1 == "auth:rand" ]; then
        echo "    If ${tty_green}cfg(auth:user)${tty_reset} is set and this setting is enabled, the bot will use a random nickname until authenticated with network services."
        echo "        ${tty_green}1${tty_reset}: Enable"
        echo "        ${tty_green}0${tty_reset}: Disable"
        NOEMPTY=1
        BINARY=1
    
    elif [ $1 == "auth:wait" ]; then
        echo "    If ${tty_green}cfg(auth:user)${tty_reset} is set and this setting is enabled, the bot will wait to join channels until authenticated with network services."
        echo "        ${tty_green}1${tty_reset}: Enable"
        echo "        ${tty_green}0${tty_reset}: Disable"
        NOEMPTY=1
        BINARY=1
    
    elif [ $1 == "ban" ]; then
        echo "    The ban mechanism to use when setting bans (except when stacking modes during floodnet detection)"
        echo "        ${tty_green}chan${tty_reset}: Set bans through the server"
        echo "        ${tty_green}X${tty_reset}:    Set bans through the service bot defined in ${tty_green}cfg(auth:serv:nick)${tty_reset}"
        NOEMPTY=1
        NOEMPTY=1
    
    elif [ $1 == "portscan" ]; then
        echo "    Defines whether or not to enable the port scanner for configured matching clients and the ${tty_green}scanport${tty_reset} command."    
        echo "        ${tty_green}1${tty_reset}: Enable"
        echo "        ${tty_green}0${tty_reset}: Disable"
        NOEMPTY=1
        BINARY=1
    fi
    echo
}


ask_for_setting_value() {
    local setting_name
    local current_value 
    setting_name=$1
    current_value=$2
    read -p "    Enter new value for ${tty_green}$setting_name${tty_reset} (default value: ${tty_blue}$current_value${tty_reset}): " new_value </dev/tty
    echo

    if [[ "${NOEMPTY}" == "1" && "${new_value}" == "" ]]; then
        # -- empty value
        warn "Setting ${tty_green}$setting_name${tty_reset} must have a value."
        echo
        ask_for_setting_value "$setting_name" "$current_value"

    elif [[ "${BINARY}" == "1" && "${new_value}" != "0" && "${new_value}" != "1" ]]; then
        # -- not a binary value
        warn "Setting ${tty_green}$setting_name${tty_reset} must have a ${tty_green}binary${tty_reset} value (${tty_green}0${tty_reset} or ${tty_green}1${tty_reset})."
        echo
        ask_for_setting_value "$setting_name" "$current_value"

    elif [[ "${NUMERIC}" == "1" && ! "${new_value}" =~ ^[0-9]+$ ]]; then
        # -- not a number
        warn "Setting ${tty_green}$setting_name${tty_reset} must have a ${tty_green}numeric${tty_reset} value."
        echo
        ask_for_setting_value "$setting_name" "$current_value"
    fi
}


check_armour_settings() {

    SETTING_LIST="botname md5 register register:inchan ircd znc realname servicehost prefix chan:nocmd chan:def chan:report auth:user auth:pass auth:totp auth:mech auth:serv:nick auth:serv:host xhost:ext auth:hide auth:rand auth:wait ban portscan"
    NOAUTH=0
    REGISTER=0
    cd ${ARMOUR_INSTALL_DIR}
    ARMOUR_FILE="${BOTNAME}.conf"

    # -- read the config file
    while IFS= read -r line; do
        # -- check for line match on pattern: set cfg(name) "value"
        if [[ "$line" =~ ^set\ cfg\(([^\)]+)\)\ \"?([^\"]*)\"?$ ]]; then
            setting_name=$(echo "$line" | sed 's/.*cfg(\([^)]*\)).*/\1/')
            current_value=$(echo "$line" | sed 's/.*cfg([^)]*)[[:space:]]*"\([^"]*\)".*/\1/;s/.*cfg([^)]*)[[:space:]]*\([^"]*\).*/\1/')

            # -- ignore settings which are not required for basic deployments
            if [[ " $SETTING_LIST " != *" $setting_name "* ]]; then
                continue;
            fi

            # -- ignore cfg(register:inchan) if cfg(register) was not enabled
            if [[ "${setting_name}" == "register:inchan" && "${REGISTER}" == "0" ]]; then
                continue;
            fi

            # -- fallback to default value
            new_value="${current_value}"

            # -- set default values for Undernet
            UNDERNET_DEFAULTS="ircd servicehost auth:mech auth:serv:nick auth:serv:host xhost:ext"
            AUTH_SETTINGS="auth:pass auth:totp auth:mech auth:serv:nick auth:serv:host auth:hide auth:rand auth:wait"
            DALNET_SETTINGS="ircd servicehost auth:mech auth:serv:nick auth:serv:host xhost:ext auth:hide auth:rand auth:wait auth:totp"
            if [[ "${NETWORK}" == "Undernet" && " $UNDERNET_DEFAULTS " == *" $setting_name "* ]]; then
                # -- Undernet: use defaults
                ohai "Using default ${tty_green}Undernet${tty_reset} value for ${tty_green}$setting_name${tty_reset}: ${tty_blue}$current_value${tty_reset}"
                echo

            elif [[ "${NETWORK}" == "DALnet" && " $DALNET_SETTINGS " == *" $setting_name "* ]]; then
                # -- DALnet: setup specific auth settings
                if [ "${setting_name}" == "ircd" ]; then
                    new_value="2"
                    
                elif [ "${setting_name}" == "servicehost" ]; then
                    new_value="dal.net"
                    
                elif [ "${setting_name}" == "auth:mech" ]; then
                    new_value="nickserv"

                elif [ "${setting_name}" == "auth:serv:nick" ]; then
                    new_value="NickServ"

                elif [ "${setting_name}" == "auth:serv:host" ]; then
                    new_value="services.dal.net"

                elif [ "${setting_name}" == "xhost:ext" ]; then
                    new_value=""

                elif [ "${setting_name}" == "auth:hide" ]; then
                    new_value="0"
                
                elif [ "${setting_name}" == "auth:rand" ]; then
                    new_value="0"
                
                elif [ "${setting_name}" == "auth:wait" ]; then
                    new_value="0"

                elif [ "${setting_name}" == "auth:totp" ]; then
                    new_value="0"
                fi
                ohai "Using ${tty_green}DALnet${tty_reset} value for ${tty_green}$setting_name${tty_reset}: ${tty_blue}$new_value${tty_reset}"
                echo

            elif [ "${setting_name}" == "md5" ]; then
                ohai "Setting ${tty_green}md5${tty_reset} binary to: ${tty_green}${MD5}${tty_reset}"
                new_value="${MD5}"
                echo

            elif [[ "${NOAUTH}" == "1" && " ${AUTH_SETTINGS} " == *" $setting_name "* ]]; then
                ohai "Ignored setting: ${tty_green}${setting_name}${tty_reset}"
                echo

            elif [ "${setting_name}" == "botname" ]; then
                ohai "Setting ${tty_green}botname${tty_reset} to: ${tty_green}${BOTNAME}${tty_reset}"
                new_value="${BOTNAME}"
                echo

            else

                # -- describe the setting
                armour_setting "$setting_name"

                # -- request new config value
                ask_for_setting_value "$setting_name" "$current_value"

                if [[ "${setting_name}" == "ircd" && "${new_value}" == "1" ]]; then
                    IRCU=1
                fi

                if [[ "${setting_name}" == "register" && "${new_value}" == "1" ]]; then
                    REGISTER=1
                fi    

            fi

            if [[ "${setting_name}" == "auth:user" && "${new_value}" == "" ]]; then
                ohai "Service authentication disabled. Skipping additional auth related settings."
                echo
                NOAUTH=1
            fi

            # -- new setting line
            updated_line="set cfg($setting_name) \"$new_value\""
            ohai "[${tty_blue}Updated${tty_reset}] config line: ${tty_green}$updated_line${tty_reset}"
            echo
            
            # -- replace the line
            sed -i "s|^set cfg($setting_name) \".*\"$|$updated_line|" "$ARMOUR_FILE"

        fi
    done < "$ARMOUR_FILE"
}


# -- show the final remarks
show_success() {
    if [ ${NEW_EGGDROP} == true ]; then
        echo "    Armour is now ready to be loaded! Start your eggdrop:"
        echo
        echo "        ${tty_blue}./eggdrop ${BOTNAME}.conf${tty_reset}"
        echo
        echo "    From IRC, ensure you are added to eggdrop as owner, via: ${tty_green}/msg ${BOTNAME} hello${tty_reset}"
    else
        echo "    Armour is now ready to be loaded!"
    fi
    echo
    echo "    Be sure to check your Armour config file, reviewing settings, and loading plugins if desired:"
    echo
    echo "        Armour configuration file: ${tty_blue}./armour/${BOTNAME}.conf${tty_reset}"
    echo
    echo "    When ready, you can load Armour by adding the below line to the end of your eggdrop ${tty_green}${BOTNAME}.conf${tty_reset} file:"
    echo
    echo "        ${tty_blue}source ./armour/${BOTNAME}.conf${tty_reset}"
    echo
    echo "    Rehash the eggdrop to load Armour, and then initialise the script by creating yourself as the 500 level admin:"
    echo
    if [ "${IRCU}" == "1" ]; then
        echo "        ${tty_blue}/msg ${BOTNAME} inituser <botuser> <netuser>${tty_reset}"
        echo
        echo "        ... where ${tty_blue}<netuser>${tty_reset} is your network username"
    else
        echo "        ${tty_blue}/msg ${BOTNAME} inituser <botuser>${tty_reset}"
    fi
    echo
    echo 
    ohai "${tty_green}Support${tty_reset}"
    echo
    echo "    Support can be obtained by visiting ${tty_green}#armour${tty_reset} on ${tty_green}Undernet${tty_reset}, or emailing ${tty_blue}Empus${tty_reset} at ${tty_blue}empus@undernet.org${tty_reset}"
    echo
    echo "    When debugging issuesm it is helpful to show output from the eggdrop partyline (DCC), with debug levels enabled:"
    echo
    echo "        ${tty_blue}.console +1${tty_reset}"
    echo "        ${tty_blue}.console +2${tty_reset}"
    echo "        ${tty_blue}.console +3${tty_reset}"
    echo
    echo "    Documentation for Armour can be viewed @ ${tty_blue}https://armour.bot${tty_reset}"
    echo
    printf "    Enjoy! \xF0\x9F\x8D\xBA\n"
    echo
}

# -- check and install optional dependencies
optional_support() {   
    return_code=0 
    # -- ImageMagick
    local input
    ohai "Do you wish to use ${tty_green}ImageMagick${tty_reset} with the ${tty_green}openai${tty_reset} plugin to add text overlay to generated DALL-E images?"
    echo "    ${tty_green}Y${tty_reset}: Yes, install ImageMagick"
    echo "    ${tty_green}N${tty_reset}: No, do not install ImageMagick"
    echo
    getc input
    if [[ "${input}" == 'y' ]]; then
        ohai "Installing ${tty_green}ImageMagick${tty_reset} ..."
        if [[ "${SYSTEM}" != "macOS" ]]; then
            # -- use sudo
            ohai "sudo $PKGMGR $PKGMGR_ARGS $PKG_IMAGEMAGICK"
            sudo $PKGMGR $PKGMGR_ARGS $PKG_IMAGEMAGICK
            return_code=$?
        else
            # -- macOS: do not run brew via sudo
            ohai "$PKGMGR $PKGMGR_ARGS $PKG_IMAGEMAGICK"
            $PKGMGR $PKGMGR_ARGS $PKG_IMAGEMAGICK
            return_code=$?
        fi
    elif [[ "${input}" == 'n' ]]; then
        ohai "Not installing ${tty_green}ImageMagick${tty_reset} ..."
    else
        optional_support
    fi

    if [ ! $return_code -eq 0 ]; then
        echo
        echo "${tty_red}Error:${tty_reset} failed package install.  Please correct and try again."
        echo
        optional_support
    fi

    ohai "Done!"
    echo

    # -- oathtool
    if [ "${IRCU}" == "1" ]; then
        ohai "Do you wish to use ${tty_green}oathtool${tty_reset} to authenticate your bot with network services using 2FA (TOTP)?"
        echo "    ${tty_green}Y${tty_reset}: Yes, install oathtool"
        echo "    ${tty_green}N${tty_reset}: No, do not install oathtool"
        echo
        getc input
        if [[ "${input}" == 'y' ]]; then
            ohai "Installing ${tty_green}oathtool${tty_reset} ..."
            if [[ "${SYSTEM}" != "macOS" ]]; then
                # -- use sudo
                ohai "sudo $PKGMGR $PKGMGR_ARGS $PKG_OATHTOOL"
                sudo $PKGMGR $PKGMGR_ARGS $PKG_OATHTOOL
                return_code=$?
            else
                # -- macOS: do not run brew via sudo
                ohai "$PKGMGR $PKGMGR_ARGS $PKG_OATHTOOL"
                $PKGMGR $PKGMGR_ARGS $PKG_OATHTOOL
                return_code=$?
            fi
        elif [[ "${input}" == 'n' ]]; then
            ohai "Not installing ${tty_green}oathtool${tty_reset} ..."
        else
            optional_support
        fi

        if [ ! $return_code -eq 0 ]; then
            echo
            echo "${tty_red}Error:${tty_reset} failed package install.  Please correct and try again."
            echo
            optional_support
        fi

        ohai "Done!"
        echo
    fi
}


# -- add a new bot to existing Armour install
add_bot() {
    NEW_EGGDROP=false
    IRCU=0
    ohai "Adding a new ${tty_green}Armour ${ARMOUR_VER}${tty_reset} bot to ${tty_green}existing${tty_reset} installation"
    echo
    ask_for_eggdrop_dir
    ARMOUR_INSTALL_DIR="${EGGDROP_INSTALL_DIR}/armour"
    
    if [ ! -d $ARMOUR_INSTALL_DIR ]; then
        # -- Armour does not exist in this eggdrop install
        echo "${tty_red}Error:${tty_reset} Armour is not installed in this eggdrop directory.  Please install via:"
        echo
        echo "        ${tty_blue}./install.sh -i${tty_reset}"
        abort
    fi
    
    ohai "Using Armour install directory: ${tty_green}$ARMOUR_INSTALL_DIR${tty_reset}"
    echo
    ask_for_botname
    echo
    ohai "Copying ${tty_green}${ARMOUR_INSTALL_DIR}/armour.conf.sample${tty_reset} to ${tty_green}${ARMOUR_INSTALL_DIR}/${BOTNAME}.conf${tty_reset} ..."
    cp ${ARMOUR_INSTALL_DIR}/armour.conf.sample ${ARMOUR_INSTALL_DIR}/${BOTNAME}.conf 
    echo
    configure_eggdrop
    echo
    # -- ask for IRC network
    ask_for_network

    # -- ask for Armour setting values
    check_armour_settings

    # -- check for ImageMagick and oathtool
    optional_support

    # -- complete!
    echo
    echo
    ohai "${tty_green}Installation complete!${tty_reset}"
    echo
    show_success
    exit
}

# -- install bot
install_bot() {
    IRCU=0
    # -- begin!
    echo
    ohai "${tty_green}Armour ${ARMOUR_VER} Installation${tty_reset}"
    wait_for_user

    # -- display system type
    echo
    ohai "Detected ${tty_green}${SYSTEM}${tty_reset} system. Using ${tty_bold}${PKGMGR}${tty_reset} package manager"

    # -- manage prerequisites (ask and install)
    ask_for_prereq

    # -- check if prerequisites exist
    check_prereqs

    # -- ask if new or existing eggdrop install
    ask_for_eggdrop

    # -- ask for IRC network
    ask_for_network

    # -- ask for Armour setting values
    check_armour_settings

    # -- check for ImageMagick and oathtool
    optional_support

    # -- complete!
    echo
    echo
    ohai "${tty_green}Installation complete!${tty_reset}"
    echo
    show_success
    exit

}

# -- display usage
usage() {
    echo "Armour Installer"
    echo "Usage: ./install.sh [options]"
    echo "    -i              Install Armour (and optionally, eggdrop)"
    echo "    -a              Add a new bot to existing Armour install"
    echo "    -h, --help      Display this message"
    exit "${1:-0}"
}

# -- check usage
if [[ $# -gt 0 ]]; then
    case "$1" in
        -h | --help) usage ;;
        -i) install_bot ;;
        -a) add_bot ;;
        *)
            warn "Unrecognized option: '$1'"
            usage 1
        ;;
    esac
fi

# -- default action to run installer
install_bot