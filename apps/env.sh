#!/usr/bin/env bash
# env.sh : Environment Variables
# Author:  Honest Chirozva
# Date :   February 2024

########################################################################
# GLOBAL VARS
########################################################################
BASE_DIR=$(pwd)
APPS_DIR="$BASE_DIR/apps"
DEPLOY_DIR="$BASE_DIR/deploy"
#infra
INFRA_NAMESPACE="infra"
INFRA_RELEASE_NAME="infra"
# mojaloop
MOJALOOP_BRANCH="main"
MOJALOOP_REPO_NAME="mojaloop-repo"
MOJALOOP_DIR="$APPS_DIR/$MOJALOOP_REPO_NAME"
MOJALOOP_APP_NAME="mojaloop"
MOJALOOP_NAMESPACE="mojaloop"
MOJALOOP_REPO_LINK="https://github.com/mojaloop/platform-shared-tools.git"
MOJALOOP_MANIFESTS_DIR=$MOJALOOP_DIR/packages/installer/manifests
MOJALOOP_MONGO_IMPORT_DIR=$MOJALOOP_DIR/packages/deployment/docker-compose-apps/ttk_files/mongodb
MOJALOOP_TTK_FILES="$MOJALOOP_DIR/packages/deployment/docker-compose-apps/ttk_files"
MOJALOOP_LAYERS=("apps" "crosscut" "reporting" "ttk")
# paymenthub
PH_BRANCH="master"
PH_REPO_NAME="paymenthub-repo"
PH_DIR="$APPS_DIR/$PH_REPO_NAME/helm/g2p-sandbox-fynarfin-demo"
PH_APP_NAME="paymenthub"
PH_NAMESPACE="paymenthub"
PH_RELEASE_NAME="g2p-sandbox"
PH_REPO_LINK="https://github.com/openMF/ph-ee-env-labs.git"
PH_VALUES_FILE="ph_values.yaml"
PH_HOSTNAME="counselorservice.sytes.net"
PH_MESSAGE_GATEWAY_API_KEY=aadc326ccee4e35716352520d2ec367b
PH_MESSAGE_GATEWAY_PROJECT_ID=AC7243e41db602c5ddde0cdb3537d7003f
# Elastic Search
PH_ELASTICSEARCH_PASSWORD=elasticSearchPas42
# Define Kubernetes service and MySQL connection details
PH_MYSQL_USER="mifos"
PH_MYSQL_PASSWORD="password"
PH_MYSQL_HOST="counselorservice.sytes.net"
PH_MYSQL_PORT="3306"
PH_MYSQL_INIT_FILE="$APPS_DIR/$PH_APP_NAME/db_setup.sql"
