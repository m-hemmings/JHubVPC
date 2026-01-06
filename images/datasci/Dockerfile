FROM quay.io/jupyter/datascience-notebook:2025-12-31

USER root

RUN curl -fsSL https://code-server.dev/install.sh | sh

ARG RSTUDIO_SERVER_DEB_URL="https://s3.amazonaws.com/rstudio-ide-build/server/jammy/amd64/rstudio-server-2025.09.2-418-amd64.deb"

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gdebi-core \
      psmisc \
      procps \
      libssl3 \
      libclang-dev \
      libpq5 \
      sudo \
    && curl -fsSL "$RSTUDIO_SERVER_DEB_URL" -o /tmp/rstudio-server.deb \
    && gdebi -n /tmp/rstudio-server.deb \
    && rm -f /tmp/rstudio-server.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER ${NB_UID}

# --- Jupyter proxy integrations ---
RUN pip install --no-cache-dir \
      jupyter-server-proxy \
      jupyter-vscode-proxy \
      jupyter-rsession-proxy

ENV CODE_WORKINGDIR=/home/jovyan \
    CODE_EXECUTABLE=code-server \
    JUPYTER_RSESSION_PROXY_USE_SOCKET=true
