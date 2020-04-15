#!/usr/bin/env bash
# Если свободное место в каталоге где хранятся записи asterisk меньше n GB - удаляем m самых старых записей.
# Имеет смысл добавить в cron
# Примерно так:
# */5 * * * * root /usr/local/bin/asterisk_ord_record_flush.sh
MONITOR_PATH='/var/spool/asterisk/monitor/'
FREE_SPACE_IN_MONITOR_PATH=$(df -BG ${MONITOR_PATH} | tr -s ' ' | grep -v 'Filesystem' | cut -d' ' -f 4 | tr -dc '0-9')
MINIMAL_FREE_SPACE_IN_GB='5'
REMOVE_RECORD_COUNT='100'
if [[ ${FREE_SPACE_IN_MONITOR_PATH} -le ${MINIMAL_FREE_SPACE_IN_GB} ]]; then
  rm -f "$(find ${MONITOR_PATH} -type f | sort | head -n ${REMOVE_RECORD_COUNT} | tr '\n' ' ')"
fi
