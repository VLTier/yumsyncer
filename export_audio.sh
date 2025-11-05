#!/bin/bash

##############################################################################
# Craig Discord Audio Exporter
#
# This script connects to a remote Ubuntu server running Craig Discord bot
# (https://craig.chat) and exports all audio recordings to a local directory.
##############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate required environment variables
if [ -z "$REMOTE_HOST" ]; then
    log_error "REMOTE_HOST environment variable is not set"
    exit 1
fi

if [ -z "$REMOTE_USER" ]; then
    log_error "REMOTE_USER environment variable is not set"
    exit 1
fi

if [ -z "$SSH_KEY_PATH" ] && [ -z "$SSH_PASSWORD" ]; then
    log_error "Either SSH_KEY_PATH or SSH_PASSWORD must be set"
    exit 1
fi

# Set defaults
REMOTE_PORT="${REMOTE_PORT:-22}"
CRAIG_INSTALL_PATH="${CRAIG_INSTALL_PATH:-~/craig}"
CRAIG_REC_PATH="${CRAIG_REC_PATH:-${CRAIG_INSTALL_PATH}/rec}"
EXPORT_PATH="${EXPORT_PATH:-/export}"
AUDIO_EXTENSIONS="${AUDIO_EXTENSIONS:-mp3,wav,ogg,flac,m4a,aac,opus,webm}"
SYNC_INTERVAL="${SYNC_INTERVAL:-3600}"
RUN_ONCE="${RUN_ONCE:-false}"

log_info "Starting Craig Discord Audio Exporter"
log_info "Remote: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}"
log_info "Craig installation: ${CRAIG_INSTALL_PATH}"
log_info "Craig recordings: ${CRAIG_REC_PATH}"
log_info "Export path: ${EXPORT_PATH}"

# Setup SSH key if provided
if [ -n "$SSH_KEY_PATH" ]; then
    log_info "Setting up SSH key authentication"

    if [ ! -f "$SSH_KEY_PATH" ]; then
        log_error "SSH key file not found at: $SSH_KEY_PATH"
        exit 1
    fi

    # Copy key to standard location and set permissions
    cp "$SSH_KEY_PATH" /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa

    SSH_OPTIONS="-i /root/.ssh/id_rsa"
else
    log_warn "SSH password authentication is less secure. Consider using SSH keys."
    SSH_OPTIONS=""
fi

# Common SSH options
SSH_OPTIONS="$SSH_OPTIONS -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

# Function to test SSH connection
test_ssh_connection() {
    log_info "Testing SSH connection..."

    if [ -n "$SSH_PASSWORD" ]; then
        log_error "Password authentication not supported in this version. Please use SSH key authentication."
        exit 1
    fi

    if ssh $SSH_OPTIONS -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "echo 'Connection successful'" > /dev/null 2>&1; then
        log_info "SSH connection successful"
        return 0
    else
        log_error "SSH connection failed"
        return 1
    fi
}

# Function to find audio files on remote server
find_audio_files() {
    log_info "Searching for audio files on remote server..."

    # Build find command with all extensions
    IFS=',' read -ra EXTENSIONS <<< "$AUDIO_EXTENSIONS"
    FIND_CMD="find ${CRAIG_REC_PATH} -type f \\( "

    for i in "${!EXTENSIONS[@]}"; do
        ext="${EXTENSIONS[$i]}"
        if [ $i -gt 0 ]; then
            FIND_CMD="$FIND_CMD -o "
        fi
        FIND_CMD="$FIND_CMD -iname '*.${ext}'"
    done

    FIND_CMD="$FIND_CMD \\) 2>/dev/null"

    # Execute find command on remote server
    AUDIO_FILES=$(ssh $SSH_OPTIONS -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "$FIND_CMD")

    if [ -z "$AUDIO_FILES" ]; then
        log_warn "No audio files found on remote server"
        return 1
    fi

    FILE_COUNT=$(echo "$AUDIO_FILES" | wc -l)
    log_info "Found $FILE_COUNT audio file(s)"

    return 0
}

