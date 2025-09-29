# Dockerfile

# Stage 1: Base Image
FROM python:3.9-slim

# Set environment variable to prevent Python from buffering stdout/stderr
ENV PYTHONUNBUFFERED=1

# Set the working directory inside the container
WORKDIR /app

# --- Dependency Installation ---

# Copy requirements file (from root to /app)
COPY requirements.txt .

# Install dependencies (will only rerun if requirements.txt changes)
RUN pip install --no-cache-dir -r requirements.txt

# --- Code Copy & Cache Buster ---

# Use an ARG that changes on every build to force Docker to execute the next steps
# This ensures new code is always copied, bypassing the build cache for the code layers.
ARG CACHE_DATE=$(date +%Y-%m-%d_%H:%M:%S)

# Copy the entire 'app' directory contents (e.g., pipeline.py, config.py) 
# from the host root to the container's WORKDIR (/app).
COPY app/ /app/

# Copy the .env file from the host root to the container's /app directory.
# Note: This is mainly for local debugging; the --env-file flag is used for runtime.
COPY .env /app/

# --- Final Command ---

# Set the command to run when the container starts
CMD ["python", "pipeline.py"]