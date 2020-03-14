#!/usr/bin/env bash

# Для работы скрипта необходим пакет certbot

# Глобальные переменные
PROVIDER='yandex'

function usage {
  echo 'Пример использования:'
  echo "$0 certonly test.example.com"
}

if [ -z "$1" ]; then
  usage
fi

function yandex-add-record {
  # Считываем API_KEY из файла API_KEY.txt
  local WORK_DIR="$(dirname "$0")"
  source "${WORK_DIR}/api_token"
  # URL - API для добавления DNS записей
  local YANDEX_DNS_ADD_URL='https://pddimp.yandex.ru/api2/admin/dns/add'
  # Переменная CERTBOT_DOMAIN переданная certbot это fdqn, парсим ее на домен и поддомен для корректного запроса
  local DOMAIN=$(printf ${CERTBOT_DOMAIN} | rev | cut -d'.' -f'1,2' | rev)
  local SUB_DOMAIN="_acme-challenge.$(printf ${CERTBOT_DOMAIN} | sed 's/.'"${DOMAIN}"'//')"
  # Параметры DNS записи
  local TTL='300'
  local TYPE='TXT'
  local WAIT_TIME='900'
  # Парсим ID записи из запроса по ее добавлению.
  RECORD_ID=$(curl \
  -s \
  -X POST \
  -H "PddToken: ${API_TOKEN}" \
  -d "domain=${DOMAIN}&type=${TYPE}&subdomain=${SUB_DOMAIN}&ttl=${TTL}&content=${CERTBOT_VALIDATION}" "${YANDEX_DNS_ADD_URL}" \
  | jq -r ".record" | jq -r ".record_id")

  # Создаем временную корневую директорию для CERTBOT
  if [ ! -d /tmp/CERTBOT ];then
    mkdir -m 0700 /tmp/CERTBOT
  fi
  # Создаем временную директорию для домена
  if [ ! -d /tmp/CERTBOT/$CERTBOT_DOMAIN ];then
    mkdir -m 0700 /tmp/CERTBOT/$CERTBOT_DOMAIN
  fi
  # Создаем файл с правами unix 700 для id dns записи
  umask 077
  echo ${RECORD_ID} > /tmp/CERTBOT/$CERTBOT_DOMAIN/RECORD_ID

  # Ждем время жизни записи
  sleep ${WAIT_TIME}
}

function yandex-remove-record {
  # URL - API для удаления DNS записей
  local YANDEX_DNS_REMOVE_URL='https://pddimp.yandex.ru/api2/admin/dns/del'
  # Переменная CERTBOT_DOMAIN переданная certbot это fdqn, парсим ее на домен и поддомен для корректного запроса
  local DOMAIN=$(printf ${CERTBOT_DOMAIN} | rev | cut -d'.' -f'1,2' | rev)
  # Если директория домена существует
  if [ -d /tmp/CERTBOT/$CERTBOT_DOMAIN ]; then
    # Если файл с id dns записи существует
    if [ -f /tmp/CERTBOT/${CERTBOT_DOMAIN}/RECORD_ID ]; then
      # Записываем в переменную значение из файла
      RECORD_ID=$(cat /tmp/CERTBOT/$CERTBOT_DOMAIN/RECORD_ID)
    fi
    # Удаляем каталог домена
    rm -rf /tmp/CERTBOT/${CERTBOT_DOMAIN}
  fi

  # Удаляем TXT запись если переменная не пуста
  if [ -n "${RECORD_ID}" ]; then
    curl \
    -s \
    -X POST \
    "${YANDEX_DNS_REMOVE_URL}" \
    -H "PddToken: ${API_TOKEN}" \
    -d "domain=${DOMAIN}&record_id=${RECORD_ID}"
  fi
}

function certonly {
  #
  if [ -z "$1" ]; then
    echo 'Нужно передать доменное имя в качестве первого аргумента'
    exit 1
  fi
  #
  certbot certonly \
  --manual \
  --preferred-challenges dns \
  --register-unsafely-without-email --agree-tos \
  --test-cert \
  --manual-public-ip-logging-ok  \
  --manual-auth-hook "$0 "${PROVIDER}"-add-record" \
  --manual-cleanup-hook "$0 "${PROVIDER}"-remove-record" \
  -d "${1}"
}

case "$1" in
  # Выводим справку по запросу
  -h | --help)
    usage
    exit 0
    ;;
  #
  certonly)
    certonly $2
    ;;
  #
  yandex-add-record)
    yandex-add-record
    ;;
  #
  yandex-remove-record)
    yandex-remove-record
    ;;
  # Выходим с ошибкой в ином случае
  *)
    usage
    ;;
esac
