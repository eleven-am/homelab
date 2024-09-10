#!/bin/bash

set -euo pipefail

# ANSI color codes
RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

# Default values
DRY_RUN=false
PARALLEL_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || nproc)
CRF=23
PRESET="medium"
CLEANUP=false
MAX_RETRIES=3

# Logging function with colors
log() {
    local level="$1"
    local message="$2"
    local color="$RESET"

    case "$level" in
        "INFO")  color="$GREEN" ;;
        "WARN")  color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
        "DEBUG") color="$BLUE" ;;
    esac

    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message${RESET}"
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS] <directory>"
    echo "Options:"
    echo "  -h, --help             Show this help message"
    echo "  -d, --dry-run          Perform a dry run without actual conversion"
    echo "  -j, --jobs <n>         Number of parallel jobs (default: number of CPU cores)"
    echo "  -q, --quality <n>      Set CRF value for quality (0-51, lower is better, default: 23)"
    echo "  -p, --preset <preset>  Set ffmpeg preset (default: medium)"
    echo "  -c, --cleanup          Remove original files after successful conversion"
    echo "  -r, --retries <n>      Maximum number of retries for failed conversions (default: 3)"
}

# Check for required commands
for cmd in ffmpeg ffprobe file parallel; do
    if ! command -v "$cmd" &> /dev/null; then
        log "ERROR" "$cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -j|--jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        -q|--quality)
            CRF="$2"
            shift 2
            ;;
        -p|--preset)
            PRESET="$2"
            shift 2
            ;;
        -c|--cleanup)
            CLEANUP=true
            shift
            ;;
        -r|--retries)
            MAX_RETRIES="$2"
            shift 2
            ;;
        *)
            DIR="$1"
            shift
            ;;
    esac
done

# Check if a directory is provided
if [ -z "${DIR:-}" ]; then
    log "ERROR" "Please provide a directory path"
    show_help
    exit 1
fi

# Check if the directory exists and is accessible
if [ ! -d "$DIR" ]; then
    log "ERROR" "Directory not found or not accessible: $DIR"
    exit 1
fi

# Convert to absolute path
DIR=$(cd "$DIR" && pwd)
log "INFO" "Processing directory: $DIR"

# Function to check if a file is a video
is_video() {
    local mime_type
    mime_type=$(file -b --mime-type "$1")
    [[ $mime_type == video/* ]]
}

# Function to check if a video is HTML5 compatible
is_html5_compatible() {
    local file="$1"
    local container
    local video_codec
    local audio_streams

    container=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$file")
    video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")

    # Check container format
    if [[ "$container" != *"mp4"* && "$container" != *"webm"* ]]; then
        log "WARN" "Container format $container is not HTML5 compatible for file: $file"
        return 1
    fi

    # Check video codec
    if [[ "$video_codec" != "h264" ]]; then
        log "WARN" "Video codec $video_codec is not h264 for file: $file"
        return 1
    fi

    # Check all audio streams
    audio_streams=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$file")

    local stream
    local audio_codec
    for stream in $audio_streams; do
        audio_codec=$(ffprobe -v error -select_streams a:"$stream" -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")
        if [[ "$audio_codec" != "eac3" && "$audio_codec" != "aac" && "$audio_codec" != "ac3" ]]; then
            log "WARN" "Audio stream $stream codec $audio_codec is not compatible for file: $file"
            return 1
        fi
    done

    log "INFO" "Video is HTML5 compatible (MP4/WebM container, h264 video, all audio streams are eac3/aac/ac3) for file: $file"
    return 0
}

# Function to convert video to HTML5 compatible format
convert_to_html5() {
    local input="$1"
    local input_filename
    local output_filename
    local output_path
    local container
    local video_codec
    local audio_streams
    local ffmpeg_cmd

    input_filename=$(basename "$input")
    output_filename="${input_filename%.*}_converted.mp4"
    output_path="$(dirname "$input")/$output_filename"

    container=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$input")
    video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input")
    audio_streams=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$input")

    # Prepare ffmpeg command
    ffmpeg_cmd=(ffmpeg -i "$input")

    # Determine video encoding settings
    if [[ "$container" == *"mp4"* && "$video_codec" == "h264" ]]; then
        ffmpeg_cmd+=(-c:v copy)
        log "INFO" "Copying video stream for file: $input"
    else
        ffmpeg_cmd+=(-c:v libx264 -preset "$PRESET" -crf "$CRF")
        log "INFO" "Transcoding video stream to h264 for file: $input"
    fi

    # Process each audio stream
    local stream
    local audio_codec
    for stream in $audio_streams; do
        audio_codec=$(ffprobe -v error -select_streams a:"$stream" -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input")
        if [[ "$audio_codec" == "eac3" || "$audio_codec" == "aac" || "$audio_codec" == "ac3" ]]; then
            ffmpeg_cmd+=(-c:a:"$stream" copy)
            log "INFO" "Copying audio stream $stream for file: $input"
        else
            ffmpeg_cmd+=(-c:a:"$stream" aac -b:a:"$stream" 192k)
            log "INFO" "Transcoding audio stream $stream to AAC for file: $input"
        fi
    done

    # Add output file to command
    ffmpeg_cmd+=(-f mp4 "$output_path")

    # Execute ffmpeg command
    log "INFO" "Starting conversion for file: $input"
    if [ "$DRY_RUN" = true ]; then
        log "DEBUG" "Dry run: ${ffmpeg_cmd[*]}"
    else
        if "${ffmpeg_cmd[@]}"; then
            log "INFO" "Conversion completed successfully: $output_path"
            if [ "$CLEANUP" = true ]; then
                rm "$input"
                log "INFO" "Removed original file: $input"
            fi
        else
            log "ERROR" "Conversion failed for file: $input"
            return 1
        fi
    fi
}

# Function to process a single video file
process_video() {
    local file="$1"
    local retries=0

    while [ $retries -lt "$MAX_RETRIES" ]; do
        if is_html5_compatible "$file"; then
            log "INFO" "File is already HTML5 compatible: $file"
            return 0
        else
            log "INFO" "Converting to HTML5 compatible format: $file"
            if convert_to_html5 "$file"; then
                return 0
            else
                retries=$((retries + 1))
                log "WARN" "Conversion failed. Retry $retries of $MAX_RETRIES for file: $file"
            fi
        fi
    done

    log "ERROR" "Max retries reached. Failed to convert file: $file"
    return 1
}

# Main processing loop
if [ "$DRY_RUN" = true ]; then
    log "INFO" "Performing dry run..."
fi

export -f log is_video is_html5_compatible convert_to_html5 process_video
export DRY_RUN CLEANUP CRF PRESET MAX_RETRIES

find "$DIR" -type f -print0 | parallel -0 -j "$PARALLEL_JOBS" process_video

log "INFO" "Video processing complete."
