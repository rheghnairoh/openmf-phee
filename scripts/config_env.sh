#!/usr/bin/env bash
# config_env.sh : Configure environment for installation
# Author:  Honest Chirozva
# Date :   February 2024

source ./apps/env.sh
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
    if [[ ! $LINUX_OS == "Ubuntu" ]]; then
        log WARNING "Untested OS distro detected. Installation requires Ubuntu OS"
        log ERROR "Proceeding... Unexpected behaviour might occur !!!"
    fi
}

function do_k3s_install {
    log INFO "===================================================================="
    log INFO " Installing Kubernetes k3s engine and tools (helm/ingress etc)"
    log INFO "===================================================================="
    # ensure k8s_user has clean .kube/config
    rm -rf $k8s_user_home/.kube >>/dev/null 2>&1
    log INFO "Installing k3s "

    K8S_VERSION="1.28"
    HELM_VERSION="3.12.0"

    curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
        INSTALL_K3S_CHANNEL="v$K8S_VERSION" \
        INSTALL_K3S_EXEC=" --disable traefik " sh >/dev/null 2>&1

    # check k3s installed ok
    status=$(k3s check-config 2>/dev/null | grep "^STATUS" | awk '{print $2}')
    if [[ "$status" -eq "pass" ]]; then
        log INFO "  [ok] check-config reporting status of pass"
    else
        log ERROR "** Error : k3s check-config not reporting status of pass   **"
        log ERROR "   run k3s check-config manually as user [$k8s_user] for more information   **"
        exit 1
    fi

    # configure user environment to communicate with k3s kubernetes
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    cp /etc/rancher/k3s/k3s.yaml $k8s_user_home/k3s.yaml
    chown $k8s_user $k8s_user_home/k3s.yaml
    chmod 600 $k8s_user_home/k3s.yaml

    perl -p -i.bak -e 's/^.*KUBECONFIG.*$//g' $k8s_user_home/.bashrc
    echo "export KUBECONFIG=\$HOME/k3s.yaml" >>$k8s_user_home/.bashrc
    perl -p -i.bak -e 's/^.*source .bashrc.*$//g' $k8s_user_home/.bash_profile
    perl -p -i.bak2 -e 's/^.*export KUBECONFIG.*$//g' $k8s_user_home/.bash_profile
    echo "source .bashrc" >>$k8s_user_home/.bash_profile
    echo "export KUBECONFIG=\$HOME/k3s.yaml" >>$k8s_user_home/.bash_profile

    # install helm
    log INFO "Installing helm "
    helm_arch_str=""
    if [[ "$k8s_arch" == "x86_64" ]]; then
        helm_arch_str="amd64"
    elif [[ "$k8s_arch" == "aarch64" ]] || [[ "$k8s_arch" == "arm64" ]]; then
        helm_arch_str="arm64"
    else
        log ERROR "** Error:  architecture not recognised as x86_64 or arm64  ** \n"
        exit 1
    fi
    rm -rf /tmp/linux-$helm_arch_str /tmp/helm.tar
    curl -L -s -o /tmp/helm.tar.gz https://get.helm.sh/helm-v$HELM_VERSION-linux-$helm_arch_str.tar.gz
    gzip -d /tmp/helm.tar.gz
    tar xf /tmp/helm.tar -C /tmp
    mv /tmp/linux-$helm_arch_str/helm /usr/local/bin
    rm -rf /tmp/linux-$helm_arch_str
    /usr/local/bin/helm version >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        log INFO "  helm ok."
    else
        log ERROR "** Error : helm install seems to have failed **"
        exit 1
    fi

    #install nginx
    log INFO "Installing nginx ingress chart and wait for it to be ready"
    su - $k8s_user -c "helm install --wait --timeout 300s ingress-nginx ingress-nginx \
                      --repo https://kubernetes.github.io/ingress-nginx \
                      -f $MOJALOOP_DIR/packages/installer/manifests/infra/nginx-values.yaml" >/dev/null 2>&1
    # TODO : check to ensure that the ingress is indeed running
    nginx_pod_name=$(kubectl get pods | grep nginx | awk '{print $1}')

    if [ -z "$nginx_pod_name" ]; then
        log ERROR "** Error : helm install of nginx seems to have failed , no nginx pod found **"
        exit 1
    fi
    # Check if the Nginx pod is running
    if kubectl get pods $nginx_pod_name | grep -q "Running"; then
        log INFO "Nginx running..."
    else
        log ERROR "** Error : helm install of nginx seems to have failed , nginx pod is not running  **"
        exit 1
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

    log INFO "Microk8s enable dashboard..."
    microk8s.enable dashboard

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
    chown -f -R $k8s_user $k8s_user_home/.kube >>/dev/null 2>&1
    microk8s config >$k8s_user_home/.kube/config

    log DEBUG "Reload group changes by running newgrp microk8s"

    log OK "Microk8s configuration complete"
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
            log INFO "Adding current user ($k8s_user) to the docker group"
            sudo groupadd docker
            sudo usermod -aG docker $k8s_user
            log DEBUG "Reload group changes by running newgrp docker"
            # newgrp docker
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

        # Check if envsubst is installed
        if ! command -v envsubst &>/dev/null; then
            log ERROR "envsubst  is not installed. Install and try again ..."
            log DEBUG " sudo apt-get -y install gettext "
            exit 1
        else
            log INFO "envsubst is installed"
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
    ENDPOINTSLIST=(127.0.0.1
        mongohost.local mongoexpress.local vnextadmin.local elasticsearch.local kafkaconsole.local fspiop.local
        bluebank.local greenbank.local)

    export ENDPOINTS=$(echo ${ENDPOINTSLIST[*]})

    # Check if perl is available for replacing
    if ! command -v perl &>/dev/null; then
        perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
    fi

    # TODO check the ping actually works > suggest cloud network rules if it doesn't
    #      also for cloud VMs might need to use something other than curl e.g. netcat ?
    # ping  -c 2 account-lookup-service-admin.local
    ping -c 2 vnextadmin
}

