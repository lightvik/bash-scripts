#!/usr/bin/env bash

# Переменные
HOST=''
USERNAME=''
PASSWORD=''
DEPENDENCIES=( curl jq xq yq )
PATH_TO_CA_CERTIFICATE="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )/ovirt.ca"

# Проверка переменных
if [[ -z ${HOST+x} || ${#HOST} -le '0' ]]; then echo 'Переменная ${HOST} не заполнена/обьявлена'; exit 1; fi
if [[ -z ${USERNAME+x} || ${#USERNAME} -le '0' ]]; then echo 'Переменная ${USERNAME} не заполнена/обьявлена'; exit 1; fi
if [[ -z ${PASSWORD+x} || ${#PASSWORD} -le '0' ]]; then echo 'Переменная ${PASSWORD} не заполнена/обьявлена'; exit 1; fi

# Проверка зависимостей
for DEPENDENCE in ${DEPENDENCIES[*]}; do
  if ! $(command -v ${DEPENDENCE}) --help 2>/dev/null 1>/dev/null; then
    echo "Необходимо установить ${DEPENDENCE}"
    echo 'Пример:'
    echo 'sudo yum install curl jq -y && sudo pip install xq yq'
    exit 1
  fi
done

function help {
  echo ''
  exit 0
}

function get-images-list {
  local XML_DISKS_INFO=$(
  curl --location \
  --cacert ${PATH_TO_CA_CERTIFICATE} \
  --silent \
  --get "https://${HOST}/ovirt-engine/api/disks" \
  --header 'Accept: application/xml' \
  --user ${USERNAME}:${PASSWORD} \
  | xq .)
  local ARRAY=( $(echo ${XML_DISKS_INFO} | jq -r '.disks.disk | .[].alias') )
  local ARRAY2=( $(echo ${XML_DISKS_INFO} | jq -r '.disks.disk | .[]."@id"') )
  local ARRAY3=( $(echo ${XML_DISKS_INFO} | jq -r '.disks.disk | .[]."description"') )
  for INDEX in ${!ARRAY[*]}; do printf "${ARRAY[$INDEX]} ${ARRAY2[$INDEX]} ${ARRAY3[$INDEX]}\n"; done
}

function image-get-url {
  local SOURCE_IMAGE_ID="${1}"
  curl --location \
  --cacert ${PATH_TO_CA_CERTIFICATE} \
  --silent \
  --request POST "https://${HOST}/ovirt-engine/api/imagetransfers" \
  --header 'Content-Type: application/xml' \
  --header 'Accept: application/xml' \
  --user ${USERNAME}:${PASSWORD} \
  --data-raw "<image_transfer><disk id=\"${SOURCE_IMAGE_ID}\"/><direction>download</direction></image_transfer>" \
  | xq . | jq -r .image_transfer.transfer_url
}

function download-image {
  curl --cacert ${PATH_TO_CA_CERTIFICATE} ${1}
}

function image-download-and-write {
  local SOURCE_IMAGE_ID
  echo 'Введите ID образа который необходимо получить через Ovirt REST API'
  read SOURCE_IMAGE_ID
  echo

  echo 'Введите путь до диска в который будет произведена запись образа '
  read TARGET_DISK
  echo
  if [[ $(partprobe -d ${TARGET_DISK} 1>/dev/null 2>/dev/null && printf '0' || printf '1') -eq '0' ]]; then
    local IMAGE_DOWNLOAD_URL=$(image-get-url ${SOURCE_IMAGE_ID})

    echo "Будет выполнено:"
    echo "скачивание образа с ID: ${SOURCE_IMAGE_ID}"
    echo "по URL: ${IMAGE_DOWNLOAD_URL}"
    echo "Образ будет записан через linux pipe в диск: ${TARGET_DISK}"
    echo
    echo '! ! ! Проверьте данные ! ! !'
    echo 'Если данные верны:'
    echo 'Введите YES для продолжения'
    read USER_CONFIRM
    echo
    if [[ "${USER_CONFIRM}" == 'YES' ]]; then
      download-image ${IMAGE_DOWNLOAD_URL} | dd bs=4M of=${TARGET_DISK}
    else
      echo "Подтверждение не было получено"
      exit 1
    fi
  else
    echo "Диск не существует"
    exit 1
  fi
}

case "$1" in
  #
  get-images-list)
    #
    get-images-list
    ;;
  #
  image-download-and-write)
    #
    image-download-and-write
    ;;
  # Выходим с ошибкой в ином случае
  *)
    echo 'Функция не передана либо не существует'; exit 1
    ;;
esac
