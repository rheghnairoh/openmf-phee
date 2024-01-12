#!/bin/bash

source ./scripts/logger.sh

function check_arch_ok {
    if [[ ! "$k8s_arch" == "x86_64" ]]; then
        log WARNING "This installation works properly with x86_64"
    fi
}

function check_resources_ok {
    # Get the total amount of installed RAM in GB
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    # Get the current free space on the root filesystem in GB
    free_space=$(df -BG ~ | awk '{print $4}' | tail -n 1 | sed 's/G//')

    # Check RAM
    if [[ "$total_ram" -lt "$MIN_RAM" ]]; then
        log WARNING "Installation detected RAM less than the minimum required"
        log WARNING "Minimum RAM required is $MIN_RAM GB. Please increase RAM"
        log ERROR "Proceeding... Unexpected results might occur !!!"
    fi
    # Check free space
    if [[ "$free_space" -lt "$MIN_FREE_SPACE" ]]; then
        log WARNING "Installation requires $MIN_FREE_SPACE GB free storage in $k8s_user home directory"
        log WARNING "Found $free_space GB free storage"
        log ERROR "Proceeding... Unexpected behaviour might occur !!!"
    fi
}

function set_linux_os_distro {
    LINUX_VERSION="Unknown"
    if [ -x "/usr/bin/lsb_release" ]; then
        LINUX_OS=$(lsb_release --d | perl -ne 'print  if s/^.*Ubuntu.*(\d+).(\d+).*$/Ubuntu/')
        LINUX_VERSION=$(/usr/bin/lsb_release --d | perl -ne 'print $&  if m/(\d+)/')
    else
        LINUX_OS="Untested"
    fi
    log INFO "Linux OS is [$LINUX_OS]"
}

function check_os_ok {
    log INFO "Checking OS distro"
    set_linux_os_distro
    n
    if [[ ! $LINUX_OS == "Ubuntu" ]]; then
        log WARNING "Untested OS distro detected. Installation requires Ubuntu OS"
        log ERROR "Proceeding... Unexpected behaviour might occur !!!"
    fi
}

function configure_microk8s {
    log INFO "Configure microK8s..."

    log DEBUG "Waiting microk8s to come online..."
    microk8s.status --wait-ready
    log DEBUG "Microk8s online, perform configurations."

    log INFO "Microk8s enable helm3..."
    microk8s.enable helm3

    log INFO "Microk8s enable dns..."
    microk8s.enable dns

    log INFO "Microk8s enable storage..."
    microk8s.enable hostpath-storage

    log INFO "Microk8s enable ingress..."
    microk8s.enable ingress

    log INFO "Adding kubectl and helm aliases"
    snap alias microk8s.kubectl kubectl
    snap alias microk8s.helm3 helm

    log INFO "Add $k8s_user user to microk8s group"
    sudo usermod -a -G microk8s $k8s_user

    # ensure .kube/config points to this new cluster and KUBECONFIG is not set in .bashrc
    log INFO "Setup kube config..."
    perl -p -i.bak -e 's/^.*KUBECONFIG.*$//g' $k8s_user_home/.bashrc
    perl -p -i.bak -e 's/^.*KUBECONFIG.*$//g' $k8s_user_home/.bash_profile
    # ensure k8s_user has clean .kube/config
    log INFO "Cleaning .kube/config files"
    mv $k8s_user_home/.kube $k8s_user_home/.kube.bak >>/dev/null 2>&1
    # setup .kube/config
    chown -f -R $k8s_user $k8s_user_home/.kube
    microk8s config >$k8s_user_home/.kube/config

    log OK "Microk8s configured"
}

