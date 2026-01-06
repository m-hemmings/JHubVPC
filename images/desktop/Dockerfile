FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:1 \
    VNC_PORT=5901 \
    NOVNC_PORT=6901 \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1600x900 \
    VNC_PW=changeme

RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-terminal dbus-x11 x11-xserver-utils xauth \
    tigervnc-standalone-server tigervnc-common \
    novnc websockify \
    ca-certificates curl sudo tini \
    python3 python3-pip \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir jupyter-server-proxy

ARG USERNAME=jovyan
ARG UID=1000
ARG GID=100

RUN set -eux; \
    EXISTING_GROUP="$(getent group ${GID} | cut -d: -f1 || true)"; \
    if [ -n "${EXISTING_GROUP}" ]; then \
        GROUP_NAME="${EXISTING_GROUP}"; \
    else \
        GROUP_NAME="${USERNAME}"; \
        groupadd -g "${GID}" "${GROUP_NAME}"; \
    fi; \
    useradd -m -s /bin/bash -u "${UID}" -g "${GID}" "${USERNAME}"; \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"


COPY start-desktop.sh /usr/local/bin/start-desktop.sh
RUN chmod +x /usr/local/bin/start-desktop.sh

USER ${USERNAME}
WORKDIR /home/${USERNAME}

EXPOSE 6901 5901

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/local/bin/start-desktop.sh"]
