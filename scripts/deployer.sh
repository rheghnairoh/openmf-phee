#!/bin/bash

source ./apps/env.sh
source ./scripts/logger.sh
source ./scripts/helper.sh

function deploy_infrastructure() {
    log DEBUG "Deploying infrastructure..."
    create_namespace $INFRA_NAMESPACE
    deploy_helm_chart_from_dir "./apps/infra/" "$INFRA_NAMESPACE" "$INFRA_RELEASE_NAME"
    log OK "============================"
    log OK "Infrastructure deployed."
    log OK "============================"
}

function apply_kube_manifests() {
    if [ "$#" -ne 2 ]; then
        log ERROR "Usage: apply_kube_manifests <directory> <namespace>"
        return 1
    fi

    local directory="$1"
    local namespace="$2"

    # Check if the directory exists.
    if [ ! -d "$directory" ]; then
        log ERROR "Directory '$directory' not found."
        return 1
    fi

    # Use 'kubectl apply' to apply manifests in the specified directory.
    kubectl apply -f "$directory" -n "$namespace" >>/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log INFO "Kubernetes manifests applied successfully."
    else
        log ERROR "Failed to apply Kubernetes manifests."
    fi
}

function run_failed_sql_statements() {
    log INFO "Fixing Operations App MySQL Race condition"
    operationsDeplName=$(kubectl get deploy --no-headers -o custom-columns=":metadata.name" -n $PH_NAMESPACE | grep operations-app)
    # kubectl exec -it mysql-0 -n infra -- mysql -h mysql -uroot -pethieTieCh8ahv < apps/config/db_setup.sql
    mysql -uroot -proot <apps/config/db_setup.sql

    if [ $? -eq 0 ]; then
        log INFO "SQL File execution successful"
    else
        log ERROR "SQL File execution failed"
        return 1
    fi

    log INFO "Restarting Deployment for Operations App"
    kubectl rollout restart deploy/$operationsDeplName -n $PH_NAMESPACE

    if [ $? -eq 0 ]; then
        log INFO "Deployment Restart successful"
    else
        log ERROR "Deployment Restart failed"
        return 1
    fi
}

#Function to run kong migrations in Kong init container
function run_kong_migrations() {
    log DEBUG "Fixing Kong Migrations"
    #StoreKongPods
    kongPods=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" -n $PH_NAMESPACE | grep g2p-sandbox-kong)
    dBcontainerName="wait-for-db"
    for pod in $kongPods; do
        podName=$(kubectl get pod $pod --no-headers -o custom-columns=":metadata.labels.app" -n $PH_NAMESPACE)
        if [[ "$podName" == "g2p-sandbox-kong" ]]; then
            initContainerStatus=$(kubectl get pod $pod --no-headers -o custom-columns=":status.initContainerStatuses[0].ready" -n $PH_NAMESPACE)
            while [[ "$initContainerStatus" != "true" ]]; do
                log INFO "Ready State: $initContainerStatus Waiting for status to become true ..."
                initContainerStatus=$(kubectl get pod $pod --no-headers -o custom-columns=":status.initContainerStatuses[0].ready" -n $PH_NAMESPACE)
                sleep 5
            done
            log INFO "Status is now true"
            while kubectl get pod "$podName" -o jsonpath="{:status.initContainersStatuses[1].name}" | grep -q "$dBcontainerName"; do
                log INFO "Waiting for Init DB container to be created ..."
                sleep 5
            done

            echo && echo $pod
            statusCode=1
            while [ $statusCode -eq 1 ]; do
                log INFO "Running Migrations ..."
                kubectl exec $pod -c $dBcontainerName -n $PH_NAMESPACE -- kong migrations bootstrap >>/dev/null 2>&1
                statusCode=$?
                if [ $statusCode -eq 0 ]; then
                    log INFO "Kong Migrations Successful"
                fi
            done
        else
            continue
        fi
    done
}

function post_paymenthub_deployment_script() {
    #Run migrations in Kong Pod
    run_kong_migrations
    # Run failed MySQL statements.
    run_failed_sql_statements
}

function configure_mojaloop() {
    log DEBUG "Configuring Mojaloop Manifests"
    local json_file=$MOJALOOP_VALUES_FILE

    # Check if jq is installed, if not, exit with an error message
    if ! command -v jq &>/dev/null; then
        log ERROR "'jq' is not installed. Please install it (https://stedolan.github.io/jq/)."
        exit 1
    fi

    # Check if the JSON file exists
    if [ ! -f "$json_file" ]; then
        log ERROR "JSON file '$json_file' does not exist."
        return 1
    fi

    # Loop over JSON objects in the file and call the process_json_object function
    jq -c '.[]' "$json_file" | while read -r json_object; do
        local file_name
        local old_value
        local new_value

        # Extract attributes from the JSON object
        file_name=$(echo "$json_object" | jq -r '.file_name')
        old_value=$(echo "$json_object" | jq -r '.old_value')
        new_value=$(echo "$json_object" | jq -r ".new_value")

        # Call the  function with the extracted attributes
        replace_values_in_file "$file_name" "$old_value" "$new_value"
    done

    if [ $? -eq 0 ]; then
        log INFO "Mojaloop Manifests edited successfully"
    else
        log ERROR "Could not edit Mojaloop Manifests."
    fi
}

