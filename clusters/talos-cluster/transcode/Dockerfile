FROM alpine:3.20

# Install required packages
RUN apk add --no-cache \
    ffmpeg \
    file \
    bash

# Copy the script into the container
COPY process_videos.sh /usr/local/bin/process_videos.sh

# Make the script executable
RUN chmod +x /usr/local/bin/process_videos.sh

# Set the entrypoint to the script
ENTRYPOINT ["/usr/local/bin/process_videos.sh"]

# Default command is to process the /data directory
CMD ["/data"]
