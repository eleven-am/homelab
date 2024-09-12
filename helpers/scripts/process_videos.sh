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
CRF=23
PRESET="medium"
CLEANUP=false
MAX_RETRIES=3
LOG_LEVEL="INFO"
TOTAL_SHARDS=1
SHARD_INDEX=0
TEMP_DIR=""

# Logging function with colors
log() {
    local level="$1"
    local message="$2"
    local color="$RESET"

    # Define log levels
    local -r DEBUG=0
    local -r INFO=1
    local -r WARN=2
    local -r ERROR=3

    # Get numeric priority of current log level
    local log_priority
    case "$LOG_LEVEL" in
        DEBUG) log_priority=$DEBUG ;;
        INFO)  log_priority=$INFO ;;
        WARN)  log_priority=$WARN ;;
        ERROR) log_priority=$ERROR ;;
        *)     log_priority=$INFO ;;  # Default to INFO if invalid level
    esac

    # Get numeric priority of message level
    local message_priority
    case "$level" in
        DEBUG) message_priority=$DEBUG ;;
        INFO)  message_priority=$INFO ;;
        WARN)  message_priority=$WARN ;;
        ERROR) message_priority=$ERROR ;;
        *)     message_priority=$INFO ;;  # Default to INFO if invalid level
    esac

    # Check if the log level is high enough to be printed
    if [ $message_priority -ge $log_priority ]; then
        case "$level" in
            INFO)  color="$GREEN" ;;
            WARN)  color="$YELLOW" ;;
            ERROR) color="$RED" ;;
            DEBUG) color="$BLUE" ;;
        esac

        echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message${RESET}"
    fi
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS] <directory>"
    echo "Options:"
    echo "  -h, --help             Show this help message"
    echo "  -d, --dry-run          Perform a dry run without actual conversion"
    echo "  -l, --log-level <level> Set log level (DEBUG, INFO, WARN, ERROR) (default: INFO)"
    echo "  -q, --quality <n>      Set CRF value for quality (0-51, lower is better, default: 23)"
    echo "  -p, --preset <preset>  Set ffmpeg preset (default: medium)"
    echo "  -c, --cleanup          Remove original files after successful conversion"
    echo "  -r, --retries <n>      Maximum number of retries for failed conversions (default: 3)"
    echo "  --total-shards <n>     Total number of shards for parallel processing (default: 1)"
    echo "  --shard-index <n>      Index of this shard (0-based, default: 0)"
    echo "  -t, --temp-dir <path>  Specify the temporary directory to use(default: system default)"
}

# Function to check the exit status of the last command
check_status() {
    if [ $? -ne 0 ]; then
        log "ERROR" "$1"
        return 1
    fi

    return 0
}

# Function to create or use the specified temporary directory
create_temp_dir() {
    if [ -z "${TEMP_DIR:-}" ]; then
        TEMP_DIR=$(mktemp -d)
        log "DEBUG" "Created temporary directory: $TEMP_DIR"
        trap 'rm -rf "$TEMP_DIR"' EXIT
    elif [ ! -d "$TEMP_DIR" ]; then
        mkdir -p "$TEMP_DIR"
        log "DEBUG" "Created specified temporary directory: $TEMP_DIR"
    else
        log "DEBUG" "Using existing temporary directory: $TEMP_DIR"
    fi
}

# Check for required commands
for cmd in ffmpeg ffprobe file; do
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
        -l|--log-level)
            LOG_LEVEL="${2^^}"
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
        --total-shards)
            TOTAL_SHARDS="$2"
            shift 2
            ;;
        --shard-index)
            SHARD_INDEX="$2"
            shift 2
            ;;
        -t|--temp-dir)
            TEMP_DIR="$2"
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

# Function to parse stream indexes from a string
parse_stream_indexes() {
    local input_string="$1"
    local result=""
    local separator=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^[0-9]+$ ]]; then
            result="${result}${separator}${line}"
            separator=","
        fi
    done <<< "$input_string"

    echo "$result"
}

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
    if [[ ! "$container" =~ mp4 ]]; then
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
    local audio_stream_index=0
    for stream in $audio_streams; do
        audio_codec=$(ffprobe -v error -select_streams a:"$audio_stream_index" -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")
        if [[ ! "$audio_codec" =~ ^(eac3|aac|ac3|mp3)$ ]]; then
            log "WARN" "Audio stream $stream codec $audio_codec is not compatible for file: $file"
            return 1
        fi
        audio_stream_index=$((audio_stream_index + 1))
    done

    log "DEBUG" "Video is HTML5 compatible (MP4/WebM container, h264 video, all audio streams are eac3/aac/ac3) for file: $file"
    return 0
}

