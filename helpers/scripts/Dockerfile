FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    ffmpeg \
    parallel \
    && rm -rf /var/lib/apt/lists/*

# Copy the script into the container
COPY process_videos.sh /usr/local/bin/process_videos.sh

# Make the script executable
RUN chmod +x /usr/local/bin/process_videos.sh

# Set the entrypoint to the script
ENTRYPOINT ["/usr/local/bin/process_videos.sh"]

# Default command is to process the /data directory
CMD ["/data"]
