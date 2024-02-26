#!/usr/bin/env bash
# helper.sh : Helper Utilities
# Author:  Honest Chirozva
# Date :   February 2024

source ./apps/env.sh
source ./scripts/logger.sh

########################################################################
# HELPER FUNCTIONS
########################################################################

function replace_values_in_file() {
    local file="$1"
    local old_value="$2"
    local new_value="$3"

    # Check if sed is available, if not, exit with an error message
    if ! command -v sed &>/dev/null; then
        log ERROR " 'sed' is not installed. Please make sure it's installed on your system."
        return 1
    fi

    # Print debugging information
    log INFO "Updating file: $file \n" \
        "Old value: $old_value \n" \
        "New value: $new_value"

    # Use sed to update the YAML file with the new value
    if sed -i "s/$old_value/$new_value/" "$file"; then
        log INFO "Value updated successfully."
        return 0
    else
        log ERROR "Error updating the value."
        return 1
    fi
}

function rename_off_files_to_yaml() {
    local folder="$1"
    local previous_dir="$PWD" # Save the current working directory

    # Check if the folder exists
    if [ ! -d "$folder" ]; then
        log ERROR "The specified folder does not exist."
        return 1
    fi

    # Navigate to the folder
    cd "$folder" || return 1

    # Rename all .off files to .yaml
    for file in *.off; do
        if [ -e "$file" ]; then
            new_name="${file%.off}.yaml" # Remove .off and add .yaml
            mv "$file" "$new_name"
            log INFO "Renamed $file -> $new_name"
        fi
    done

    # Return to the previous working directory
    cd "$previous_dir" || return 1
}

function create_secret() {
    local namespace="$1"
    log INFO "Creating secrets in $namespace namespace"
    if make secrets -e NAMESPACE="$namespace" >>/dev/null 2>&1; then
        log OK "Create secrets completed."
        return 0
    else
        log ERROR "Creating secrets failed."
        return 1
    fi
}

function deploy_helm_chart_from_dir() {
    # Check if Helm is installed
    if ! command -v helm &>/dev/null; then
        log ERROR "Helm not installed. Please install Helm first."
        exit 1
    fi

    # Check if the chart directory exists
    local chart_dir="$1"
    local namespace="$2"
    local release_name="$3"
    if [ ! -d "$chart_dir" ]; then
        log ERROR "Chart directory '$chart_dir' does not exist."
        exit 1
    fi

    # Check if a values file has been provided
    values_file="$4"

    # Enter the chart directory
    cd "$chart_dir" || exit 1

    log DEBUG "Deploying helm chart $release_name from directory $chart_dir..."

    # Run helm dependency update to fetch dependencies
    log INFO "Updating Helm chart dependencies..."
    helm dependency update >>/dev/null 2>&1
    log INFO "Helm chart dependencies updated."

    # Run helm dependency build
    log INFO "Building helm chart dependencies..."
    helm dependency build . >>/dev/null 2>&1
    log INFO "Helm chart dependencies built."

    # Determine whether to install or upgrade the chart also check whether to apply a values file
    log INFO "Upgrading helm chart..."
    if [ -n "$values_file" ]; then
        helm upgrade --install "$release_name" . -n "$namespace" -f "$values_file"
    else
        helm upgrade --install "$release_name" . -n "$namespace"
    fi
    log INFO "Helm chart upgraded"

    # Use kubectl to get the resource count in the specified namespace
    resource_count=$(kubectl get pods -n "$namespace" --ignore-not-found=true 2>/dev/null | grep -v "No resources found" | wc -l)
    # Check if the deployment was successful
    if [ $resource_count -gt 0 ]; then
        log OK "Helm chart deployed successfully."
    else
        log ERROR "Helm chart $release_name deployment failed."
        if [[ "$release_name" == "$PH_RELEASE_NAME" ]]; then
            log ERROR "Payment hub EE installation failed \n" \
                "Consider uninstalling: sudo ./installer.sh -m uninstall -u $k8s_user \n" \
                "And install again: sudo ./installer.sh -m install -u $k8s_user"
            # exit 1
        fi

    fi
    # Exit the chart directory
    cd - || exit 1
}

function create_namespace() {
    local namespace=$1
    log DEBUG "Creating namespace $namespace"
    # Check if the namespace already exists
    if kubectl get namespace "$namespace" >>/dev/null 2>&1; then
        log WARNING "Namespace $namespace already exists."
        return 1
    fi

    # Create the namespace
    kubectl create namespace "$namespace"
    if [ $? -eq 0 ]; then
        log INFO "Namespace $namespace created successfully."
    else
        log INFO "Failed to create namespace $namespace."
    fi
}

function clone_repo() {
    if [ "$#" -ne 4 ]; then
        log ERROR "Usage: clone_repo <branch> <repo_link> <target_directory> <cloned_directory_name>"
        return 1
    fi

    branch="$1"
    repo_link="$2"
    target_directory="$3"
    cloned_directory_name="$4"
    log DEBUG "Cloning repository $repo_link"

    # Check if the target directory exists; if not, create it.
    if [ ! -d "$target_directory" ]; then
        mkdir -p "$target_directory"
    fi

    # Change to the target directory.
    cd "$target_directory" || return 1

    # Clone the repository with the specified branch into the specified directory.
    if [ -d "$cloned_directory_name" ]; then
        log WARNING "$cloned_directory_name repo exists deleting and re-cloning"
        rm -rf "$cloned_directory_name"
        git clone -b "$branch" "$repo_link" "$cloned_directory_name" >>/dev/null 2>&1
    else
        git clone -b "$branch" "$repo_link" "$cloned_directory_name" >>/dev/null 2>&1
    fi

    if [ $? -eq 0 ]; then
        log INFO "Repository cloned successfully."
    else
        log WARNING "Failed to clone the repository."
    fi

    # Change back to the previous directory
    cd - || return 1
}

function copy_to_deploy_dir {
    from_path="$1"
    to_path="$2"
    log INFO "Copying $from_path to $DEPLOY_DIR/$to_path"
    rm -rf $DEPLOY_DIR/$to_path
    cp -r $from_path $DEPLOY_DIR/$to_path
}
