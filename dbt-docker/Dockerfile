FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install dbt-core and dbt-trino with compatible versions
RUN pip install --no-cache-dir \
    dbt-core \
    dbt-trino \
    dbt-metricflow \
    keyring

# Create work directory
WORKDIR /usr/app

# Verify installation
RUN dbt --version

# Keep container running
CMD ["tail", "-f", "/dev/null"]
