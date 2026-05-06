FROM nvidia/cuda:12.8.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    curl \
    ca-certificates \
    git \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1 \
    libibverbs-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade pip setuptools wheel && \
    python3 -m pip install \
    https://github.com/vllm-project/vllm/releases/download/v0.14.0/vllm-0.14.0-cp38-abi3-manylinux_2_31_x86_64.whl \
    --extra-index-url https://download.pytorch.org/whl/cu128

EXPOSE 8001

ENTRYPOINT ["vllm"]
