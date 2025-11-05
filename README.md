# Borg Discord Audio Exporter

A Docker-based solution to automatically connect to a remote Ubuntu server running Borg Discord Listener and export all audio recordings to a local directory.

## Overview

This tool connects to your remote Ubuntu server via SSH, locates audio files from your Borg Discord bot installation, and synchronizes them to a local directory using rsync. It can run continuously with scheduled syncs or execute once on-demand.

## Features

- **Automated SSH Connection**: Securely connects to remote servers using SSH key authentication
- **Intelligent Audio Detection**: Automatically finds all audio files based on configurable extensions
- **Efficient Syncing**: Uses rsync for bandwidth-efficient file transfers
- **Continuous or One-time Sync**: Supports both scheduled recurring syncs and one-time exports
- **Progress Tracking**: Real-time progress reporting during file transfers
- **Export Reports**: Generates detailed reports of exported files
- **Docker-based**: Easy deployment with Docker Compose
- **Configurable**: Fully customizable via environment variables

## Prerequisites

- Docker and Docker Compose installed on your local machine
- A remote Ubuntu server with Borg Discord Listener installed
- SSH access to the remote server with key-based authentication
- SSH private key file accessible on your local machine

## Quick Start

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd yumsyncer
```

### 2. Configure Environment Variables

Copy the example environment file and configure it:

```bash
cp .env.example .env
```

Edit `.env` with your settings:

```bash
nano .env
```

### 3. Prepare SSH Key

Ensure your SSH private key has the correct permissions:

```bash
chmod 600 /path/to/your/ssh/key
```

### 4. Run with Docker Compose

```bash
docker-compose up -d
```

### 5. Check Logs

```bash
docker-compose logs -f
```

### 6. Stop the Container

```bash
docker-compose down
```

## Configuration

All configuration is done through environment variables in the `.env` file:

### Required Settings

| Variable | Description | Example |
|----------|-------------|---------|
| `REMOTE_HOST` | Remote server hostname or IP | `192.168.1.100` or `server.example.com` |
| `REMOTE_USER` | SSH username | `ubuntu` |
| `SSH_KEY_HOST_PATH` | Path to SSH private key on host | `/home/user/.ssh/id_rsa` |

### Optional Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `REMOTE_PORT` | `22` | SSH port |
| `BORG_INSTALL_PATH` | `~/borg-discord` | Path to Borg installation on remote server |
| `EXPORT_HOST_PATH` | `./export` | Local directory for exported files |
| `AUDIO_EXTENSIONS` | `mp3,wav,ogg,flac,m4a,aac,opus,webm` | File extensions to export |
| `SYNC_INTERVAL` | `3600` | Time between syncs (seconds) |
| `RUN_ONCE` | `false` | Run once and exit (`true`/`false`) |
| `TZ` | `UTC` | Container timezone |

## Usage Examples

### Continuous Sync (Default)

Runs continuously, syncing every hour (3600 seconds):

```bash
# In .env file:
SYNC_INTERVAL=3600
RUN_ONCE=false

docker-compose up -d
```

### One-time Export

Run once and exit:

```bash
# In .env file:
RUN_ONCE=true

docker-compose up
```

### Custom Sync Interval

Sync every 30 minutes (1800 seconds):

```bash
# In .env file:
SYNC_INTERVAL=1800

docker-compose up -d
```

### Custom Borg Installation Path

If Borg is installed in a custom location:

```bash
# In .env file:
BORG_INSTALL_PATH=/opt/borg-discord

docker-compose up -d
```

### Export Specific Audio Formats

Export only MP3 and WAV files:

```bash
# In .env file:
AUDIO_EXTENSIONS=mp3,wav

docker-compose up -d
```

## Directory Structure

```
.
├── Dockerfile              # Docker image configuration
├── docker-compose.yml      # Docker Compose configuration
├── export_audio.sh         # Main export script
├── .env.example            # Example environment configuration
├── .env                    # Your actual configuration (create this)
└── export/                 # Exported audio files (created automatically)
    └── export_report.txt   # Export summary report
```

## Export Report

After each sync, a report is generated at `export/export_report.txt` containing:

- Sync timestamp
- Server information
- Total files and size exported
- Breakdown by file type

Example report:

```
Borg Discord Audio Export Report
=================================
Generated: Mon Nov 5 10:00:00 UTC 2025

