#/usr/bin/env bash

ALERTMANAGER_SERVER=${1}
PORT=${2:-443}
CURRENT_DIR=$(pwd -P)
PROTOCOL='https'

if [ $PORT != 443 ]
then 
    PROTOCOL='http'
fi

SCRIPT_DIR="${CURRENT_DIR}/$(dirname ${BASH_SOURCE})"
TEST_FILE="${SCRIPT_DIR}/dbAlerts.json"

curl -XPOST -d @${TEST_FILE}  ${PROTOCOL}://${ALERTMANAGER_SERVER}:${PORT}/api/v1/alerts