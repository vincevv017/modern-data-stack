#!/bin/bash
set -e

echo "🔍 Validating MetricFlow Setup..."

# Check MetricFlow installation
echo "Checking MetricFlow CLI..."
docker compose exec dbt mf --version

# List metrics
echo "Listing available metrics..."
docker compose exec dbt mf list metrics

# Test basic query
echo "Testing basic revenue query..."
docker compose exec dbt mf query --metrics total_revenue

# Test with dimensions
echo "Testing query with dimensions..."
docker compose exec dbt mf query \
  --metrics total_revenue \
  --group-by order_id__supplier_country

echo "✅ MetricFlow validation complete"
