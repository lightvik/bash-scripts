#!/usr/bin/env bash

# Выводит буквенно-цифровой пароль (нижний и верхний регистр), где fold задает длину, а head выбирает количество строк с паролем.
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
# Выводит буквенно-цифровой пароль (только нижний регистр), где fold задает длину, а head выбирает количество строк с паролем.
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
# Число от 0 до 9
cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | head --bytes 1
# Число от 0 до n разрядов где n = количество байт
cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 2
