#!/usr/bin/env python3

import argparse
import json
import logging
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional

STATE_FILE_NAME = ".transcode_state.json"
COMPATIBLE_AUDIO_CODECS = {"aac", "ac3", "eac3", "mp3"}
COMPATIBLE_CONTAINERS = {"mov", "mp4", "m4a", "3gp", "3g2", "mj2"}

logging.basicConfig(
    level=logging.INFO,
    format="\033[0;32m[%(asctime)s] [%(levelname)s] %(message)s\033[0m",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


@dataclass
class StreamInfo:
    index: int
    codec_name: str
    codec_type: str
    bit_depth: Optional[int] = None
    color_transfer: Optional[str] = None
    channels: Optional[int] = None


@dataclass
class ProbeResult:
    format_name: str
    duration: float
    streams: list[StreamInfo] = field(default_factory=list)

    @property
    def video_streams(self) -> list[StreamInfo]:
        return [s for s in self.streams if s.codec_type == "video"]

    @property
    def audio_streams(self) -> list[StreamInfo]:
        return [s for s in self.streams if s.codec_type == "audio"]

    @property
    def subtitle_streams(self) -> list[StreamInfo]:
        return [s for s in self.streams if s.codec_type == "subtitle"]


@dataclass
class FileState:
    mtime: float
    size: int
    status: str


class TranscodeState:
    def __init__(self, state_path: Path):
        self.state_path = state_path
        self.data: dict[str, FileState] = {}
        self._load()

    def _load(self):
        if self.state_path.exists():
            try:
                with open(self.state_path) as f:
                    raw = json.load(f)
                    self.data = {k: FileState(**v) for k, v in raw.items()}
                logger.debug(f"Loaded state with {len(self.data)} entries")
            except (json.JSONDecodeError, TypeError) as e:
                logger.warning(f"Failed to load state file: {e}")
                self.data = {}

    def save(self):
        with open(self.state_path, "w") as f:
            json.dump({k: asdict(v) for k, v in self.data.items()}, f, indent=2)

    def should_process(self, file_path: Path) -> bool:
        key = str(file_path)
        stat = file_path.stat()
        if key not in self.data:
            return True
        state = self.data[key]
        if state.mtime != stat.st_mtime or state.size != stat.st_size:
            return True
        return state.status not in ("compatible", "converted")

    def mark(self, file_path: Path, status: str):
        stat = file_path.stat()
        self.data[str(file_path)] = FileState(
            mtime=stat.st_mtime, size=stat.st_size, status=status
        )
        self.save()


def detect_gpu() -> bool:
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            logger.info(f"GPU detected: {result.stdout.strip().split(chr(10))[0]}")
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    try:
        result = subprocess.run(
            ["ffmpeg", "-hide_banner", "-encoders"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if "h264_nvenc" in result.stdout:
            logger.info("NVENC encoder available")
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    logger.info("No GPU detected, using CPU encoding")
    return False


def probe_file(file_path: Path) -> Optional[ProbeResult]:
    cmd = [
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=format_name,duration:stream=index,codec_name,codec_type,bits_per_raw_sample,color_transfer,channels",
        "-of", "json",
        str(file_path),
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            logger.error(f"ffprobe failed for {file_path}: {result.stderr}")
            return None

        data = json.loads(result.stdout)
        streams = []
        for s in data.get("streams", []):
            bit_depth = None
            if s.get("bits_per_raw_sample"):
                try:
                    bit_depth = int(s["bits_per_raw_sample"])
                except ValueError:
                    pass
            streams.append(StreamInfo(
                index=s.get("index", 0),
                codec_name=s.get("codec_name", ""),
                codec_type=s.get("codec_type", ""),
                bit_depth=bit_depth,
                color_transfer=s.get("color_transfer"),
                channels=s.get("channels"),
            ))

        fmt = data.get("format", {})
        duration = 0.0
        if fmt.get("duration"):
            try:
                duration = float(fmt["duration"])
            except ValueError:
                pass

        return ProbeResult(
            format_name=fmt.get("format_name", ""),
            duration=duration,
            streams=streams,
        )
    except (subprocess.TimeoutExpired, json.JSONDecodeError) as e:
        logger.error(f"Failed to probe {file_path}: {e}")
        return None


VIDEO_EXTENSIONS = {
    ".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm",
    ".m4v", ".mpg", ".mpeg", ".3gp", ".3g2", ".ts", ".mts",
    ".m2ts", ".vob", ".ogv", ".divx", ".xvid", ".rm", ".rmvb",
    ".asf", ".f4v",
}


def is_video_file(file_path: Path) -> bool:
    ext = file_path.suffix.lower()
    if ext in VIDEO_EXTENSIONS:
        return True
    if ext in {".txt", ".nfo", ".jpg", ".jpeg", ".png", ".srt", ".sub", ".idx", ".ass", ".ssa"}:
        return False
    try:
        result = subprocess.run(
            ["file", "-b", "--mime-type", str(file_path)],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.stdout.strip().startswith("video/")
    except subprocess.TimeoutExpired:
        return False


def is_html5_compatible(probe: ProbeResult) -> bool:
    if not any(c in probe.format_name for c in COMPATIBLE_CONTAINERS):
        return False

    video = probe.video_streams
    if not video:
        return False

    v = video[0]
    if v.codec_name != "h264":
        return False
    if v.bit_depth and v.bit_depth > 8:
        return False

    for a in probe.audio_streams:
        if a.codec_name not in COMPATIBLE_AUDIO_CODECS:
            return False

    return True


def needs_hdr_tonemap(probe: ProbeResult) -> bool:
    for v in probe.video_streams:
        if v.color_transfer in ("smpte2084", "arib-std-b67"):
            return True
        if v.bit_depth and v.bit_depth >= 10 and v.color_transfer in ("bt2020-10", "bt2020-12"):
            return True
    return False


def build_ffmpeg_command(
    input_path: Path,
    output_path: Path,
    probe: ProbeResult,
    use_gpu: bool,
    crf: int,
    preset: str,
) -> list[str]:
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "warning", "-stats", "-y"]
    cmd.extend(["-i", str(input_path)])

    v = probe.video_streams[0] if probe.video_streams else None
    needs_transcode = False

    if v:
        if v.codec_name != "h264":
            needs_transcode = True
        elif v.bit_depth and v.bit_depth >= 10:
            needs_transcode = True

    if needs_transcode:
        if needs_hdr_tonemap(probe):
            cmd.extend(["-vf", "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"])
        elif use_gpu:
            cmd.extend(["-vf", "format=yuv420p"])

        if use_gpu:
            cmd.extend([
                "-c:v", "h264_nvenc",
                "-preset", "p4",
                "-cq", str(crf),
                "-profile:v", "high",
            ])
        else:
            cmd.extend([
                "-c:v", "libx264",
                "-preset", preset,
                "-crf", str(crf),
                "-profile:v", "high",
                "-threads", "4",
            ])
    else:
        cmd.extend(["-c:v", "copy"])

    for i, a in enumerate(probe.audio_streams):
        if a.codec_name in COMPATIBLE_AUDIO_CODECS:
            cmd.extend([f"-c:a:{i}", "copy"])
        else:
            cmd.extend([
                f"-c:a:{i}", "aac",
                f"-b:a:{i}", "192k",
            ])

    for i, s in enumerate(probe.subtitle_streams):
        if s.codec_name in ("mov_text", "tx3g"):
            cmd.extend([f"-c:s:{i}", "copy"])
        elif s.codec_name in ("subrip", "srt", "ass", "ssa"):
            cmd.extend([f"-c:s:{i}", "mov_text"])

    cmd.extend(["-movflags", "+faststart", "-f", "mp4", str(output_path)])
    return cmd


def convert_video(
    input_path: Path,
    temp_dir: Path,
    probe: ProbeResult,
    use_gpu: bool,
    crf: int,
    preset: str,
    cleanup: bool,
    dry_run: bool,
) -> tuple[bool, Optional[Path]]:
    output_name = input_path.stem + ".mp4"
    temp_output = temp_dir / output_name
    final_output = input_path.parent / output_name

    cmd = build_ffmpeg_command(input_path, temp_output, probe, use_gpu, crf, preset)

    if dry_run:
        logger.info(f"Dry run: {' '.join(cmd)}")
        return True, None

    logger.info(f"Converting: {input_path.name}")
    logger.debug(f"Command: {' '.join(cmd)}")

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        for line in process.stdout:
            line = line.strip()
            if line:
                print(f"  {line}", flush=True)

        process.wait(timeout=7200)

        if process.returncode != 0:
            logger.error(f"Conversion failed for {input_path.name}")
            if temp_output.exists():
                temp_output.unlink()
            return False, None

        if cleanup and input_path.suffix.lower() != ".mp4":
            input_path.unlink()
            shutil.move(str(temp_output), str(final_output))
        elif cleanup:
            shutil.move(str(temp_output), str(final_output))
            if input_path != final_output and input_path.exists():
                input_path.unlink()
        else:
            if final_output.exists() and final_output != input_path:
                final_output = input_path.parent / f"{input_path.stem}_converted.mp4"
            shutil.move(str(temp_output), str(final_output))

        logger.info(f"Completed: {final_output.name}")
        return True, final_output

    except subprocess.TimeoutExpired:
        logger.error(f"Conversion timed out for {input_path}")
        if temp_output.exists():
            temp_output.unlink()
        return False, None


def process_file(
    file_path: Path,
    temp_dir: Path,
    state: TranscodeState,
    use_gpu: bool,
    crf: int,
    preset: str,
    cleanup: bool,
    dry_run: bool,
    max_retries: int,
) -> bool:
    if not state.should_process(file_path):
        logger.debug(f"Skipping (already processed): {file_path}")
        return True

    probe = probe_file(file_path)
    if not probe:
        state.mark(file_path, "failed")
        return False

    if is_html5_compatible(probe):
        logger.debug(f"Already compatible: {file_path}")
        state.mark(file_path, "compatible")
        return True

    for attempt in range(max_retries):
        success, output_path = convert_video(
            file_path, temp_dir, probe, use_gpu, crf, preset, cleanup, dry_run
        )
        if success:
            if not dry_run:
                mark_path = output_path if output_path else file_path
                if mark_path.exists():
                    state.mark(mark_path, "converted")
            return True

        if attempt < max_retries - 1:
            logger.warning(f"Retry {attempt + 2}/{max_retries} for {file_path}")

            if use_gpu:
                logger.info("Retrying with CPU encoding")
                use_gpu = False

    state.mark(file_path, "failed")
    return False


def find_video_files(directory: Path, ignore_pattern: Optional[str]) -> list[Path]:
    files = []
    ignore_re = re.compile(ignore_pattern) if ignore_pattern else None

    for file_path in directory.rglob("*"):
        if not file_path.is_file():
            continue
        if ignore_re and ignore_re.search(str(file_path)):
            logger.debug(f"Ignoring: {file_path}")
            continue
        if is_video_file(file_path):
            files.append(file_path)

    return sorted(files)


def main():
    parser = argparse.ArgumentParser(description="Convert videos to HTML5 compatible format")
    parser.add_argument("directory", type=Path, help="Directory to process")
    parser.add_argument("-d", "--dry-run", action="store_true", help="Perform dry run")
    parser.add_argument("-l", "--log-level", default="INFO", choices=["DEBUG", "INFO", "WARN", "ERROR"])
    parser.add_argument("-q", "--quality", type=int, default=23, help="CRF value (0-51)")
    parser.add_argument("-p", "--preset", default="medium", help="Encoding preset")
    parser.add_argument("-c", "--cleanup", action="store_true", help="Remove originals after conversion")
    parser.add_argument("-r", "--retries", type=int, default=3, help="Max retries")
    parser.add_argument("-i", "--ignore", type=str, help="Ignore pattern (regex)")
    parser.add_argument("-t", "--temp-dir", type=Path, help="Temporary directory")
    parser.add_argument("-g", "--gpu", action="store_true", help="Enable GPU acceleration")
    parser.add_argument("--total-shards", type=int, default=1)
    parser.add_argument("--shard-index", type=int, default=0)
    parser.add_argument("-w", "--workers", type=int, default=1, help="Parallel workers")

    args = parser.parse_args()

    log_level = getattr(logging, args.log_level.upper(), logging.INFO)
    logger.setLevel(log_level)

    if os.environ.get("JOB_COMPLETION_INDEX"):
        args.shard_index = int(os.environ["JOB_COMPLETION_INDEX"])

    if not args.directory.is_dir():
        logger.error(f"Directory not found: {args.directory}")
        sys.exit(1)

    args.directory = args.directory.resolve()
    logger.info(f"Processing directory: {args.directory}")

    temp_dir = args.temp_dir or Path("/tmp/transcode")
    temp_dir.mkdir(parents=True, exist_ok=True)

    state_path = args.directory / STATE_FILE_NAME
    state = TranscodeState(state_path)

    use_gpu = args.gpu and detect_gpu()

    files = find_video_files(args.directory, args.ignore)

    if args.total_shards > 1:
        files = [f for i, f in enumerate(files) if i % args.total_shards == args.shard_index]

    total = len(files)
    logger.info(f"Found {total} video files to process")

    if total == 0:
        logger.info("No files to process")
        return

    processed = 0
    failed = 0

    for i, file_path in enumerate(files, 1):
        logger.info(f"[{i}/{total}] {file_path.name}")
        success = process_file(
            file_path,
            temp_dir,
            state,
            use_gpu,
            args.quality,
            args.preset,
            args.cleanup,
            args.dry_run,
            args.retries,
        )
        if success:
            processed += 1
        else:
            failed += 1

    logger.info(f"Complete: {processed} processed, {failed} failed")


if __name__ == "__main__":
    main()
