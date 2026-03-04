# ── GPU Build (default): Cloud Run with NVIDIA L4 ──
# docker build -t minton-smash-cv:gpu .
#
# ── CPU Build (dev/testing): no GPU needed ──
# docker build --build-arg BASE_IMAGE=python:3.11-slim --build-arg PYTORCH_EXTRA_INDEX="" -t minton-smash-cv:cpu .

ARG BASE_IMAGE=nvidia/cuda:12.1.1-runtime-ubuntu22.04
FROM ${BASE_IMAGE}

# Prevent interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    python3-pip \
    libgl1 \
    libglib2.0-0 \
    ffmpeg \
    curl \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch with CUDA support first (large layer, cached separately)
ARG PYTORCH_EXTRA_INDEX=--extra-index-url https://download.pytorch.org/whl/cu121
RUN pip install --no-cache-dir ${PYTORCH_EXTRA_INDEX} \
    torch==2.2.2 \
    torchvision==0.17.2

# Install remaining requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create models directory (weights downloaded separately or mounted)
RUN mkdir -p /app/models

COPY . .

# Cloud Run injects PORT environment variable
ENV PORT=8080

# Health check for Cloud Run
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
    CMD curl -f http://localhost:${PORT}/health || exit 1

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port $PORT"]