function install_prerequisites {
    log DEBUG "Checking prerequisites..."

    if [[ $LINUX_OS == "Ubuntu" ]]; then
        # Check if Docker is installed
        if ! command -v docker &>/dev/null; then
            log ERROR "Docker is not installed. Please install and try again..."
            exit 1
        else
            log INFO "Docker installed..."
            # Add your user to the docker group (optional)
            log INFO "Adding current user ($USER) to the docker group"
            sudo usermod -aG docker $USER
        fi

        # Check if nc (netcat) is installed
        if ! command -v nc &>/dev/null; then
            log ERROR "nc (netcat) is not installed. Install and try again..."
            log DEBUG " sudo apt-get install -y netcat"
            exit 1
        else
            log INFO "nc (netcat) is installed."
        fi

        # Check if jq is installed
        if ! command -v jq &>/dev/null; then
            log ERROR "jq is not installed. Install and try again ..."
            log DEBUG " sudo apt-get -y install jq"
            exit 1
        else
            log INFO "jq is installed"
        fi

        # Check if make is installed
        if ! command -v make &>/dev/null; then
            log ERROR "make is not installed. Install and try again...(https://stedolan.github.io/jq/)"
            log DEBUG " sudo apt install -y make"
        else
            log INFO "make is installed."
        fi

        # Check if sed is installed
        if ! command -v sed &>/dev/null; then
            log ERROR "sed is not installed. Install and try again ..."
            log DEBUG " sudo apt-get -y install sed"
            exit 1
        else
            log INFO "sed is installed"
        fi

        # Check if microk8s is installed
        if ! command -v microk8s &>/dev/null; then
            log ERROR "MicroK8s is not installed. Please install and try again..."
            log DEBUG " sudo snap install microk8s --classic --channel=1.29"
            exit 1
        else
            log INFO "Microk8s installed..."
            # configure microk8s
            configure_microk8s
        fi
    else
        log WARNING "Untested OS - Make sure to install docker, kubectl, helm, netcat and jq"
        log ERROR "Proceeding... Unexpected behaviour might occur !!!"
    fi
}

function add_hosts {
    log INFO "Updating hosts file"
    ENDPOINTSLIST=(127.0.0.1 ml-api-adapter.local central-ledger.local account-lookup-service.local account-lookup-service-admin.local
        quoting-service.local central-settlement-service.local transaction-request-service.local central-settlement.local bulk-api-adapter.local
        moja-simulator.local sim-payerfsp.local sim-payeefsp.local sim-testfsp1.local sim-testfsp2.local sim-testfsp3.local sim-testfsp4.local
        mojaloop-simulators.local finance-portal.local operator-settlement.local settlement-management.local testing-toolkit.local
        testing-toolkit-specapi.local apachehost mongohost.local mongo-express.local vnextadmin elasticsearch.local redpanda-console.local
        fspiop.local bluebank.local greenbank.local bluebank-specapi.local greenbank-specapi.local)

    export ENDPOINTS=$(echo ${ENDPOINTSLIST[*]})

    # Check if perl is available for replacing
    if ! command -v perl &>/dev/null; then
        perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
    fi

    # TODO check the ping actually works > suggest cloud network rules if it doesn't
    #      also for cloud VMs might need to use something other than curl e.g. netcat ?
    # ping  -c 2 account-lookup-service-admin.local
}

function install_k8s_tools {
    log INFO "Recommendation - install kubernetes tools: kubens, kubectx and kustomize"
}

function add_helm_repos {
    # see readme at https://github.com/mojaloop/helm for required helm libs
    log INFO "Add the helm repositories"
    su - $k8s_user -c "helm repo add elastic https://helm.elastic.co" >/dev/null 2>&1
    su - $k8s_user -c "helm repo add codecentric https://codecentric.github.io/helm-charts" >/dev/null 2>&1 # keycloak for TTK
    su - $k8s_user -c "helm repo add bitnami https://charts.bitnami.com/bitnami" >/dev/null 2>&1
    su - $k8s_user -c "helm repo add mojaloop http://mojaloop.io/helm/repo/" >/dev/null 2>&1
    su - $k8s_user -c "helm repo add cowboysysop https://cowboysysop.github.io/charts/" >/dev/null 2>&1                 # mongo-express
    su - $k8s_user -c "helm repo add redpanda-data https://charts.redpanda.com/ " >/dev/null 2>&1                       # kafka console
    su - $k8s_user -c "helm repo add paymenthub https://fynarfin.io/images/ph-ee-engine-0.0.0-SNAPSHOT" >/dev/null 2>&1 # paymenthub

    log INFO "Updating helm repos..."
    su - $k8s_user -c "helm repo update" >/dev/null 2>&1

    log INFO "Helm repos added and updated."
}

