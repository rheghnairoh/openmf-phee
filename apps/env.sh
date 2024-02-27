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
REPO_DIR="$BASE_DIR/repository"
#infra
INFRA_NAMESPACE="infra"
INFRA_RELEASE_NAME="infra"
# mojaloop
MOJALOOP_BRANCH="main"
MOJALOOP_NAME="mojaloop"
MOJALOOP_NAMESPACE="mojaloop"
MOJALOOP_LAYERS=("apps" "crosscut" "reporting" "ttk")
MOJALOOP_REPO_LINK="https://github.com/mojaloop/platform-shared-tools.git"
MOJALOOP_REPO="$REPO_DIR/$MOJALOOP_NAME"
MOJALOOP_REPO_MANIFESTS_DIR=$MOJALOOP_REPO/packages/installer/manifests
MOJALOOP_REPO_MONGO_DIR=$MOJALOOP_REPO/packages/deployment/docker-compose-apps/ttk_files/mongodb
MOJALOOP_REPO_TTK_FILES_DIR="$MOJALOOP_REPO/packages/deployment/docker-compose-apps/ttk_files"
# paymenthub
PH_BRANCH="master"
PH_NAME="paymenthub"
PH_NAMESPACE="paymenthub"
PH_RELEASE_NAME="g2p-sandbox"
PH_REPO_LINK="https://github.com/openMF/ph-ee-env-labs.git"
PH_REPO="$REPO_DIR/$PH_NAME/helm/g2p-sandbox-fynarfin-demo"
PH_VALUES_FILE="$DEPLOY_DIR/$PH_NAME/ph_values.yaml"
PH_MYSQL_INIT_FILE="$DEPLOY_DIR/$PH_NAME/db_setup.sql"
PH_HOSTNAME="counselorservice.sytes.net"
PH_MESSAGE_GATEWAY_API_KEY=aadc326ccee4e35716352520d2ec367b
PH_MESSAGE_GATEWAY_PROJECT_ID=AC7243e41db602c5ddde0cdb3537d7003f
PH_ELASTICSEARCH_PASSWORD=elasticSearchPas42
PH_MYSQL_USER="mifos"
PH_MYSQL_PASSWORD="password"
PH_MYSQL_HOST="counselorservice.sytes.net"
PH_MYSQL_PORT="3306"
