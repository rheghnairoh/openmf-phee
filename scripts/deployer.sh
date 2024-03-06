#!/usr/bin/env bash
# deployer.sh : Deploy apps
# Author:  Honest Chirozva
# Date :   February 2024

source ./apps/env.sh
source ./scripts/logger.sh
source ./scripts/helper.sh

predeploy_app_apply_env() {
    if [ "$#" -ne 1 ]; then
        log ERROR "Usage: predeploy_app_apply_env <deploy_dir> "
        return 1
    fi

    local app_name="$1"
    local app_dir="$DEPLOY_DIR/$app_name"
    local temp_dir="${app_dir}_temp"

    log DEBUG "Substituting env variables in $app_dir"
    set -a
    source $APPS_DIR/env.sh
    set +a

    # create temp app dir
    cp -r "$app_dir" "$temp_dir"

    local file_name
    for file_path in $(find $temp_dir -type f); do
        file_name=$(basename ${file_path})
        log INFO "Apply env to $file_name"
        envsubst <$file_path >$app_dir/$file_name
    done

    # clean up
    rm -rf "$temp_dir"
}

# ===== INFRA =====
infra_restore_mongo_demo_data() {
    local mongo_data_dir=$MOJALOOP_REPO_MONGO_DIR
    log INFO "Restoring mongo data from directory $mongo_data_dir"

    local pod_status=$(kubectl get pods --namespace $INFRA_NAMESPACE | grep -i mongodb | awk '{print $3}')
    while [[ "$pod_status" != "Running" ]]; do
        log INFO "MongoDB seems not running...waiting for pods to come up."
        sleep 5
        pod_status=$(kubectl get pods --namespace $INFRA_NAMESPACE | grep -i mongodb | awk '{print $3}')
    done

    #   error_message=" restoring the mongo database data failed "
    #   trap 'handle_warning $LINENO "$error_message"' ERR
    log INFO "Restoring demonstration/test data and ttk configs"
    # temporary measure to inject base participants data into switch
    local mongopod=$(kubectl get pods --namespace $INFRA_NAMESPACE | grep -i mongodb | awk '{print $1}')
    # local mongo_root_pw=$(kubectl get secret mongodb -n $INFRA_NAMESPACE -o jsonpath='{.data.MONGO_INITDB_ROOT_PASSWORD}' | base64 -d)
    local mongo_root_pw=$(kubectl get secret mongodb -n $INFRA_NAMESPACE -o jsonpath='{.data.mongodb-root-password}' | base64 -d)
    #kubectl cp $mongo_data_dir/mongodata.gz $mongopod:/tmp >/dev/null 2>&1 # copy the demo / test data into the mongodb pod
    log INFO "$mongo_data_dir/mongodump-beta.gz"
    kubectl cp $mongo_data_dir/mongodump-beta.gz $mongopod:/tmp/mongodump.gz >/dev/null 2>&1 # copy the demo / test data into the mongodb pod
    # drop existing collections
    # kubectl exec --stdin --tty $mongopod -- mongosh  -u root -p $mongo_root_pw  --eval "use accounts_and_balances_bc_builtin_ledger" --eval  "db.dropDatabase()"
    # kubectl exec --stdin --tty $mongopod -- mongosh -u root -p $mongo_root_pw --eval "use  accounts_and_balances_bc_coa"  --eval  "db.dropDatabase()"
    # kubectl exec --stdin --tty $mongopod -- mongosh -u root -p $mongo_root_pw --eval "use  participants"  --eval  "db.dropDatabase()"
    # kubectl exec --stdin --tty $mongopod -- mongosh -u root -p $mongo_root_pw --eval "use  security"  --eval  "db.dropDatabase()"

    # run the mongorestore
    kubectl exec --stdin --tty $mongopod -- mongorestore -u root -p $mongo_root_pw \
        --gzip --archive=/tmp/mongodump.gz --authenticationDatabase admin >/dev/null 2>&1
    log INFO "Restore demo data complete."
}