Server Information:
- Host: 192.168.1.100:22
- User: ubuntu
- Borg Path: ~/borg-discord

Export Information:
- Export Path: /export
- Total Files: 42
- Total Size: 1.2G

File Types:
- .mp3: 30 file(s)
- .wav: 10 file(s)
- .opus: 2 file(s)
```

## Troubleshooting

### SSH Connection Failed

**Problem**: Container logs show "SSH connection failed"

**Solutions**:
- Verify `REMOTE_HOST`, `REMOTE_USER`, and `REMOTE_PORT` are correct
- Ensure SSH key path is correct and accessible
- Check SSH key permissions: `chmod 600 /path/to/key`
- Test SSH connection manually: `ssh -i /path/to/key user@host`
- Verify the remote server is accessible from your network

### No Audio Files Found

**Problem**: Logs show "No audio files found on remote server"

**Solutions**:
- Verify `BORG_INSTALL_PATH` points to correct directory
- Check that Borg Discord bot has actually recorded audio files
- SSH into the server and verify files exist: `find ~/borg-discord -type f -name "*.mp3"`
- Ensure the remote user has read permissions for the Borg directory

### Permission Denied

**Problem**: "Permission denied" errors during sync

**Solutions**:
- Ensure remote user has read access to Borg directory
- Check SSH key is authorized on remote server (`~/.ssh/authorized_keys`)
- Verify SSH key permissions on local machine: `chmod 600 /path/to/key`

### Container Exits Immediately

**Problem**: Container starts and exits right away

**Solutions**:
- Check logs: `docker-compose logs`
- Verify all required environment variables are set in `.env`
- Ensure `.env` file exists in the same directory as `docker-compose.yml`
- Check for syntax errors in `.env` file

### Export Directory Permission Issues

**Problem**: Cannot write to export directory

**Solutions**:
- Ensure export directory exists and is writable
- Check directory permissions: `chmod 755 ./export`
- If using a custom path, ensure parent directories exist

## Advanced Usage

### Building the Image Manually

```bash
docker build -t borg-audio-exporter .
```

### Running Without Docker Compose

```bash
docker run -d \
  --name borg-audio-exporter \
  -v /path/to/ssh/key:/ssh/id_rsa:ro \
  -v ./export:/export \
  -e REMOTE_HOST=your.server.com \
  -e REMOTE_USER=ubuntu \
  -e SSH_KEY_PATH=/ssh/id_rsa \
  borg-audio-exporter
```

### Running Script Directly

If you prefer to run the script without Docker:

```bash
chmod +x export_audio.sh

# Set environment variables
export REMOTE_HOST=your.server.com
export REMOTE_USER=ubuntu
export SSH_KEY_PATH=/path/to/key
export BORG_INSTALL_PATH=~/borg-discord
export EXPORT_PATH=./export

# Run script
./export_audio.sh
```

Requirements:
- bash
- openssh-client
- rsync

### Scheduling with Cron

To run exports via cron instead of continuous mode:

```bash
# Set RUN_ONCE=true in .env
# Add to crontab (runs every hour):
0 * * * * cd /path/to/yumsyncer && docker-compose up
```

## Security Considerations

- **SSH Keys**: Always use SSH key authentication instead of passwords
- **Key Permissions**: Keep SSH private keys secure with `chmod 600`
- **Network Security**: Consider using VPN or SSH tunneling for remote connections
- **Read-Only Mounts**: SSH key is mounted read-only in the container
- **Minimal Permissions**: Remote user should have only read access to Borg directory

## Borg Discord Listener Setup

This tool assumes Borg Discord Listener is installed on your remote Ubuntu server. If you haven't installed it yet:

1. SSH into your Ubuntu server
2. Follow the official Borg Discord installation guide
3. Note the installation directory (typically in home directory)
4. Ensure the bot is configured and recording audio

## Support and Contributions

For issues, questions, or contributions, please open an issue or pull request on the repository.

## License

This project is provided as-is without warranty. Use at your own risk.

## Changelog

### Version 1.0.0
- Initial release
- SSH-based connection to remote server
- Rsync file synchronization
- Configurable sync intervals
- Export reporting
- Docker Compose support
