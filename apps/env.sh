#!/bin/bash

########################################################################
# GLOBAL VARS
########################################################################
BASE_DIR=$(pwd)
APPS_DIR="$BASE_DIR/apps"
INFRA_NAMESPACE="infra"
INFRA_RELEASE_NAME="infra"
# mojaloop
MOJALOOPBRANCH="alpha-1.1"
MOJALOOPREPO_DIR="mojaloop"
MOJALOOP_NAMESPACE="mojaloop"
MOJALOOP_REPO_LINK="https://github.com/mojaloop/platform-shared-tools.git"
MOJALOOP_LAYER_DIRS=("$APPS_DIR/mojaloop/packages/deployment/k8s/crosscut" "$APPS_DIR/mojaloop/packages/deployment/k8s/apps" "$APPS_DIR/mojaloop/packages/deployment/k8s/ttk" )
MOJALOOP_VALUES_FILE="$APPS_DIR/config/mojaloop_values.json"
# paymenthub
PHBRANCH="master"
PHREPO_DIR="phee"
PH_NAMESPACE="paymenthub"
PH_RELEASE_NAME="g2p-sandbox"
PH_VALUES_FILE="$APPS_DIR/ph_values.yaml"
PH_REPO_LINK="https://github.com/openMF/ph-ee-env-labs.git"
# Define Kubernetes service and MySQL connection details
MYSQL_SERVICE_NAME="mysql"  # Replace with your MySQL service name
MYSQL_SERVICE_PORT="3306"           # Replace with the MySQL service port
LOCAL_PORT="3306"                   # Local port to forward to
MAX_WAIT_SECONDS=60
# MySQL Connection Details
MYSQL_USER="mifos"
MYSQL_PASSWORD="password"
MYSQL_HOST="127.0.0.1"
SQL_FILE="$BASE_DIR/config/setup.sql"
