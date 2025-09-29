# app/mediaconvert_client.py
import boto3
import time
import json

def get_endpoint(region):
    mc = boto3.client("mediaconvert", region_name=region)
    res = mc.describe_endpoints()
    url = res["Endpoints"][0]["Url"]
    return url

def create_client(region, endpoint_url):
    return boto3.client("mediaconvert", region_name=region, endpoint_url=endpoint_url)

def submit_job(mc_client, role_arn, input_s3, output_s3_prefix):
    """
    Minimal job template: two mp4 outputs (720p and 480p).
    Adjust codec and bitrate for production. Returns job id.
    """
    job_settings = {
      "Role": role_arn,
      "Settings": {
        "Inputs": [{"FileInput": input_s3}],
        "OutputGroups": [{
          "Name": "File Group",
          "OutputGroupSettings": {
            "Type": "FILE_GROUP_SETTINGS",
            "FileGroupSettings": {"Destination": output_s3_prefix}
          },
          "Outputs": [
            {
              "ContainerSettings": {"Container": "MP4"},
              "VideoDescription": {"Width": 1280, "Height": 720}
            },
            {
              "ContainerSettings": {"Container": "MP4"},
              "VideoDescription": {"Width": 854, "Height": 480}
            }
          ]
        }]
      }
    }

    resp = mc_client.create_job(**job_settings)
    return resp["Job"]["Id"]

def poll_job(mc_client, job_id, interval=10, timeout=1800):
    started = time.time()
    while True:
        res = mc_client.get_job(Id=job_id)
        status = res["Job"]["Status"]
        if status in ("COMPLETE", "ERROR", "CANCELED"):
            return status, res
        if time.time() - started > timeout:
            return "TIMEOUT", res
        time.sleep(interval)
