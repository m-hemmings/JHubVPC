FROM quay.io/jupyter/datascience-notebook:2025-12-31

USER root

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install RStudio Server via conda-forge
RUN mamba install -y -c conda-forge rstudio-server \
 && mamba clean -a -f -y

USER ${NB_UID}

RUN pip install --no-cache-dir \
      jupyter-server-proxy \
      jupyter-vscode-proxy \
      jupyter-rsession-proxy

ENV CODE_WORKINGDIR=/home/jovyan \
    CODE_EXECUTABLE=code-server \
    JUPYTER_RSESSION_PROXY_USE_SOCKET=true
