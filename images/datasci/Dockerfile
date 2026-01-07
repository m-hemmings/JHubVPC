FROM quay.io/jupyter/datascience-notebook:2025-12-31

USER root

RUN curl -fsSL https://code-server.dev/install.sh | sh

ARG RSTUDIO_SERVER_DEB_URL="https://s3.amazonaws.com/rstudio-ide-build/server/jammy/amd64/rstudio-server-2025.09.2-418-amd64.deb"

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gdebi-core \
      procps \
      psmisc \
      sudo \
      libasound2t64 \
    && curl -fsSL "$RSTUDIO_SERVER_DEB_URL" -o /tmp/rstudio-server.deb \
    && gdebi -n /tmp/rstudio-server.deb \
    && rm -f /tmp/rstudio-server.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# RStudio needs writable state/run/log dirs when started as NB_UID (jovyan)
RUN mkdir -p /var/run/rstudio-server /var/lib/rstudio-server /var/log/rstudio-server \
 && chown -R ${NB_UID}:users /var/run/rstudio-server /var/lib/rstudio-server /var/log/rstudio-server \
 && chmod 775 /var/run/rstudio-server /var/lib/rstudio-server /var/log/rstudio-server

# ✅ This is the actual crash fix: rserver writes here on startup
RUN mkdir -p /home/jovyan/.cache/rstudio /home/jovyan/.local/share/rstudio \
 && chown -R ${NB_UID}:users /home/jovyan/.cache /home/jovyan/.local \
 && chmod -R u+rwX,g+rwX /home/jovyan/.cache /home/jovyan/.local

USER ${NB_UID}

RUN pip install --no-cache-dir \
      jupyter-server-proxy \
      jupyter-vscode-proxy \
      jupyter-rsession-proxy

ENV CODE_WORKINGDIR=/home/jovyan \
    CODE_EXECUTABLE=code-server \
    JUPYTER_RSESSION_PROXY_USE_SOCKET=false
