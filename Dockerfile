# IronCore RV32IM Development Environment
# Pinned tool versions for reproducibility

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Tool versions
ENV VERILATOR_VERSION=5.024
ENV VERIBLE_VERSION=0.0-3644-g6882622d

# Install base dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-venv \
    autoconf \
    automake \
    libtool \
    flex \
    bison \
    ccache \
    libfl2 \
    libfl-dev \
    zlib1g \
    zlib1g-dev \
    help2man \
    perl \
    perl-doc \
    gtkwave \
    device-tree-compiler \
    default-jre \
    clang \
    libreadline-dev \
    gawk \
    tcl-dev \
    libffi-dev \
    graphviz \
    xdot \
    pkg-config \
    libboost-system-dev \
    libboost-python-dev \
    libboost-filesystem-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Verilator from source (pinned version)
WORKDIR /tmp
RUN git clone https://github.com/verilator/verilator.git && \
    cd verilator && \
    git checkout v${VERILATOR_VERSION} && \
    autoconf && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/verilator

# Install Verible (linter/formatter)
RUN wget -q https://github.com/chipsalliance/verible/releases/download/v${VERIBLE_VERSION}/verible-v${VERIBLE_VERSION}-linux-static-x86_64.tar.gz && \
    tar -xzf verible-v${VERIBLE_VERSION}-linux-static-x86_64.tar.gz && \
    cp verible-v${VERIBLE_VERSION}/bin/* /usr/local/bin/ && \
    rm -rf verible-v${VERIBLE_VERSION}*

# Install RISC-V GNU Toolchain (prebuilt)
    RUN wget -q https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v13.2.0-2/xpack-riscv-none-elf-gcc-13.2.0-2-linux-x64.tar.gz && \
        tar -xzf xpack-riscv-none-elf-gcc-13.2.0-2-linux-x64.tar.gz -C /opt && \
        rm xpack-riscv-none-elf-gcc-13.2.0-2-linux-x64.tar.gz

# Install Yosys from source
RUN git clone https://github.com/YosysHQ/yosys.git /tmp/yosys && \
    cd /tmp/yosys && \
    make config-gcc && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/yosys

ENV PATH="/opt/xpack-riscv-none-elf-gcc-13.2.0-2/bin:${PATH}"

# Install Python packages
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# Create non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    apt-get update && apt-get install -y sudo && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
WORKDIR /workspace

CMD ["/bin/bash"]
