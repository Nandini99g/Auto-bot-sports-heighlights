# app/pipeline.py

import os
import requests
import tempfile
import pathlib
import random
import logging
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

from config import Config

# --- Setup logging ---
logging.basicConfig(level=Config.LOG_LEVEL, format="%(asctime)s %(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

# --- Helper functions ---

def fetch_highlights():
    """Fetch highlights JSON from RapidAPI for the configured league/date."""
    url = f"https://{Config.RAPIDAPI_HOST}/football.league?league={Config.DEFAULT_LEAGUE}&date={Config.DEFAULT_DATE}"
    headers = {
        "X-RapidAPI-Key": Config.RAPIDAPI_KEY,
        "X-RapidAPI-Host": Config.RAPIDAPI_HOST
    }
    logger.info(f"Fetching highlights from {url}")
    try:
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        data = response.json()
        logger.info("Highlights fetched successfully")
        return data
    except requests.exceptions.HTTPError as e:
        logger.error(f"HTTP error fetching highlights: {e}")
        return None
    except Exception as e:
        logger.error(f"Error fetching highlights: {e}")
        return None

def pick_random_video_from_json(highlights_json):
    """Pick a random video URL from the highlights JSON."""
    candidates = []

    def walk(obj):
        if isinstance(obj, dict):
            for k, v in obj.items():
                if isinstance(v, str) and (v.endswith(".mp4") or v.startswith("http")):
                    candidates.append(v)
                else:
                    walk(v)
        elif isinstance(obj, list):
            for it in obj:
                walk(it)

    walk(highlights_json)
    if not candidates:
        return None
    return random.choice(candidates)

def download_video(url, dest_path):
    logger.info(f"Downloading video {url}")
    try:
        with requests.get(url, stream=True, timeout=60) as r:
            r.raise_for_status()
            with open(dest_path, "wb") as fh:
                for chunk in r.iter_content(chunk_size=8192):
                    if chunk:
                        fh.write(chunk)
        logger.info(f"Video downloaded to {dest_path}")
        return dest_path
    except Exception as e:
        logger.error(f"Failed to download video: {e}")
        return None

def upload_file_to_s3(bucket, key, local_path):
    try:
        s3_client = boto3.client("s3", region_name=Config.AWS_REGION)
        s3_client.upload_file(local_path, bucket, key)
        logger.info(f"Uploaded {local_path} to s3://{bucket}/{key}")
    except ClientError as e:
        logger.error(f"Failed to upload {local_path} to S3: {e}")

def upload_logs(log_content):
    """Upload pipeline logs to S3."""
    if not Config.LOGS_BUCKET:
        logger.warning("LOGS_BUCKET not configured, skipping log upload")
        return
    try:
        s3_client = boto3.client("s3", region_name=Config.AWS_REGION)
        file_name = f"pipeline_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        s3_client.put_object(Bucket=Config.LOGS_BUCKET, Key=file_name, Body=log_content.encode('utf-8'))
        logger.info(f"Logs uploaded to s3://{Config.LOGS_BUCKET}/{file_name}")
    except ClientError as e:
        logger.error(f"Failed to upload logs: {e}")

# --- Main pipeline ---

def main():
    logger.info(f"Starting pipeline for {Config.DEFAULT_LEAGUE} {Config.DEFAULT_DATE}")

    try:
        # 1) Fetch highlights
        highlights = fetch_highlights()
        if not highlights:
            raise RuntimeError("No highlights fetched from API")

        # 2) Save highlights JSON to S3
        if Config.METADATA_BUCKET:
            s3_key = f"highlights/{Config.DEFAULT_LEAGUE}/{Config.DEFAULT_DATE}/highlights.json"
            upload_file_path = tempfile.mktemp(suffix=".json")
            with open(upload_file_path, "w", encoding="utf-8") as f:
                f.write(str(highlights))
            upload_file_to_s3(Config.METADATA_BUCKET, s3_key, upload_file_path)

        # 3) Pick random video URL
        video_url = pick_random_video_from_json(highlights)
        if not video_url:
            raise RuntimeError("No video URL found in highlights")

        # 4) Download video
        tmpdir = tempfile.mkdtemp()
        local_video_path = os.path.join(tmpdir, pathlib.Path(video_url).name or "video.mp4")
        download_video(video_url, local_video_path)

        # 5) Upload video to S3
        if Config.VIDEOS_BUCKET:
            s3_video_key = f"incoming/{Config.DEFAULT_LEAGUE}/{Config.DEFAULT_DATE}/{pathlib.Path(local_video_path).name}"
            upload_file_to_s3(Config.VIDEOS_BUCKET, s3_video_key, local_video_path)

        logger.info("Pipeline completed successfully")
        upload_logs("Pipeline completed successfully")

    except Exception as e:
        logger.error(f"Pipeline failed: {e}")
        upload_logs(f"Pipeline failed: {e}")

if __name__ == "__main__":
    main()