deploy_infrastructure() {
    log DEBUG "Deploying infrastructure..."
    create_namespace $INFRA_NAMESPACE

    # setup env values
    log INFO "Copy $INFRA_NAME app for deployment"
    copy_to_deploy_dir "$APPS_DIR/$INFRA_NAME" "$INFRA_NAME"
    predeploy_app_apply_env "$INFRA_NAME"

    helm_deploy_dir "$INFRA_HELM_DIR" "$INFRA_NAMESPACE" "$INFRA_RELEASE_NAME" "$INFRA_VALUES_FILE"
    
    log OK "============================"
    log OK "Infrastructure deployed."
    log OK "============================"
}

update_infrastructure() {
    log DEBUG "Updating infrastructure"
    # setup env values
    log INFO "Copy $INFRA_NAME app for deployment"
    copy_to_deploy_dir "$APPS_DIR/$INFRA_NAME" "$INFRA_NAME"
    predeploy_app_apply_env "$INFRA_NAME"

    helm_deploy_dir "$INFRA_HELM_DIR" "$INFRA_NAMESPACE" "$INFRA_RELEASE_NAME" "$INFRA_VALUES_FILE"

    log OK "==========================="
    log OK "Infrastructure updated."
    log OK "==========================="
}

uninstall_infrastructure() {
    log WARNING "Uninstalling infrastructure..."
    su - $k8s_user -c "helm uninstall $INFRA_RELEASE_NAME -n $INFRA_NAMESPACE "
    su - $k8s_user -c "kubectl delete namespace $INFRA_NAMESPACE"
}

