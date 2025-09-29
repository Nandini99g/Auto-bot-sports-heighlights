# app/rapidapi_client.py
import requests
import os

def fetch_highlights(api_key, host, league, date):
    """
    Minimal example request - adjust path/params based on the exact RapidAPI endpoint.
    Returns parsed JSON (dict).
    """
    url = f"https://{host}/highlights"  # change path if needed per actual API docs
    params = {"league": league, "date": date}
    headers = {
        "x-rapidapi-host": host,
        "x-rapidapi-key": api_key,
        "Accept": "application/json"
    }
    resp = requests.get(url, headers=headers, params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()
