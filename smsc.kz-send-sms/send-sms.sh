#!/usr/bin/env bash
# Пример использования
function usage {
  echo -e "Пример использования:\n$0"' $1 - номер телефона $2 - текст сообщения в кавычках'
}
# Если не передано двух аргументов - показываем пример использования
if [ $# -ne 2 ]; then
  usage
  exit 1
fi
# Инициализируем переменные
LOGIN=''
PASSWORD=''
ID=''
NAME=''
PHONE_NUMBER=$1
MESSAGE=$2
# Отправка SMS
curl "https://smsc.kz/sys/send.php?login=$LOGIN&psw=$PASSWORD&phones=$PHONE_NUMBER&mes=$MESSAGE&translit=0&id=$ID&name=$NAME"
