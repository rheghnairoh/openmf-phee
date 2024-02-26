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
MOJALOOPBRANCH="main"
MOJALOOP_REPO_DIR_NAME="mojaloop-repo"
MOJALOOP_DIR="$APPS_DIR/mojaloop"
MOJALOOP_NAMESPACE="mojaloop"
MOJALOOP_REPO_LINK="https://github.com/mojaloop/platform-shared-tools.git"
MOJALOOP_MANIFESTS_DIR=$MOJALOOP_DIR/packages/installer/manifests
MOJALOOP_MONGO_IMPORT_DIR=$MOJALOOP_DIR/packages/deployment/docker-compose-apps/ttk_files/mongodb
MOJALOOP_TTK_FILES="$MOJALOOP_DIR/packages/deployment/docker-compose-apps/ttk_files"
MOJALOOP_LAYERS=("apps" "crosscut" "reporting" "ttk")
# paymenthub
PHBRANCH="master"
PH_REPO_DIR_NAME="phee-repo"
PH_NAMESPACE="paymenthub"
PH_RELEASE_NAME="g2p-sandbox"
PH_REPO_LINK="https://github.com/openMF/ph-ee-env-labs.git"
PH_VALUES_FILE="values.yaml"
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
PH_MYSQL_INIT_FILE="$APPS_DIR/phee/db_setup.sql"
