# Dia TTS Server with CUDA 12.8 / Blackwell (sm_120) support
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1 \
    ffmpeg \
    git \
    python3 \
    python3-pip \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install PyTorch with CUDA 12.8 support (includes sm_120 for Blackwell)
RUN pip3 install --no-cache-dir \
    torch \
    torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

# Install other dependencies
RUN pip3 install --no-cache-dir \
    fastapi \
    uvicorn[standard] \
    numpy \
    soundfile \
    huggingface_hub \
    descript-audio-codec \
    safetensors \
    openai-whisper \
    pydantic \
    python-dotenv \
    Jinja2 \
    python-multipart \
    requests \
    PyYAML \
    tqdm \
    pydub \
    praat-parselmouth \
    librosa \
    hf-transfer

# Clone Dia TTS Server
RUN git clone https://github.com/devnen/Dia-TTS-Server.git /app

# Create required directories
RUN mkdir -p model_cache reference_audio outputs voices

EXPOSE 8003

CMD ["python3", "server.py"]
