FROM ubuntu:24.04

ARG USER=ubuntu

ARG PTS_WORK_DIR=/pts
# The trailing slash is necessary.
ARG PTS_USER_PATH_OVERRIDE=/pts/pts-home/

# NOTE 1: the setcap operator flag options "eip" stand for effective,
# inheritable and permitted. When the container is run with capability (cap_add)
# SYS_NICE, then process niceness is honored.

# NOTE 2: packages rec2, z3, and libz3-dev are added for Alive2 build
# support.

RUN apt-get update && \
  apt-get -y upgrade && \
  DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    apt-file \
    apt-utils \
    autoconf \
    bison \
    build-essential \
    clang \
    cmake \
    cmake-data \
    curl \
    fftw-dev \
    flex \
    git \
    less \
    libasio-dev \
    libboost-all-dev \
    libboost-iostreams-dev \
    libbrotli-dev \
    libcap2-bin \
    libcurl4-openssl-dev \
    libfftw3-dev \
    libfindbin-libs-perl \
    libfreetype6-dev \
    libjpeg-dev \
    libnl-genl-3-dev \
    libzstd-dev \
    linux-tools-common \
    linux-tools-generic \
    locales \
    mesa-utils \
    nasm \
    ninja-build \
    p7zip-full \
    php-cli \
    php-curl \
    php-xml \
    pkg-config \
    python3 \
    python3-pip \
    python3-psutil \
    python3-yaml \
    re2c \
    tcl \
    tclsh \
    unzip \
    vulkan-tools \
    xorg-dev \
    yasm \
    zlib1g-dev && \
  apt-get clean autoclean && \
  rm -rf /var/lib/apt/lists/* && \
  localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
  setcap 'cap_sys_nice=eip' /usr/bin/nice

ENV LANG=en_US.utf8
ENV PTS_USER_PATH_OVERRIDE=$PTS_USER_PATH_OVERRIDE

# Disable gcc and g++ from being accessible to the runtime user.
RUN chmod 700 $(readlink -f /usr/bin/g++) && chmod 700 $(readlink -f /usr/bin/gcc)

RUN mkdir ${PTS_WORK_DIR} && chown $USER:$USER ${PTS_WORK_DIR}

WORKDIR /home/$USER
COPY --chown=$USER:$USER user-config.xml .
COPY --chown=$USER:$USER local-phoronix-run-config.bash .
COPY --chown=$USER:$USER CMakePresetsLLVM.json .
COPY --chown=$USER:$USER CMakePresetsAlive2.json .
COPY --chown=$USER:$USER CMakePresetsZ3.json .
COPY --chown=$USER:$USER build-and-run.bash .
RUN sed -i -E 's,\$HOME,'${PTS_WORK_DIR}',g' user-config.xml && \
    sed -i -E 's,\$HOME,'${PTS_WORK_DIR}',g' local-phoronix-run-config.bash

USER ${USER}
ENTRYPOINT ["./build-and-run.bash"]
