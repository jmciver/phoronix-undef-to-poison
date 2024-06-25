#!/usr/bin/bash

declare -r PTS_INSTALL="/tmp/pts-install"

if [ ! -d "$PTS_INSTALL" ]; then
    printf "INFO: making pts install/build directory %s\n" "$PTS_INSTALL"
    mkdir -p "$PTS_INSTALL" || exit 1
fi

docker \
    run \
    -it \
    --rm \
    --cap-add SYS_NICE \
    --mount type=bind,source="$(pwd)",target="/pts/phoronix" \
    --mount type=bind,source="$PTS_INSTALL",target="/pts/pts-install" \
    pts-test:1