function deploy_mojaloop() {
    log DEBUG "Deploying Mojaloop application manifests"
    create_namespace "$MOJALOOP_NAMESPACE"
    clone_repo "$MOJALOOPBRANCH" "$MOJALOOP_REPO_LINK" "$APPS_DIR" "$MOJALOOPREPO_DIR"
    rename_off_files_to_yaml "${MOJALOOP_LAYER_DIRS[0]}"
    configure_mojaloop

    for index in "${!MOJALOOP_LAYER_DIRS[@]}"; do
        folder="${MOJALOOP_LAYER_DIRS[index]}"
        log INFO "Deploying files in $folder"
        apply_kube_manifests "$folder" "$MOJALOOP_NAMESPACE"
        if [ "$index" -eq 0 ]; then
            log INFO "Waiting for Mojaloop to come up..."
            sleep 10
            log INFO "Proceeding ..."
        fi
    done

    log OK "============================"
    log OK "Mojaloop deployed."
    log OK "============================"
}

function configure_paymenthub() {
    local ph_chart_dir=$1
    local previous_dir="$PWD" # Save the current working directory
    log DEBUG "Configuring Payment Hub..."

    cd $ph_chart_dir || exit 1

    # Check if make is installed
    if ! command -v make &>/dev/null; then
        log ERROR "make is not installed. Please install it..."
        exit 1
    fi

    # create secrets for paymenthub namespace and infra namespace
    cd es-secret || exit 1
    log DEBUG "Creating elasticsearch secrets..."
    create_secret "$PH_NAMESPACE"
    # create_secret "$INFRA_NAMESPACE"
    cd ..
    cd kibana-secret || exit 1
    log DEBUG "Creating kibana secrets..."
    create_secret "$PH_NAMESPACE"
    # create_secret "$INFRA_NAMESPACE"
    
    # cd ..
    # kubectl create secret generic g2p-sandbox-redis --from-literal=redis-password="" -n "$PH_NAMESPACE"

    # check if the configuration was successful
    if [ $? -eq 0 ]; then
        log INFO "Paymenthub configuration successful."
    else
        log ERROR "Paymenthub configuration failed."
    fi

    # Return to the previous working directory
    cd "$previous_dir" || return 1
}

function deploy_paymenthub() {
    log DEBUG "Deploying PaymentHub EE"
    create_namespace "$PH_NAMESPACE"
    clone_repo "$PHBRANCH" "$PH_REPO_LINK" "$APPS_DIR" "$PHREPO_DIR"
    configure_paymenthub "$APPS_DIR/$PHREPO_DIR/helm"

    deploy_helm_chart_from_dir "$APPS_DIR/$PHREPO_DIR/helm/g2p-sandbox-fynarfin-SIT" "$PH_NAMESPACE" "$PH_RELEASE_NAME" "$PH_VALUES_FILE"

    log DEBUG "Fixing paymenthub post deployment issues(might take a while)..."
    post_paymenthub_deployment_script >>/dev/null 2>&1

    log OK "============================"
    log OK "Paymenthub deployed."
    log OK "============================"
}

function update_phee (){
    deploy_helm_chart_from_dir "$APPS_DIR/$PHREPO_DIR/helm/g2p-sandbox-fynarfin-SIT" "$PH_NAMESPACE" "$PH_RELEASE_NAME" "$PH_VALUES_FILE"
}

function uninstall_deployments {
    log WARNING "Uninstalling deployments..."

    log INFO "Uninstalling infrastructure..."
    su - $k8s_user -c "helm uninstall $INFRA_RELEASE_NAME -n $INFRA_NAMESPACE "
    su - $k8s_user -c "kubectl delete namespace $INFRA_NAMESPACE"

    log INFO "Uninstalling paymenthub ..."
    su - $k8s_user -c "helm uninstall $PH_RELEASE_NAME -n $PH_NAMESPACE"
    su - $k8s_user -c "kubectl delete namespace $PH_NAMESPACE"

    log INFO "Uninstalling mojaloop..."
    su - $k8s_user -c "kubectl delete namespace $MOJALOOP_NAMESPACE"

    log WARNING "Deployments uninstalled."
}

function print_end_message {
    log "==========================="
    log "INSTALLATION COMPLETED"
    log "===========================\n"

    log "Monitor pods using kubectl"
    log "kubectl get pods -n infra # Infrastructure"
    log "kubectl get pods -n mojaloop # Mojaloop"
    log "kubectl get pods -n paymenthub # Paymenthub"
}

function deploy_apps {
    log DEBUG "Deploying applications ..."
    deploy_paymenthub
    deploy_infrastructure
    deploy_mojaloop
    print_end_message
}
