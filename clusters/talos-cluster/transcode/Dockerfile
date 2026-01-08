FROM nvidia/cuda:12.3.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,video,utility

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    ffmpeg \
    file \
    && rm -rf /var/lib/apt/lists/*

COPY process_videos.py /usr/local/bin/process_videos.py
RUN chmod +x /usr/local/bin/process_videos.py

ENTRYPOINT ["python3", "/usr/local/bin/process_videos.py"]
CMD ["/data"]
