FROM ubuntu:24.04

ARG USER=ptr
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ARG PTS_WORK_DIR=/pts

RUN apt-get update && \
  apt-get upgrade && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install \
    apt-file \
    apt-utils \
    autoconf \
    build-essential \
    clang \
    cmake \
    cmake-data \
    curl \
    less \
    libasio-dev \
    libboost-all-dev \
    libboost-iostreams-dev \
    libbrotli-dev \
    libcap2-bin \
    libcurl4-openssl-dev \
    libjpeg-dev \
    libnl-genl-3-dev \
    locales \
    mesa-utils \
    nasm \
    p7zip-full \
    php-cli \
    php-curl \
    php-xml \
    pkg-config \
    sudo \
    tcl \
    tclsh \
    unzip \
    vulkan-tools \
    yasm && \
  apt-get clean autoclean && \
  rm -rf /var/lib/apt/lists/* && \
  localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
  setcap 'cap_sys_nice=eip' /usr/bin/nice

ENV LANG=en_US.utf8

# Disable gcc and g++ from being accessible to the runtime user.
RUN chmod 700 $(readlink -f /usr/bin/g++) && chmod 700 $(readlink -f /usr/bin/gcc)

RUN if [ ${USER_UID} -eq 1000 ]; then userdel -r ubuntu; fi && \
  groupadd -g ${USER_GID} -r ${USER} && \
  useradd -m -u ${USER_UID} -r -g ${USER} -G sudo ${USER} && \
  usermod -p 'R0Vc6SemMBgmQ' ${USER} && \
  printf '#<domain>    <type>  <item>  <value>\n%-12s %-7s %-7s %s\n' \
    "${USER}" \
    "-" \
    "nice" \
    "-20" > /etc/security/limits.d/${USER}-nice-maximum.conf && \
  mkdir ${PTS_WORK_DIR} && \
  chown $USER:$USER ${PTS_WORK_DIR}

WORKDIR /home/$USER
COPY --chown=$USER:$USER user-config.xml .phoronix-test-suite/
COPY --chown=$USER:$USER local-phoronix-run-config.bash .
RUN sed -i -E 's,\$HOME,'${PTS_WORK_DIR}',g' .phoronix-test-suite/user-config.xml && \
    sed -i -E 's,\$HOME,'${PTS_WORK_DIR}',g' local-phoronix-run-config.bash && \
    ln -s /pts/phoronix/test-profiles .phoronix-test-suite/test-profiles && \
    chown -h ${USER_UID}:${USER_GID} .phoronix-test-suite/test-profiles

USER ${USER}
