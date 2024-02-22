#!/usr/bin/env bash
# env.sh : Environment Variables
# Author:  Honest Chirozva
# Date :   February 2024

########################################################################
# GLOBAL VARS
########################################################################
BASE_DIR=$(pwd)
APPS_DIR="$BASE_DIR/apps"
INFRA_NAMESPACE="infra"
INFRA_RELEASE_NAME="infra"
# mojaloop
MOJALOOPBRANCH="main"
MOJALOOPREPO_DIR="$APPS_DIR/mojaloop"
MOJALOOP_NAMESPACE="mojaloop"
MOJALOOP_REPO_LINK="https://github.com/mojaloop/platform-shared-tools.git"
MOJALOOP_MANIFESTS_DIR=$MOJALOOPREPO_DIR/packages/installer/manifests
MOJALOOP_MONGO_IMPORT_DIR=$MOJALOOPREPO_DIR/packages/deployment/docker-compose-apps/ttk_files/mongodb
MOJALOOP_TTK_FILES="$MOJALOOPREPO_DIR/packages/deployment/docker-compose-apps/ttk_files"
MOJALOOP_LAYER_DIRS=(
    "$MOJALOOP_MANIFESTS_DIR/crosscut"
    "$MOJALOOP_MANIFESTS_DIR/apps"
    "$MOJALOOP_MANIFESTS_DIR/reporting"
    "$MOJALOOP_MANIFESTS_DIR/ttk"
)
MOJALOOP_VALUES_FILE="$APPS_DIR/config/mojaloop_values.json"
# paymenthub
PHBRANCH="master"
PHREPO_DIR="phee"
PH_NAMESPACE="paymenthub"
PH_RELEASE_NAME="g2p-sandbox"
PH_VALUES_FILE="$APPS_DIR/ph_values.yaml"
PH_REPO_LINK="https://github.com/openMF/ph-ee-env-labs.git"
PH_HOSTNAME="counselorservice.sytes.net"
PH_MESSAGE_GATEWAY_API_KEY=aadc326ccee4e35716352520d2ec367b
PH_MESSAGE_GATEWAY_PROJECT_ID=AC7243e41db602c5ddde0cdb3537d7003f
# Define Kubernetes service and MySQL connection details
MYSQL_USER="mifos"
MYSQL_PASSWORD="password"
MYSQL_HOST="counselorservice.sytes.net"
MYSQL_PORT="3306"
MYSQL_INIT_FILE="$APPS_DIR/config/db_setup.sql"
