#!/bin/bash

# Text color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

function log() {
  local logLevel=$1
  shift
  local logMessage=$@
  case "$logLevel" in
    "DEBUG")
        echo -e "${BLUE}DEBUG: $logMessage ${RESET} "
        ;;
    "INFO")
        echo -e "${RESET}INFO: $logMessage ${RESET} "
        ;;
    "WARNING")
        echo -e "${YELLOW}WARNING: $logMessage ${RESET}"
        ;;
    "OK")
        echo -e "${GREEN} $logMessage ${RESET}"
        ;;
    "ERROR")
        echo -e "${RED}ERROR: $logMessage ${RESET} "
        ;;
    *) # Default case
        echo -e "$logLevel $logMessage"
        ;;
  esac
}