function verify_user {
    log INFO "k8s user is $k8s_user"
    # ensure that the user for k8s exists
    if [ -z ${k8s_user+x} ]; then
        log ERROR "Installation user not set with the -u flag \nNote: The user must not be root."
        exit 1
    fi

    if [[ $(id -u $k8s_user >/dev/null 2>&1) == 0 ]]; then
        log ERROR "The user specified by -u should be a non-root user"
        exit 1
    fi

    if id -u "$k8s_user" >/dev/null 2>&1; then
        k8s_user_home=$(eval echo "~$k8s_user")
        return
    else
        log ERROR "The user [$k8s_user] does not exist. \nPlease try again and specify an existing user"
        exit 1
    fi
}

function check_k8s_installed {
    log INFO "Checking cluster is available and ready for kubectl"
    k8s_ready=$(su - $k8s_user -c "kubectl get nodes" | perl -ne 'print  if s/^.*Ready.*$/Ready/')
    if [[ ! "$k8s_ready" == "Ready" ]]; then
        log ERROR "Kubernetes is not installed , please run $0 -m install -u $k8s_user before trying this installation"
        exit 1
    fi
    log OK "Kubernetes installed and ready..."
}

function print_end_message {
    echo -e "\n${GREEN}============================"
    echo -e "Installation complete"
    echo -e "============================${RESET}\n"
}

function uninstall_setup {
    log DEBUG "Rolling back environment setup..."
    log INFO "Packages added externally require manual uninstall: \n" \
        " - docker : sudo snap remove docker \n" \
        " - microk8s : sudo snap remove microk8s \n" \
        " - netcat : sudo apt-get remove netcat \n" \
        " - sed : sudo apt-get remove sed \n" \
        " - jq : sudo apt-get remove jq \n"

    log INFO "Removing $k8s_user from microk8s group"
    sudo gpasswd -d $USER microk8s
    log INFO "Removing $k8s_user from docker group"
    sudo gpasswd -d $USER docker

    log INFO "Restoring kube config"
    mv $k8s_user_home/.kube.bak $k8s_user_home/.kube >>/dev/null 2>&1

    log INFO "Restoring .bashrc and .bash_profile"
    mv $k8s_user_home/.bashrc.bak $k8s_user_home/.bashrc >>/dev/null 2>&1
    mv $k8s_user_home/.bash_profile.bak $k8s_user_home/.bash_profile >>/dev/null 2>&1

    log INFO "Restoring hosts file"
    mv /etc/hosts.bak /etc/hosts >>/dev/null 2>&1

    log INFO "If installed, kubens, kubectx and kustomize can be safely removed"

    log INFO "Removing helm repos."
    su - $k8s_user -c "helm repo remove elastic" >/dev/null 2>&1
    su - $k8s_user -c "helm repo remove codecentric" >/dev/null 2>&1
    su - $k8s_user -c "helm repo remove bitnami" >/dev/null 2>&1
    su - $k8s_user -c "helm repo remove mojaloop" >/dev/null 2>&1
    su - $k8s_user -c "helm repo remove cowboysysop" >/dev/null 2>&1
    su - $k8s_user -c "helm repo remove redpanda-data" >/dev/null 2>&1
    su - $k8s_user -c "helm repo remove paymenthub" >/dev/null 2>&1
    su - $k8s_user -c "helm repo update" >/dev/null 2>&1

    log DEBUG "Rollback environment setup completed."
}

function setup_env {

    k8s_distro="$1"
    k8s_user_home=""
    k8s_arch=$(uname -p) # what arch
    # Set the minimum amount of RAM in GB
    MIN_RAM=16
    MIN_FREE_SPACE=30

    # ensure we are running as root
    if [ "$EUID" -ne 0 ]; then
        log ERROR "Please run as root"
        exit 1
    fi

    check_arch_ok
    verify_user

    check_resources_ok
    check_os_ok
    install_prerequisites
    add_hosts
    install_k8s_tools
    add_helm_repos
    check_k8s_installed
    log OK "Kubernetes distro:[$k8s_distro] is now configured for user [$k8s_user] and ready for deployment"
}