function install_k8s_tools {
    # Check if kubens is installed
    if ! command -v kubens &>/dev/null; then
        log DEBUG "Installing kubernetes tools: kubens and kustomize\n" \
            "   - https://github.com/ahmetb/kubectx"
        sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx >>/dev/null 2>&1
        sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
        sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
    else
        log INFO "Kubens, kubectx is installed."
    fi
}

function add_helm_repos {
    # see readme at https://github.com/mojaloop/helm for required helm libs
    log INFO "Add the helm repositories"
    su - $k8s_user -c "helm repo add kiwigrid https://kiwigrid.github.io" >/dev/null 2>&1
    su - $k8s_user -c "helm repo add kokuwa https://kokuwaio.github.io/helm-charts" >/dev/null 2>&1 #fluentd
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
    log WARNING "Rolling back environment setup..."
    log INFO "Packages added externally require manual uninstall: \n" \
        " - docker : sudo snap remove docker \n" \
        " - microk8s : sudo snap remove microk8s \n" \
        " - netcat : sudo apt-get remove netcat \n" \
        " - sed : sudo apt-get remove sed \n" \
        " - jq : sudo apt-get remove jq \n"

    log DEBUG "Manually remove $k8s_user from microk8s group if needed\n" \
        " sudo gpasswd -d $k8s_user microk8s"
    log DEBUG "Manually remove $k8s_user from docker group if needed\n" \
        " sudo gpasswd -d $k8s_user docker"

    log INFO "Restoring kube config"
    mv $k8s_user_home/.kube.bak $k8s_user_home/.kube >>/dev/null 2>&1

    log INFO "Restoring .bashrc and .bash_profile"
    mv $k8s_user_home/.bashrc.bak $k8s_user_home/.bashrc >>/dev/null 2>&1
    mv $k8s_user_home/.bash_profile.bak $k8s_user_home/.bash_profile >>/dev/null 2>&1

    log INFO "Restoring hosts file"
    sudo mv /etc/hosts.bak /etc/hosts >>/dev/null 2>&1

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

    log WARNING "Rollback environment setup completed."
}

function apply_config_env_vars {
    log DEBUG "Substituting env variables in config files"
    for file_name in $(find $APPS_DIR/config -type f); do
        sudo envsubst < $file_name
    done
}

function setup_env {

    k8s_distro="$1"
    k8s_user_home=""
    k8s_arch=$(uname -p) # what arch
    # Set the minimum amount of RAM in GB
    MIN_RAM=30
    MIN_FREE_SPACE=60

    DEFAULT_HELM_TIMEOUT_SECS="1200s" # default timeout for deplying helm chart
    TIMEOUT_SECS=$DEFAULT_HELM_TIMEOUT_SECS

    EXTERNAL_ENDPOINTS_LIST=("mongoexpress.local" "vnextadmin.local" "elasticsearch.local" "kibana.local"
        "kafkaconsole.local" "fspiop.local" "bluebank.local" "greenbank.local")

    # ensure we are running as root
    if [ "$EUID" -ne 0 ]; then
        log ERROR "Please run as root"
        exit 1
    fi

    # make tmp dir
    if [ ! -d "$DEPLOY_DIR" ]; then
        mkdir -p "$DEPLOY_DIR"
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
