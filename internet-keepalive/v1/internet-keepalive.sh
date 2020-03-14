#!/usr/bin/env bash
function usage {
  echo '# Основная функция скрипта - автоматически переключает маршрут по умолчанию при падении основного провайдера.'
  echo 'internet-keepalive.sh'
  echo '# Добавь в cron - например так:'
  echo '* * * * * root /usr/local/bin/internet-keepalive.sh'
  echo 'Используемые функции:'
  echo '# Меняет маршрут по умолчанию на работу через основного провайдера и добавляет флаг ручного управления'
  echo 'internet-keepalive.sh manual_activate_primary_provider'
  echo '# Меняет маршрут по умолчанию на работу через резервного провайдера и добавляет флаг ручного управления'
  echo 'internet-keepalive.sh manual_activate_secondary_provider'
  echo '# Удаляет флаг управления маршрутом по умолчанию(основная функция скрипта начинает работать)'
  echo 'internet-keepalive.sh disable_manual_internet_control'
}
# Инициализируем Переменные
# Имя основного провайдера
PRIMARY_PROVIDER_NAME="PRIMARY"
# Имя резервного провайдера
SECONDARY_PROVIDER_NAME="SECONDARY"
# Массив содержащий IP адреса до которых будет выполнен ping
HOSTS=( 8.8.8.8 8.8.4.4 77.88.8.8 1.1.1.1 ) #
# Количество проверок с помощью ping
PING_COUNT="4"
# Минимальное количество живых хостов
MINIMUM_ALIVE_HOSTS="3"
# Сетевой интерфейс основного провайдера
P_IF=""
# Сетевой интерфейс резервного провайдера
S_IF=""
# IP адреса шлюза основного провайдера
P_GW=""
# IP адреса шлюза резервного провайдера
S_GW=""
# Метрика для маршрутов до $HOSTS
METRIC="0"
# Метрика для маршрута по умолчанию
DEFAULT_METRIC="10"
# Файл-флаг. Появляется при переключении на резервный канал
LOCKFILE="/tmp/internet-keepalive.lock"
# Флаг ручного управления маршрутом
MANUAL_INET_CONTROL_FLAG="/var/tmp/manual_inet_control_flag"
# Файл журнала
LOGFILE="/var/log/internet-keepalive.log"
function check_default_route {
  DEFAULT_ROUTE_EXIST=`ip route | grep default | wc -l`
}
function enable_manual_internet_control {
  touch ${MANUAL_INET_CONTROL_FLAG}
}
function disable_manual_internet_control {
  rm -f ${MANUAL_INET_CONTROL_FLAG}
}
function check_manual_control {
  # Проверка на наличие флага ручного управления интернетом
  if [ -f ${MANUAL_INET_CONTROL_FLAG} ]; then
      exit 1
  fi
}
function check_internet_state {
  local HOSTS_ALIVE="0"
  for HOST in ${HOSTS[*]}
  do
    ip route add $HOST via $P_GW dev $P_IF metric $METRIC &> /dev/null
    ping -I $P_IF -c${PING_COUNT} ${HOST} > /dev/null 2>&1
    if [ $? -eq "0" ]; then
      ((HOST_ALIVE++))
      HOST_ALIVE_RESULT=${HOST_ALIVE}
    fi
    ip route del $HOST via $P_GW dev $P_IF metric $METRIC &> /dev/null
  done
  if [[ ${HOST_ALIVE_RESULT} -lt ${MINIMUM_ALIVE_HOSTS} ]]; then
    INET_STATE=0
  else
    INET_STATE=1
  fi
}
function activate_primary_provider {
  # Меняем маршрут по умолчанию в основой таблице роутинга
  ip route del default &> /dev/null
  ip route add default via $P_GW dev $P_IF metric $DEFAULT_METRIC &> /dev/null
  ip route flush cache &> /dev/null
  # Удаляем файл-флаг
  rm -f ${LOCKFILE}
  # Записываем событие в файл журнала
  echo "`date +'%Y/%m/%d %H:%M:%S'` Основной маршрут был изменен на работу с ${PRIMARY_PROVIDER_NAME}" >> ${LOGFILE}
}
function activate_secondary_provider {
  # Меняем маршрут по умолчанию в основной таблице роутинга
  ip route del default &> /dev/null
  ip route add default via ${S_GW} dev ${S_IF} metric $DEFAULT_METRIC &> /dev/null
  ip route flush cache &> /dev/null
  # Создаём файл флаг
  touch ${LOCKFILE}
  # Делаем запись в файл журнала
  echo "`date +'%Y/%m/%d %H:%M:%S'` Основной маршрут был изменен на работу с ${SECONDARY_PROVIDER_NAME}" >> ${LOGFILE}
}
function manual_activate_primary_provider {
  enable_manual_internet_control
  activate_primary_provider
}
function manual_activate_secondary_provider {
  enable_manual_internet_control
  activate_secondary_provider
}
function internet-keepalive {
  # Проверяем не управляется ли переключение интернета вручную
  check_manual_control
  # Проверяем существуют ли статические маршруты до проверяемых хостов - если нет, добавляем.
  check_internet_state
  # Основной провайдер работает, текущий провайдер - резервный -> переключаемся на основного провайдера.
  if [ $INET_STATE -eq "1" ] && [ -f ${LOCKFILE} ] ; then
    activate_primary_provider
    # Дополнительные команды
    # asterisk -rx "core reload"
  fi
  # Основной провайдер не работает, текущий провайдер - основной -> переключаемся на резервного провайдера.
  if [ $INET_STATE -eq "0" ] && [ ! -f ${LOCKFILE} ] ; then
    activate_secondary_provider
    # Дополнительные команды
    # asterisk -rx "core reload"
  fi
  # # Основной провайдер работает, текущий провайдер - основной
  # if [ $INET_STATE == "1" ] && [ ! -f ${LOCKFILE} ] ; then
  # fi
  # # Основной провайдер не работает, текущий провайдер - резервный
  # if [ $INET_STATE == "0" ] && [ -f ${LOCKFILE} ] ; then
  # fi
  # Проверяем существует ли маршрут по умолчанию.
  check_default_route
  # Если нет маршрута по умолчанию - используем основного провайдера.
  if [[ ${DEFAULT_ROUTE_EXIST} -eq 0 ]]; then
    activate_primary_provider
    exit 0
  fi
}
# Если не было передано аргументов - выполняем основную функцию скрипта.
if [[ $# -eq 0 ]]; then
  internet-keepalive
fi
# Если аргументы были переданы - используем case
case "$1" in
  # Выводим справку по запросу
  -h | --help)
    usage
    exit 0
    ;;
  # Принудительно используем основного провайдера
  manual_activate_primary_provider)
    manual_activate_primary_provider
    ;;
  # Принудительно используем резервного провайдера
  manual_activate_secondary_provider)
    manual_activate_secondary_provider
    ;;
  # Удаляем флаг ручного управления
  disable_manual_internet_control)
    disable_manual_internet_control
    ;;
  # Выходим с ошибкой в ином случае
  *)
    exit 1
    ;;
esac
