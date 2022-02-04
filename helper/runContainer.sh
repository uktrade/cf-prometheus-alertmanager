#!/usr/bin/env bash

status(){
    echo "------------------> ${1}"
}

prepare(){

    if [ ! -d ${CACHE_PATH} ]
    then
        mkdir -p ${CACHE_PATH}
    fi 

    if [ ! -d ${BUILD_PATH} ]
    then 
        mkdir -p ${BUILD_PATH}
    fi
}

set_version(){
    export VERSION_FILE="${APP_ROOT}/runtime.txt"
    export DEFAULT_VERSION='0.21.0'

    SET_VERSION=""
    if [ -f ${VERSION_FILE} ]
    then
        SET_VERSION=$(cat "${VERSION_FILE}" | tr -dc '0-9|.0-9|.0-9' | tr -d " ")
        if ! [[ $SET_VERSION  =~ $VERSION_RX ]]
        then
            echo "ERROR: ${VERSION_FILE} contails invalid version , it must be in formate Major.Minor.Patch format"
            echo "INFO: Falling back to ${DEFAULT_VERSION}"
            SET_VERSION="${DEFAULT_VERSION}"
        fi
    else
        SET_VERSION="${DEFAULT_VERSION}"
    fi
    export VERSION="${SET_VERSION}"
}

set_download_vars(){
    export DOWNLOAD_FILE_NAME="alertmanager-${VERSION}.linux-amd64.tar.gz"
    export DOWNLOAD_FILE_URL="https://github.com/prometheus/alertmanager/releases/download/v${VERSION}/${DOWNLOAD_FILE_NAME}"

    export SHA_SUM_FILE="sha256sums.txt"
    export DOWNLOAD_SHA256_URL="https://github.com/prometheus/alertmanager/releases/download/v${VERSION}/${SHA_SUM_FILE}"
}

download_alertmanager(){

  if [ -f ${CACHE_PATH}/${DOWNLOAD_FILE_NAME} ]
  then
    status "Using Cached Prometheus Alertmanger ${VERSION}"
  else
    status "Downloading Prometheus Alertmanger ${VERSION}"
    if [ -f  ${CACHE_PATH}/${DOWNLOAD_FILE_NAME} ]
    then 
        rm -f ${CACHE_PATH}/${DOWNLOAD_FILE_NAME}
    fi 
    curl -L "${DOWNLOAD_FILE_URL}" --output "${CACHE_PATH}/${DOWNLOAD_FILE_NAME}" --silent 
    curl -L "${DOWNLOAD_SHA256_URL}" --output "${CACHE_PATH}/${SHA_SUM_FILE}" --silent
  fi
}

validate_download_file(){
  local sum=$(grep ${DOWNLOAD_FILE_NAME} ${CACHE_PATH}/${SHA_SUM_FILE} | cut -d' ' -f1)
  echo "${sum} ${CACHE_PATH}/${DOWNLOAD_FILE_NAME}" > checksum

  if ! sha256sum -c checksum --status
  then
   rm -f checksum
   status "Failed: Downloaded file could not be validated"
   exit 1
  fi
  rm checksum
}

install_alertmanager(){
  status "Installing Prometheus Alertmanager ${VERSION}"
  #move user supplied file to cache dir
  if [ -f "${BUILD_PATH}/alertmanager.yml" ]
  then
    cp -f "${BUILD_PATH}/alertmanager.yml" "${CACHE_PATH}/"
  fi

  tar -zxf "${CACHE_PATH}/${DOWNLOAD_FILE_NAME}"  --strip-components=1 -C "${BUILD_PATH}"
}

configure_app(){
    status "Configuring app"
    if [ -f "${APP_ROOT}/alertmanager.yml" ]
    then 
        cp -f ${APP_ROOT}/alertmanager.yml ${BUILD_PATH}/alertmanager.yml
    fi

    status "Replacing vars"

    env | while IFS='=' read -r key val; do
            if grep -q "\\\${$key}" "${BUILD_PATH}/alertmanager.yml" > /dev/null 2>&1
            then
                if echo ${val} | grep -q http
                then 
                    val=$(perl -ne 'print quotemeta($_)' <<< ${val})
                    val=${val::-1}
                fi
                sed -i 's@${'"${key}"'}@'"${val}"'@g' "${BUILD_PATH}/alertmanager.yml"
            fi
        done
}

starting_alertmanager(){
    command="${BUILD_PATH}/alertmanager --config.file=${BUILD_PATH}/alertmanager.yml --web.listen-address=:${PORT} --storage.path=${BUILD_PATH}/data --log.level=${LOG_LEVEL:-info} --log.format=${LOG_FORMAT:-logfmt}"
    status "Running ${command}"
    `$command`
}

main(){
    prepare
    set_version
    set_download_vars
    download_alertmanager
    validate_download_file
    install_alertmanager
    configure_app
    starting_alertmanager
}

main