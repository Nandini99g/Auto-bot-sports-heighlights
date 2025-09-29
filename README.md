# Auto-bot-sports-heighlights
 
 
##Project Explanation – Sports Highlights Ingestion & Processing Pipeline
 
# Purpose
 
The main goal of this project is to automate the process of collecting, processing, and storing sports highlight videos. Instead of manually downloading videos, converting them, and uploading them to storage, this pipeline handles all of that automatically. It is production-ready, scalable, and easily deployable.
 
# How the Pipeline Works (Workflow)
Step 1: Fetch Highlights
 
The pipeline connects to the RapidAPI Sports Highlights API.
 
It retrieves a list of available highlights based on the selected league and date.
 
This ensures you only process relevant videos.
 
Step 2: Download Videos
 
Videos are downloaded temporarily to the EC2 instance.
 
Both metadata (like video title, league, date) and actual video files are stored locally before processing.
 
Step 3: Process Videos
 
Videos are sent to AWS MediaConvert for processing.
 
MediaConvert converts the videos into desired formats, resolutions, and codecs (e.g., MP4, HLS).
 
This ensures the videos are optimized for storage, playback, or further distribution.
 
Step 4: Store Videos in S3
 
Raw videos (original downloads) are uploaded to a dedicated S3 bucket.
 
Processed videos (converted by MediaConvert) are uploaded to another S3 bucket.
 
This separation keeps raw and processed content organized and easy to access.
 
Step 5: Notifications (Optional)
 
Once processing is complete, a message can be sent via AWS SNS.
 
This allows monitoring or alerts when new highlights are available.
 
Step 6: Automation via EventBridge
 
The entire pipeline can be scheduled using AWS EventBridge.
 
For example, it can run daily at 10 PM to fetch and process the day’s highlights automatically.
 
# Key Components

Component   Role
EC2 Instance    Runs the pipeline scripts inside Docker.
Docker  Ensures consistent environment and dependencies across machines.
AWS S3  Stores both raw and processed videos.
AWS MediaConvert    Converts videos into the desired format and resolution.
AWS SNS Sends notifications when videos are processed.
EventBridge Automates pipeline execution on a schedule.
Terraform   Provision all AWS resources programmatically for repeatable deployment.

# Benefits
 
Automation: No manual downloading, processing, or uploading.
 
Scalability: Can handle multiple leagues, dates, and videos efficiently.
 
Organization: Separate buckets for raw and processed videos for better management.
 
Reproducibility: Docker ensures the pipeline works the same way on any system.
 
Infrastructure as Code: Terraform makes AWS setup repeatable and version-controlled.
 
Notification & Monitoring: SNS allows you to get alerts when the pipeline finishes.
 
# Practical Use Cases
 
Media companies can automatically collect and publish highlights.
 
Sports analytics platforms can process and store video datasets for analysis.
 
Coaches and teams can quickly access processed highlights for review....
 
