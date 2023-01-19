ARG VARIANT="16-buster"
FROM mcr.microsoft.com/vscode/devcontainers/javascript-node:0-${VARIANT}

# [Optional] Uncomment if you want to install an additional version of node using nvm
# ARG EXTRA_NODE_VERSION=10
# RUN su node -c "source /usr/local/share/nvm/nvm.sh && nvm install ${EXTRA_NODE_VERSION}"

# [Optional] Uncomment if you want to install more global node modules
# RUN su node -c "npm install -g <your-package-list-here>"

RUN sudo apt-get update && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y \
    build-essential \
    libssl-dev \
    uuid-dev \
    libgpgme11-dev \
    squashfs-tools \
    libseccomp-dev \
    wget \
    pkg-config \
    git \
    cryptsetup

# install GO
RUN export GOVERSION=1.17.3 OS=linux ARCH=amd64  # change this as you need
RUN sudo rm -rf /usr/local/go

RUN wget -O /tmp/go${GOVERSION}.${OS}-${ARCH}.tar.gz \
  https://dl.google.com/go/go${GOVERSION}.${OS}-${ARCH}.tar.gz
RUN sudo tar -C /usr/local -xzf /tmp/go${GOVERSION}.${OS}-${ARCH}.tar.gz

RUN echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
RUN source ~/.bashrc

# download singularity
RUN git clone https://github.com/hpcng/singularity.git
RUN cd singularity
RUN git checkout v3.8.4


# compile singularity
RUN ./mconfig
RUN cd ./builddir
RUN make
RUN sudo make install