# Function to export audio files using rsync
export_audio_files() {
    log_info "Starting audio file export..."

    # Create export directory if it doesn't exist
    mkdir -p "$EXPORT_PATH"

    # Use rsync to efficiently copy files
    # -a: archive mode (preserves permissions, timestamps, etc.)
    # -v: verbose
    # -z: compress during transfer
    # -h: human-readable
    # --progress: show progress
    # --include: include specific file types
    # --exclude: exclude everything else initially

    # Build rsync filter rules
    IFS=',' read -ra EXTENSIONS <<< "$AUDIO_EXTENSIONS"
    RSYNC_FILTERS=""
    for ext in "${EXTENSIONS[@]}"; do
        RSYNC_FILTERS="$RSYNC_FILTERS --include=**/*.${ext} --include=**/*.${ext^^}"
    done
    RSYNC_FILTERS="$RSYNC_FILTERS --include=*/ --exclude=*"

    log_info "Syncing files with rsync..."

    if rsync -avzh --progress \
        -e "ssh $SSH_OPTIONS -p $REMOTE_PORT" \
        $RSYNC_FILTERS \
        "${REMOTE_USER}@${REMOTE_HOST}:${CRAIG_REC_PATH}/" \
        "$EXPORT_PATH/"; then

        log_info "Export completed successfully"

        # Count exported files
        EXPORTED_COUNT=$(find "$EXPORT_PATH" -type f | wc -l)
        EXPORTED_SIZE=$(du -sh "$EXPORT_PATH" | cut -f1)

        log_info "Total files exported: $EXPORTED_COUNT"
        log_info "Total size: $EXPORTED_SIZE"

        return 0
    else
        log_error "Export failed"
        return 1
    fi
}

# Function to create a summary report
create_report() {
    REPORT_FILE="$EXPORT_PATH/export_report.txt"

    log_info "Creating export report..."

    cat > "$REPORT_FILE" << EOF
Craig Discord Audio Export Report
==================================
Generated: $(date)

Server Information:
- Host: ${REMOTE_HOST}:${REMOTE_PORT}
- User: ${REMOTE_USER}
- Craig Installation: ${CRAIG_INSTALL_PATH}
- Craig Recordings: ${CRAIG_REC_PATH}

Export Information:
- Export Path: ${EXPORT_PATH}
- Total Files: $(find "$EXPORT_PATH" -type f ! -name "export_report.txt" | wc -l)
- Total Size: $(du -sh "$EXPORT_PATH" | cut -f1)

File Types:
EOF

    # Add file type breakdown
    IFS=',' read -ra EXTENSIONS <<< "$AUDIO_EXTENSIONS"
    for ext in "${EXTENSIONS[@]}"; do
        count=$(find "$EXPORT_PATH" -type f -iname "*.${ext}" | wc -l)
        if [ $count -gt 0 ]; then
            echo "- .${ext}: $count file(s)" >> "$REPORT_FILE"
        fi
    done

    log_info "Report saved to: $REPORT_FILE"
}

# Main execution loop
main() {
    # Test connection first
    if ! test_ssh_connection; then
        log_error "Unable to establish SSH connection. Exiting."
        exit 1
    fi

    while true; do
        START_TIME=$(date +%s)
        log_info "=== Starting export cycle at $(date) ==="

        # Find and export audio files
        if find_audio_files; then
            if export_audio_files; then
                create_report
                log_info "Export cycle completed successfully"
            else
                log_error "Export cycle failed"
            fi
        else
            log_warn "No files to export"
        fi

        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        log_info "Cycle duration: ${DURATION} seconds"

        # Check if we should run only once
        if [ "$RUN_ONCE" = "true" ]; then
            log_info "RUN_ONCE is set to true. Exiting."
            exit 0
        fi

        # Wait for next sync interval
        log_info "Waiting ${SYNC_INTERVAL} seconds until next sync..."
        log_info "=== Next sync scheduled at $(date -d "@$(($(date +%s) + SYNC_INTERVAL))") ==="
        sleep "$SYNC_INTERVAL"
    done
}

# Run main function
main