# ===== MOJALOOP =====
check_mojaloop_urls() {
    log INFO "Checking URLs are active"
    for url in "${EXTERNAL_ENDPOINTS_LIST[@]}"; do
        if ! [[ $url =~ ^https?:// ]]; then
            url="http://$url"
        fi

        if curl --output /dev/null --silent --head --fail "$url"; then
            if curl --output /dev/null --silent --head --fail --write-out "%{http_code}" "$url" | grep -q "200\|301"; then
                log INFO "      URL $url  [ ok ]"
            else
                log WARNING "URL $url [ not ok ]"
                log WARNING "(Status code: $(curl --output /dev/null --silent --head --fail --write-out "%{http_code}"))"
            fi
        else
            log WARNING "URL $url is not working."
        fi
    done
}

check_mojaloop_health() {
    # verify the health of the deployment
    for i in "${EXTERNAL_ENDPOINTS_LIST[@]}"; do
        #curl -s  http://$i/health
        if [[ $(curl -s --head --fail --write-out \"%{http_code}\" http://$i/health |
            perl -nle '$count++ while /\"status\":\"OK+/g; END {print $count}') -lt 1 ]]; then
            log WARNING "[curl -s http://$i/health] endpoint healthcheck failed"
            # exit 1
        else
            log INFO "curl -s http://$i/health is OK "
        fi
        sleep 2
    done
}

mojaloop_postinstall_setup_ttk() {
    local ttk_files_dir=$MOJALOOP_REPO_TTK_FILES_DIR
    log DEBUG "Configuring mojaloop testing toolkit"
    #copy in the TTK environment data if bluebank pod exists and is running

    bb_pod_status=$(kubectl get pods bluebank-backend-0 --namespace $MOJALOOP_NAMESPACE --no-headers 2>/dev/null | awk '{print $3}')
    while [[ "$bb_pod_status" != "Running" ]]; do
        log INFO "TTK seems not running...waiting for pods to come up."
        sleep 5
        bb_pod_status=$(kubectl get pods bluebank-backend-0 --namespace $MOJALOOP_NAMESPACE --no-headers 2>/dev/null | awk '{print $3}')
    done
    if [[ "$bb_pod_status" == "Running" ]]; then
        log DEBUG "Configure testing toolkit (ttk) data and environment..."
        ####   bluebank  ###
        log INFO "=====bluebank====="
        ttk_pod_env_dest="/opt/app/examples/environments"
        ttk_pod_spec_dest="/opt/app/spec_files"
        kubectl cp $ttk_files_dir/environment/hub_local_environment.json bluebank-backend-0:$ttk_pod_env_dest/hub_local_environment.json
        kubectl cp $ttk_files_dir/environment/dfsp_local_environment.json bluebank-backend-0:$ttk_pod_env_dest/dfsp_local_environment.json
        kubectl cp $ttk_files_dir/spec_files/user_config_bluebank.json bluebank-backend-0:$ttk_pod_spec_dest/user_config.json
        kubectl cp $ttk_files_dir/spec_files/default.json bluebank-backend-0:$ttk_pod_spec_dest/rules_callback/default.json

        ####  greenbank  ###
        log INFO "=====greenbank====="
        kubectl cp $ttk_files_dir/environment/hub_local_environment.json greenbank-backend-0:$ttk_pod_env_dest/hub_local_environment.json
        kubectl cp $ttk_files_dir/environment/dfsp_local_environment.json greenbank-backend-0:$ttk_pod_env_dest/dfsp_local_environment.json
        kubectl cp $ttk_files_dir/spec_files/user_config_greenbank.json greenbank-backend-0:$ttk_pod_spec_dest/user_config.json
        kubectl cp $ttk_files_dir/spec_files/default.json greenbank-backend-0:$ttk_pod_spec_dest/rules_callback/default.json

        log OK "Configure TTK complete."
    fi
}

configure_mojaloop_manifests_values() {
    log DEBUG "Configuring mojaloop manifests"
    # setup env values
    log INFO "Copy $MOJALOOP_NAME app for deployment"
    copy_to_deploy_dir "$APPS_DIR/$MOJALOOP_NAME" "$MOJALOOP_NAME"
    predeploy_app_apply_env "$MOJALOOP_NAME"

    log INFO "Copy mojaloop manifests for deployment"
    for index in "${!MOJALOOP_LAYERS[@]}"; do
        layer_deploy_dir="$MOJALOOP_NAME/${MOJALOOP_LAYERS[index]}"
        layer_source_dir="$MOJALOOP_REPO_MANIFESTS_DIR/${MOJALOOP_LAYERS[index]}"
        copy_to_deploy_dir "$layer_source_dir" "$layer_deploy_dir"
    done

    local property_name old_value new_value
    local layer_deploy_dir layer_source_dir layer_dir
    local json_file="$DEPLOY_DIR/$MOJALOOP_NAME/mojaloop_values.json"
    jq -c '.[]' "$json_file" | while read -r json_object; do
        # Extract attributes from the JSON object
        property_name=$(echo "$json_object" | jq -r '.property_name')
        old_value=$(echo "$json_object" | jq -r '.old_value')
        new_value=$(echo "$json_object" | jq -r ".new_value")

        log DEBUG "Configure $property_name in mojaloop manifests"
        for index in "${!MOJALOOP_LAYERS[@]}"; do
            layer_dir="$DEPLOY_DIR/$MOJALOOP_NAME/${MOJALOOP_LAYERS[index]}"
            for file_name in $(find $layer_dir -type f); do
                replace_values_in_file "$file_name" "$old_value" "$new_value"
            done
        done
    done

    if [ $? -eq 0 ]; then
        log INFO "Mojaloop manifests edited successfully"
    else
        log ERROR "Could not edit manifests."
    fi
}

deploy_mojaloop_layers() {
    local layer_dir
    for index in "${!MOJALOOP_LAYERS[@]}"; do
        layer_dir="$DEPLOY_DIR/$MOJALOOP_NAME/${MOJALOOP_LAYERS[index]}"
        log INFO "Deploying layer $layer_dir"
        install_mojaloop_layer "$layer_dir" "$MOJALOOP_NAMESPACE"
    done
}

install_mojaloop_layer() {
    if [ "$#" -ne 2 ]; then
        log ERROR "Usage: install_mojaloop_layer <directory> <namespace>"
        return 1
    fi

    local directory="$1"
    local namespace="$2"
    local previous_dir="$PWD" # Save the current working directory

    log DEBUG "Installing mojaloop layer $directory"
    # Check if the directory exists.
    if [ ! -d "$directory" ]; then
        log ERROR "Directory '$directory' not found."
        return 1
    fi

    cd "$directory" || return 1
    # select non docker files
    local non_data_resource_files=$(ls *.yaml | grep -v '^docker-' | grep -v "\-data\-")
    local data_resource_files=$(ls *.yaml | grep -v '^docker-' | grep -i "\-data\-")
    for file in $data_resource_files; do
        kubectl apply -f $file -n $namespace >/dev/null 2>&1
    done
    for file in $non_data_resource_files; do
        kubectl apply -f $file -n $namespace >/dev/null 2>&1
    done

    if [ $? -eq 0 ]; then
        log INFO "Mojaloop layer installed successfully."
    else
        log ERROR "Failed to install mojaloop layer."
    fi

    # Return to the previous working directory
    cd "$previous_dir" || return 1
}

delete_mojaloop_layer() {
    local directory="$1"
    local namespace="$2"
    local previous_dir="$PWD" # Save the current working directory
    log INFO "Delete layer resources in mojaloop $directory"
    cd "$directory" || return 1

    local non_data_resource_files=$(ls *.yaml | grep -v '^docker-' | grep -v "\-data\-")
    local data_resource_files=$(ls *.yaml | grep -v '^docker-' | grep -i "\-data\-")
    for file in $non_data_resource_files; do
        kubectl delete -f $file -n $namespace >/dev/null 2>&1
    done
    for file in $data_resource_files; do
        kubectl delete -f $file -n $namespace >/dev/null 2>&1
    done

    if [ $? -eq 0 ]; then
        log INFO "Mojaloop layer deleted."
    else
        log ERROR "Failed to delete mojaloop layer."
    fi
    # Return to the previous working directory
    cd "$previous_dir" || return 1
}

deploy_mojaloop() {
    log DEBUG "Deploying mojaloop application manifests"
    create_namespace "$MOJALOOP_NAMESPACE"
    clone_repository "$MOJALOOP_BRANCH" "$MOJALOOP_REPO_LINK" "$REPO_DIR" "$MOJALOOP_NAME"
    configure_mojaloop_manifests_values
    deploy_mojaloop_layers

    log OK "============================"
    log OK "Mojaloop deployed."
    log OK "============================"

    log DEBUG "Run postinstall for mojaloop when all pods are running. \n" \
        "     sudo $0 -u $USER postinstall mojaloop"

    # mojaloop_postinstall_setup_ttk
    check_mojaloop_urls
    check_mojaloop_health
}

update_mojaloop() {
    log DEBUG "Updating mojaloop"
    configure_mojaloop_manifests_values
    deploy_mojaloop_layers
    log OK "==========================="
    log OK "Mojaloop updated."
    log OK "==========================="
}

uninstall_mojaloop() {
    log WARNING "Uninstalling mojaloop..."
    local layer_dir
    for index in "${!MOJALOOP_LAYERS[@]}"; do
        layer_dir="$DEPLOY_DIR/$MOJALOOP_NAME/${MOJALOOP_LAYERS[index]}"
        delete_mojaloop_layer "$layer_dir" "$MOJALOOP_NAMESPACE"
    done
    su - $k8s_user -c "kubectl delete namespace $MOJALOOP_NAMESPACE"
}

# ===== PAYMENTHUB =====
run_failed_sql_statements() {
    log INFO "Fixing operations app MySQL race condition"
    local operationsDeplName=$(kubectl get deploy --no-headers -o custom-columns=":metadata.name" -n $PH_NAMESPACE | grep operations-app)
    # kubectl exec -it mysql-0 -n infra -- mysql -h mysql -uroot -pethieTieCh8ahv < apps/config/db_setup.sql
    mariadb -u$PH_MYSQL_USER -p$PH_MYSQL_PASSWORD -h $PH_MYSQL_HOST -P $PH_MYSQL_PORT <$PH_MYSQL_INIT_FILE

    if [ $? -eq 0 ]; then
        log INFO "SQL File execution successful"
    else
        log ERROR "SQL File execution failed"
        return 1
    fi

    log INFO "Restarting deployment for operations-app"
    kubectl rollout restart deploy/$operationsDeplName -n $PH_NAMESPACE

    if [ $? -eq 0 ]; then
        log INFO "Deployment restart operations-app successful"
    else
        log ERROR "Deployment restart failed for operations-app"
        return 1
    fi
}

run_kong_migrations() {
    #Function to run kong migrations in Kong init container
    log DEBUG "Fixing Kong Migrations"
    #StoreKongPods
    local kongPods=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" -n $PH_NAMESPACE | grep "${PH_RELEASE_NAME}-kong")
    local dBcontainerName="wait-for-db"
    local podName initContainerStatus
    for pod in $kongPods; do
        podName=$(kubectl get pod $pod --no-headers -o custom-columns=":metadata.labels.app" -n $PH_NAMESPACE)
        if [[ "$podName" == "${PH_RELEASE_NAME}-kong" ]]; then
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

post_paymenthub_deployment_script() {
    # Run failed MySQL statements.
    run_failed_sql_statements
    # Run migrations in Kong Pod
    # Now using kong-init-migrations pod to run migrations
    run_kong_migrations
}

setup_paymenthub_env_vars() {
    log DEBUG "Setting up paymenthub environment variables"
    local property_name old_value new_value
    local json_file values_file

    # setup ph env values
    log INFO "Copy paymenthub app for deployment"
    copy_to_deploy_dir "$APPS_DIR/$PH_NAME" "$PH_NAME"
    predeploy_app_apply_env "$PH_NAME"

    # application-tenantsConnection.properties"
    log DEBUG "Updating tenant datasource connections in application-tenantsConnection.properties"
    local tenant_prop_file="$PH_HELM_DIR/config/application-tenantsConnection.properties"
    json_file="$DEPLOY_DIR/$PH_NAME/tenant_connection_values.json"
    jq -c '.[]' "$json_file" | while read -r json_object; do
        property_name=$(echo "$json_object" | jq -r '.property_name')
        old_value=$(echo "$json_object" | jq -r '.old_value')
        new_value=$(echo "$json_object" | jq -r ".new_value")
        replace_values_in_file "$tenant_prop_file" "$old_value" "$new_value"
    done
    copy_to_deploy_dir "$tenant_prop_file" "application-tenantsConnection.properties"

    log DEBUG "Updating env variables in $PH_NAME"
    values_file="$PH_VALUES_FILE"
    json_file="$DEPLOY_DIR/$PH_NAME/paymenthub_values.json"
    jq -c '.[]' "$json_file" | while read -r json_object; do
        property_name=$(echo "$json_object" | jq -r '.property_name')
        old_value=$(echo "$json_object" | jq -r '.old_value')
        new_value=$(echo "$json_object" | jq -r ".new_value")
        replace_values_in_file "$values_file" "$old_value" "$new_value"
    done
}

configure_paymenthub() {
    local ph_chart_dir="$REPO_DIR/$PH_NAME/helm"
    local previous_dir="$PWD" # Save the current working directory
    log INFO "Configuring Payment Hub..."

    prom_pod_status=$(kubectl get pods --namespace $PH_NAMESPACE --no-headers | grep prometheus-operator)
    if [[ "$prom_pod_status" != "Running" ]]; then
        LATEST=$(curl -s https://api.github.com/repos/prometheus-operator/prometheus-operator/releases/latest | jq -cr .tag_name)
        log DEBUG "Deploying prometheus operator ${LATEST} in $PH_NAMESPACE namespace"
        su - $k8s_user -c "curl -sL https://github.com/prometheus-operator/prometheus-operator/releases/download/${LATEST}/bundle.yaml | kubectl create -n $PH_NAMESPACE -f -"
    else
        log INFO "Prometheus operator already deployed and running..."
    fi

    cd $ph_chart_dir || exit 1

    # create secrets for paymenthub namespace
    cd es-secret || exit 1
    log DEBUG "Creating elasticsearch secrets..."
    export ELASTICSEARCH_PASSWORD=$PH_ELASTICSEARCH_PASSWORD
    create_secret "$PH_NAMESPACE"
    # create_secret "$INFRA_NAMESPACE"
    # create_secret "$MOJALOOP_NAMESPACE"

    cd ..
    cd kibana-secret || exit 1
    log DEBUG "Creating kibana secrets..."
    create_secret "$PH_NAMESPACE"
    # create_secret "$INFRA_NAMESPACE"
    # create_secret "$MOJALOOP_NAMESPACE"

    # ph-ee-connector-channel pod requires redis-password secret key.
    # redis set to auth.enabled=false because mojaloop requires no-auth redis.
    # if redis is used with auth.enabled=false, no secret is created. We create manually
    cd ..
    kubectl create secret generic "${PH_RELEASE_NAME}-redis" --from-literal=redis-password="" -n "$PH_NAMESPACE"

    # check if the configuration was successful
    if [ $? -eq 0 ]; then
        log INFO "Paymenthub configuration successful."
    else
        log ERROR "Paymenthub configuration failed."
    fi

    # Return to the previous working directory
    cd "$previous_dir" || return 1
}

deploy_paymenthub() {
    log DEBUG "Deploying PaymentHub EE"
    create_namespace "$PH_NAMESPACE"
    clone_repository "$PH_BRANCH" "$PH_REPO_LINK" "$REPO_DIR" "$PH_NAME"
    
    setup_paymenthub_env_vars
    configure_paymenthub

    helm_deploy_dir "$PH_HELM_DIR" "$PH_NAMESPACE" "$PH_RELEASE_NAME" "$PH_VALUES_FILE"

    log OK "============================"
    log OK "Paymenthub deployed."
    log OK "============================"

    log DEBUG "Run postinstall for paymenthub when all pods are running. \n" \
        "     sudo $0 -u $USER postinstall paymenthub"
}

update_paymenthub() {
    log DEBUG "Updating paymenthub"
    setup_paymenthub_env_vars

    helm_deploy_dir "$PH_HELM_DIR" "$PH_NAMESPACE" "$PH_RELEASE_NAME" "$PH_VALUES_FILE"

    log OK "==========================="
    log OK "Paymenthub updated."
    log OK "==========================="
}

uninstall_paymenthub() {
    log WARNING "Uninstalling paymenthub ..."
    su - $k8s_user -c "helm uninstall $PH_RELEASE_NAME -n $PH_NAMESPACE"
    su - $k8s_user -c "kubectl delete namespace $PH_NAMESPACE"
}

# ===== FULL STACK =====

print_end_message() {
    log OK "==========================="
    log OK "INSTALLATION COMPLETED."
    log OK "==========================="

    log "Monitor pods using kubectl"
    log "kubectl get pods -n infra # Infrastructure"
    log "kubectl get pods -n mojaloop # Mojaloop"
    log "kubectl get pods -n paymenthub # Paymenthub"
}

uninstall_apps() {
    log WARNING "Uninstalling all deployments..."
    uninstall_infrastructure
    uninstall_paymenthub
    uninstall_mojaloop
    log WARNING "Deployments uninstalled."
}

update_apps() {
    log INFO "Updating all deployments"
    update_infrastructure
    update_paymenthub
    update_mojaloop
    log OK "==========================="
    log OK "All deployments updated."
    log OK "==========================="
}

deploy_apps() {
    deploy_infrastructure
    deploy_paymenthub
    deploy_mojaloop
    print_end_message
}
