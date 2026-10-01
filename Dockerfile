# riscv64xO3 RV64IMAC development environment (pinned, reproducible)
# Preferred: docker build -f docker/Dockerfile.dev -t rv64xo3-dev .
# This root Dockerfile is kept for `make docker-build` compatibility.
FROM ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive
ENV VERILATOR_VERSION=5.024 \
    VERIBLE_VERSION=v0.0-3644-g6882622d \
    RISCV_XPACK_VERSION=13.2.0-2

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl wget ca-certificates python3 python3-pip python3-venv \
    autoconf automake libtool flex bison ccache libfl2 libfl-dev zlib1g zlib1g-dev \
    help2man perl device-tree-compiler clang libreadline-dev gawk tcl-dev libffi-dev \
    graphviz pkg-config libboost-system-dev libboost-filesystem-dev ruby nodejs npm \
    sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN git clone --depth 1 --branch v${VERILATOR_VERSION} https://github.com/verilator/verilator.git \
    && cd verilator && autoconf && ./configure && make -j$(nproc) && make install \
    && cd / && rm -rf /tmp/verilator
RUN wget -q https://github.com/chipsalliance/verible/releases/download/v${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz \
    && tar -xzf verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz \
    && cp verible-${VERIBLE_VERSION}/bin/* /usr/local/bin/ \
    && rm -rf verible-${VERIBLE_VERSION}*
RUN wget -q https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v${RISCV_XPACK_VERSION}/xpack-riscv-none-elf-gcc-${RISCV_XPACK_VERSION}-linux-x64.tar.gz \
    && tar -xzf xpack-riscv-none-elf-gcc-${RISCV_XPACK_VERSION}-linux-x64.tar.gz -C /opt \
    && rm xpack-riscv-none-elf-gcc-${RISCV_XPACK_VERSION}-linux-x64.tar.gz
RUN git clone --depth 1 https://github.com/YosysHQ/yosys.git /tmp/yosys \
    && make -C /tmp/yosys config-gcc && make -C /tmp/yosys -j$(nproc) && make -C /tmp/yosys install \
    && rm -rf /tmp/yosys
ENV PATH="/opt/xpack-riscv-none-elf-gcc-${RISCV_XPACK_VERSION}/bin:${PATH}"

COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
USER $USERNAME
WORKDIR /workspace
CMD ["/bin/bash"]
