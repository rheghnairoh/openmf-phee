#!/usr/bin/env bash
# logger.sh : Logger
# Author:  Honest Chirozva 
# Date :   February 2024 

# Text color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

set_logfiles() {
  # set the logfiles
  if [ ! -z ${logfiles+x} ]; then 
    LOGFILE="/tmp/$logfiles.log"
    ERRFILE="/tmp/$logfiles.err"
    echo $LOGFILE
    echo $ERRFILE
  fi 
  touch $LOGFILE
  touch $ERRFILE
  printf "start : Paymenthub x Mojaloop Installer utility [%s]\n" "`date`" >> $LOGFILE
  printf "================================================================================\n" >> $LOGFILE
  printf "start : Paymenthub x Mojaloop Installer utility [%s]\n" "`date`" >> $ERRFILE
  printf "================================================================================\n" >> $ERRFILE
  printf "==> logfiles can be found at %s and %s \n" "$LOGFILE" "$ERRFILE"
}

log() {
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