# Function to convert video to HTML5 compatible format
convert_to_html5() {
    local input="$1"
    local input_filename
    local output_filename
    local temp_output_path
    local final_output_path
    local video_codec
    local ffmpeg_cmd

    input_filename=$(basename "$input")
    output_filename="${input_filename%.*}.mp4"
    temp_output_path="${TEMP_DIR}/${output_filename}"
    final_output_path="$(dirname "$input")/${output_filename}"

    video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input")

    # Prepare ffmpeg command
    ffmpeg_cmd=(ffmpeg -loglevel error -hide_banner -i "$input")

    # Determine video encoding settings
    if [[ "$video_codec" == "h264" ]]; then
        ffmpeg_cmd+=(-c:v copy)
        log "DEBUG" "Copying video stream for file: $input"
    else
        ffmpeg_cmd+=(-c:v libx264 -preset "$PRESET" -crf "$CRF")
        log "DEBUG" "Transcoding video stream to h264 for file: $input"
    fi

    # Process audio streams
    local audio_codec
    local audio_streams
    local parsed_audio_streams
    local ffmpeg_audio_index=0
    local subtitle_stream_array

    audio_streams=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$input")
    parsed_audio_streams=$(parse_stream_indexes "$audio_streams")

    IFS=',' read -ra audio_stream_array <<< "$parsed_audio_streams"

    for stream in "${audio_stream_array[@]}"; do
         audio_codec=$(ffprobe -v error -select_streams a:"$ffmpeg_audio_index" -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input")
        if [[ "$audio_codec" =~ ^(eac3|aac|ac3|mp3)$ ]]; then
            ffmpeg_cmd+=(-c:a:"$ffmpeg_audio_index" copy)
            log "DEBUG" "Copying audio stream $stream for file: $input"
        else
            ffmpeg_cmd+=(-c:a:"$ffmpeg_audio_index" aac)
            log "DEBUG" "Transcoding audio stream $stream to AAC for file: $input"
        fi
        ffmpeg_audio_index=$((ffmpeg_audio_index + 1))
    done

    # Process subtitle streams
    local subtitle_codec
    local subtitle_streams
    local parsed_subtitle_streams
    local ffmpeg_subtitle_index=0

    subtitle_streams=$(ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "$input")
    parsed_subtitle_streams=$(parse_stream_indexes "$subtitle_streams")

    if [ -n "$parsed_subtitle_streams" ]; then
        IFS=',' read -ra subtitle_stream_array <<< "$parsed_subtitle_streams"

        for stream in "${subtitle_stream_array[@]}"; do
            subtitle_codec=$(ffprobe -v error -select_streams s:"$ffmpeg_subtitle_index" -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input")
            if [[ "$subtitle_codec" == "mov_text" ]]; then
                ffmpeg_cmd+=(-c:s:"$ffmpeg_subtitle_index" copy)
                log "DEBUG" "Copying subtitle stream $stream (codec: $subtitle_codec) for file: $input"
            else
                ffmpeg_cmd+=(-c:s:"$ffmpeg_subtitle_index" mov_text)
                log "DEBUG" "Transcoding subtitle stream $stream from $subtitle_codec to mov_text for file: $input"
            fi
            ffmpeg_subtitle_index=$((ffmpeg_subtitle_index + 1))
        done
    else
        log "DEBUG" "No subtitle streams found for file: $input"
    fi

    # Add movflags for better streaming
    ffmpeg_cmd+=(-movflags +faststart)

    # Add output file to command
    ffmpeg_cmd+=(-f mp4 "$temp_output_path")

    # Execute ffmpeg command
    log "INFO" "Starting conversion for file: $input"
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "Dry run: ${ffmpeg_cmd[*]}"
    else
        "${ffmpeg_cmd[@]}" </dev/null
        if check_status "Conversion failed for file: $input"; then
            log "INFO" "Conversion completed successfully: $temp_output_path"

            if [ "$CLEANUP" = true ]; then
                rm "$input"
                log "DEBUG" "Removed original file: $input"
                mv "$temp_output_path" "$final_output_path"
                log "DEBUG" "Moved converted file to replace original: $final_output_path"
            else
                if [ -f "$final_output_path" ]; then
                    log "WARN" "File already exists: $final_output_path"
                    final_output_path="$(dirname "$input")/${input_filename%.*}_converted.mp4"
                    log "DEBUG" "Renaming output to: $final_output_path"
                fi
                mv "$temp_output_path" "$final_output_path"
                log "DEBUG" "Moved converted file to: $final_output_path"
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
        if convert_to_html5 "$file"; then
            return 0
        else
            retries=$((retries + 1))
            log "WARN" "Conversion failed. Retry $retries of $MAX_RETRIES for file: $file"
            sleep 5
        fi
    done

    log "ERROR" "Max retries reached. Failed to convert file: $file"
    return 1
}

# Function to process all video files in a directory recursively
process_directory() {
    local dir="$1"
    local file_index=0

    find "$dir" -type f | while read -r file; do
        if is_video "$file"; then
            if [ $((file_index % TOTAL_SHARDS)) -eq "$SHARD_INDEX" ]; then
                log "INFO" "Processing video: $file"
                if is_html5_compatible "$file"; then
                    log "DEBUG" "File is already HTML5 compatible: $file"
                else
                    log "DEBUG" "Converting to HTML5 compatible format: $file"
                    process_video "$file"
                fi
            else
                log "DEBUG" "Skipping file (not in this shard): $file"
            fi
            file_index=$((file_index + 1))
        else
            log "DEBUG" "Skipping non-video file: $file"
        fi
    done
}

# Create a temporary directory
create_temp_dir

# Main processing loop
if [ "$DRY_RUN" = true ]; then
    log "INFO" "Performing dry run..."
fi

export -f log is_video is_html5_compatible convert_to_html5 process_video
export DRY_RUN CLEANUP CRF PRESET MAX_RETRIES LOG_LEVEL TEMP_DIR TOTAL_SHARDS SHARD_INDEX

process_directory "$DIR"

log "INFO" "Video processing complete."
