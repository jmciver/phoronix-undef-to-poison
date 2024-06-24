#!/usr/bin/bash

declare -r USER_UID=$(id -u)
declare -r USER_GID=$(id -g)

docker \
    build \
    --build-arg="USER_UID=${USER_UID}" \
    --build-arg="USER_GID=${USER_GID}" \
    --tag=pts-test:1 .
