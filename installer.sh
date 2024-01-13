#!/bin/bash

source ./scripts/config_env.sh
source ./scripts/deployer.sh

function welcome {
    log " \n"
    log "===================================================="
    log "       Payment Hub EE x Mojaloop Installer          "
    log "===================================================="
    log " \n"
}

function showUsage {
    if [ $# -ne 0 ]; then
        echo "Incorrect number of arguments passed to function $0"
        exit 1
    else
        echo "USAGE: $0 -m [mode]
Options:
  -m mode ............... install|uninstall (-m is required)
  -u user................ user attached to the installation
  -h|H .................. display this message

Example 1 : sudo $0  -m install -u $USER # Install
Example 2 : sudo $0  -m uninstall -u $USER # Uninstall everything
Example 2 : sudo $0  -m update -u $USER # Update current installation
    **** Argument -m [mode] is required****
"
    fi

}

function getoptions {
    local mode_opt

    while getopts "m:u:hH" OPTION; do
        case "${OPTION}" in
        m)
            mode_opt="${OPTARG}"
            ;;
        u)
            k8s_user="${OPTARG}"
            ;;
        h | H)
            showUsage
            exit 0
            ;;
        *)
            log ERROR "Unknown option"
            showUsage
            exit 1
            ;;
        esac
    done

    if [ -z "$mode_opt" ]; then
        showUsage
        exit 1
    fi

    mode="$mode_opt"
}

# this function is also called when Ctrl-C is sent
function uninstall() {
    log WARNING "Performing graceful uninstall..."
    uninstall_deployments
    uninstall_setup

    # exit shell script with error code 2
    # if omitted, shell script will continue execution
    exit 2
}

function trapCtrlC {
    log ERROR "Ctrl-C detected. Terminating installation..."
    uninstall
}

# initialise trap to call trap_ctrlc function
# when signal 2 (SIGINT) is received
trap "trapCtrlC" 2

###########################################################################
# MAIN
###########################################################################
function main {
    # set env vars
    k8s_distro="${K8S_DISTRO:-microk8s}"

    welcome
    getoptions "$@"
    if [ $mode == "install" ]; then
        echo -e "${YELLOW}"
        echo -e "===================================================================="
        echo -e "This deployment is meant for demo purposes and not for production"
        echo -e "===================================================================="
        echo -e "${RESET}"
        setup_env "$k8s_distro"
        deploy_apps
    elif [ $mode == "uninstall" ]; then
        uninstall
    elif [ $mode == "update" ]; then
        update_phee
    else
        showUsage
    fi
}

###########################################################################
# CALL TO MAIN
###########################################################################
main "$@"
