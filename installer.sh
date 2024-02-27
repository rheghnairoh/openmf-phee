#!/usr/bin/env bash
# installer.sh : Installer Utility
# Author:  Honest Chirozva
# Date :   February 2024

source ./scripts/config_env.sh
source ./scripts/deployer.sh

welcome() {
    log " \n"
    log "===================================================="
    log "       Payment Hub EE x Mojaloop Installer          "
    log "===================================================="
    log " \n"
}

showUsage() {
    if [ $# -ne 0 ]; then
        echo "Incorrect number of arguments passed to $0"
        exit 1
    else
        echo "USAGE: $0 -u [user]
Options:
  -h|H                              : Display this help message
  -u user                           : installation user (-u user is required)
  install [paymenthub|mojaloop]     : Install paymenthub|mojaloop. Install full stack if none specified.
  update [paymenthub|mojaloop]      : Update paymenthub|mojaloop. Update all if none specified.
  uninstall [paymenthub|mojaloop]   : Uninstall paymenthub|mojaloop. Uninstall everything if none specified.
  postinstall [paymenthub|mojaloop]   : Run post install tasks for [paymenthub|mojaloop].

EXAMPLES: 
    sudo $0 -u $USER install                                # Install full stack.
    sudo $0 -u $USER install paymenthub                     # Install paymenthub stack
    sudo $0 -u $USER install mojaloop                       # Install mojaloop stack
    sudo $0 -u $USER update                                 # Update all
    sudo $0 -u $USER update [paymenthub|mojaloop|infra]     # Update paymenthub|mojaloop|infra
    sudo $0 -u $USER uninstall                              # Uninstall everything
    sudo $0 -u $USER uninstall [paymenthub|mojaloop]        # uninstall paymenthub|mojaloop
    sudo $0 -u $USER postinstall [paymenthub|mojaloop]      # Perform post install tasks for paymenthub|mojaloop
                **** Argument -u [user] is required ****
"
    fi

}

getoptions() {
    while getopts "u:hH" OPTION; do
        case "${OPTION}" in
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

    if [ -z "$k8s_user" ]; then
        showUsage
        echo "USER MISSING"
        exit 1
    fi
}

# this is also called when Ctrl-C is sent
uninstall() {
    log WARNING "Performing graceful uninstall"
    uninstall_apps
    uninstall_setup

    # exit shell script with error code 2
    # if omitted, shell script will continue execution
    exit 2
}

trapCtrlC {
    log ERROR "Ctrl-C detected. Terminating installation..."
    uninstall
}

# initialise trap to call trap_ctrlc function
# when signal 2 (SIGINT) is received
trap "trapCtrlC" 2

###########################################################################
# MAIN
###########################################################################
main() {
    # set env vars
    k8s_distro="${K8S_DISTRO:-microk8s}"
    k8s_user_home=""
    k8s_arch=$(uname -p) # what arch
    MIN_RAM=30
    MIN_FREE_SPACE=60
    DEFAULT_HELM_TIMEOUT_SECS="1200s" # default timeout for deplying helm chart
    TIMEOUT_SECS=$DEFAULT_HELM_TIMEOUT_SECS
    EXTERNAL_ENDPOINTS_LIST=("mongoexpress.local" "vnextadmin.local" "elasticsearch.local" "kibana.local"
        "kafkaconsole.local" "fspiop.local" "bluebank.local" "greenbank.local")

    welcome
    getoptions "$@"
    mode="${@:$OPTIND:1}"
    application="${@:$OPTIND+1:1}"

    apply_preinstall_env_vars

    if [ $mode == "install" ]; then
        echo -e "${YELLOW}"
        echo -e "===================================================================="
        echo -e "This deployment is meant for demo purposes and not for production"
        echo -e "===================================================================="
        echo -e "${RESET}"

        setup_env "$k8s_distro"

        if [[ $application == "paymenthub" ]]; then
            deploy_paymenthub
        elif [[ $application == "mojaloop" ]]; then
            deploy_infrastructure
            deploy_mojaloop
        else
            deploy_apps
        fi
    elif [ $mode == "update" ]; then
        if [[ $application == "paymenthub" ]]; then
            update_paymenthub
        elif [[ $application == "mojaloop" ]]; then
            update_mojaloop
        elif [[ $application == "infra" ]]; then
            update_infrastructure
        else
            update_apps
        fi
    elif [ $mode == "uninstall" ]; then
        if [[ $application == "paymenthub" ]]; then
            uninstall_paymenthub
        elif [[ $application == "mojaloop" ]]; then
            uninstall_mojaloop
        else
            uninstall
        fi
    elif [ $mode == "postinstall" ]; then
        if [[ $application == "paymenthub" ]]; then
            log DEBUG "Running paymenthub post install (might take a while)..."
            post_paymenthub_deployment_script
        elif [[ $application == "mojaloop" ]]; then
            log DEBUG "Running mojaloop post install (might take a while)..."
            infra_restore_mongo_demo_data
            mojaloop_postinstall_setup_ttk
        else
            log DEBUG "Running post install tasks (might take a while)..."
            post_paymenthub_deployment_script
            infra_restore_mongo_demo_data
            mojaloop_postinstall_setup_ttk
        fi
    else
        showUsage
    fi
}

###########################################################################
# CALL TO MAIN
###########################################################################
main "$@"
