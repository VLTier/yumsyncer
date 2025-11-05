FROM alpine:latest

# Install required packages
RUN apk add --no-cache \
    bash \
    openssh-client \
    rsync \
    tzdata

# Create necessary directories
RUN mkdir -p /root/.ssh /export /scripts

# Copy the export script
COPY export_audio.sh /scripts/export_audio.sh
RUN chmod +x /scripts/export_audio.sh

# Set working directory
WORKDIR /scripts

# Default command
CMD ["/scripts/export_audio.sh"]
