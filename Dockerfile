FROM debian:stable-20251117-slim

SHELL ["/bin/bash", "-e", "-u", "-o", "pipefail", "-c"]

ARG TINI_VERSION=v0.19.0
## We always want the latest rsync version
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
    ca-certificates \
    curl \
    gettext-base \
    rsync \
    openssh-server \
    && curl --silent --show-error --location --output /bin/tini \
    "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-$(dpkg --print-architecture)" \
    && chmod +x /bin/tini \
    && apt-get remove --purge --yes ca-certificates curl \
    && apt-get autoremove --purge --yes \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ARG user=rsyncd
ARG group=rsyncd
ARG uid=1000
ARG gid=1000
ARG user_home="/home/${user}"
ENV USER_ETC_DIR="${user_home}/etc"
ENV HOST_KEYS_DIR="${USER_ETC_DIR}/keys"
ENV USER_RUN_DIR="${user_home}/run"

RUN groupadd -g ${gid} ${group} \
    && useradd -l -d "${user_home}" -u "${uid}" -g "${gid}" -m -s /bin/bash "${user}" \
    && mkdir -p "${user_home}"/.ssh "${user_home}"/data "${USER_RUN_DIR}" "${USER_ETC_DIR}"/rsyncd.d "${USER_ETC_DIR}"/keys

COPY rsyncd.conf "${user_home}"/etc/rsyncd.conf.orig
COPY sshd_config "${user_home}"/etc/sshd_config.orig
COPY entrypoint.sh /entrypoint.sh
COPY ssh-rsync-wrapper.sh /ssh-rsync-wrapper.sh

RUN chown -R "${uid}:${gid}" "${user_home}" \
    && sed -i '/pam_motd/s/^/#/' /etc/pam.d/sshd

ENV SSHD_PORT=22
ENV RSYNCD_PORT=873

WORKDIR "${user_home}"/data

VOLUME "${user_home}" "/tmp"

EXPOSE $RSYNCD_PORT $SSHD_PORT

USER $user

# Change it to 'sshd' to use rsync over SSH instead of rsyncd
ENV RSYNCD_DAEMON="rsyncd"

ENV SSHD_LOG_LEVEL="INFO"

ENTRYPOINT ["/bin/tini","--"]

CMD ["/entrypoint.sh"]
