FROM ubuntu:24.04

ARG USER=ptr
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN apt-get update && \
  apt-get upgrade && \
  apt-get -y install \
    php-cli \
    php-xml \
    php-curl \
    sudo && \
  apt-get clean autoclean

RUN if [ ${USER_UID} -eq 1000 ]; then userdel -r ubuntu; fi && \
  groupadd -g ${USER_GID} -r ${USER} && \
  useradd -m -u ${USER_UID} -r -g ${USER} -G sudo ${USER} && \
  mkdir -p /home/${USER}/phoronix && \
  usermod -p 'R0Vc6SemMBgmQ' ${USER} && \
  printf '#<domain>    <type>  <item>  <value>\n%-12s %-7s %-7s %s\n' \
    "${USER}" \
    "-" \
    "nice" \
    "-20" > /etc/security/limits.d/${USER}-nice-maximum.conf

USER ${USER}
WORKDIR /home/$USER
