#!/usr/bin/bash

docker \
    run \
    -it \
    --rm \
    --cap-add SYS_NICE \
    --mount type=bind,source="$(pwd)",target="/pts/phoronix" \
    --mount type=bind,source="/tmp/pts-install",target="/pts/pts-install" \
    pts-test:1
