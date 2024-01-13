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
PH_HOSTNAME="counselorservice.sytes.net"
# Define Kubernetes service and MySQL connection details
MYSQL_USER="mifos"
MYSQL_PASSWORD="password"
MYSQL_HOST="counselorservice.sytes.net"
MYSQL_PORT="3306"
SQL_FILE="$APPS_DIR/config/setup.sql"
