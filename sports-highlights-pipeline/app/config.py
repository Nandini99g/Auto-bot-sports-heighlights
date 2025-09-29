# app/config.py
import os
from dotenv import load_dotenv
from datetime import datetime

# Load .env file from project root
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))

class Config:
    # League and date
    DEFAULT_LEAGUE = os.getenv("DEFAULT_LEAGUE", "Superettan")
    DEFAULT_DATE = os.getenv("DEFAULT_DATE", datetime.now().strftime("%Y-%m-%d"))

    # RapidAPI
    RAPIDAPI_KEY = os.getenv("RAPIDAPI_KEY")
    RAPIDAPI_HOST = os.getenv("RAPIDAPI_HOST", "sport-highlights-api.p.rapidapi.com")

    # S3 Buckets
    METADATA_BUCKET = os.getenv("METADATA_BUCKET")
    VIDEOS_BUCKET = os.getenv("VIDEOS_BUCKET")
    LOGS_BUCKET = os.getenv("LOGS_BUCKET")

    # AWS
    AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
    MEDIACONVERT_ROLE_ARN = os.getenv("MEDIACONVERT_ROLE_ARN")
    SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN")

    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

    # Construct full URL for fetching highlights
    HIGHLIGHTS_URL = f"https://{RAPIDAPI_HOST}/highlights?league={DEFAULT_LEAGUE}&date={DEFAULT_DATE}"
