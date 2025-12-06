#!/bin/bash

# Polaris Catalog Initialization Script
# This script creates the lakehouse catalog in Apache Polaris with MinIO configuration

set -e

echo "🚀 Initializing Polaris Catalog..."

# Auto-detect credentials from Polaris logs or use environment variables
if [ -z "$POLARIS_CLIENT_ID" ] || [ -z "$POLARIS_CLIENT_SECRET" ]; then
  echo "🔍 Auto-detecting Polaris credentials from logs..."
  CREDS=$(docker compose logs polaris 2>/dev/null | grep "root principal credentials" | tail -1 | grep -o '[a-f0-9]\{16\}:[a-f0-9]\{32\}')
  
  if [ -z "$CREDS" ]; then
    echo "❌ Could not auto-detect credentials from Polaris logs"
    echo ""
    echo "Please provide credentials manually:"
    echo "  Find them with: docker compose logs polaris | grep 'root principal credentials'"
    echo "  Then run: POLARIS_CLIENT_ID=xxx POLARIS_CLIENT_SECRET=yyy ./scripts/init-polaris-catalog.sh"
    exit 1
  fi
  
  CLIENT_ID=$(echo "$CREDS" | cut -d':' -f1)
  CLIENT_SECRET=$(echo "$CREDS" | cut -d':' -f2)
  echo "✅ Found credentials: $CLIENT_ID:${CLIENT_SECRET:0:8}..."
else
  CLIENT_ID="$POLARIS_CLIENT_ID"
  CLIENT_SECRET="$POLARIS_CLIENT_SECRET"
  echo "✅ Using credentials from environment variables"
fi

POLARIS_URL="${POLARIS_URL:-http://localhost:8181}"

# Get OAuth token
echo "🔑 Authenticating with Polaris..."
TOKEN_RESPONSE=$(curl -s -X POST "$POLARIS_URL/api/catalog/v1/oauth/tokens" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=PRINCIPAL_ROLE:ALL")

# Extract access token
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to get access token"
  echo "Response: $TOKEN_RESPONSE"
  echo ""
  echo "Troubleshooting:"
  echo "1. Check Polaris is running: docker compose ps polaris"
  echo "2. Verify credentials in docker-compose.yml POLARIS_BOOTSTRAP_CREDENTIALS"
  echo "3. Get current credentials: docker compose logs polaris | grep 'root principal credentials'"
  exit 1
fi

echo "✅ Successfully authenticated"

# Check if catalog already exists
echo "📋 Checking existing catalogs..."
EXISTING_CATALOGS=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$POLARIS_URL/api/management/v1/catalogs")

if echo "$EXISTING_CATALOGS" | grep -q '"name":"lakehouse"'; then
  echo "⚠️  Catalog 'lakehouse' already exists"
  read -p "Do you want to delete and recreate it? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Deleting existing catalog..."
    curl -s -X DELETE \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      "$POLARIS_URL/api/management/v1/catalogs/lakehouse"
    echo "✅ Existing catalog deleted"
  else
    echo "ℹ️  Keeping existing catalog"
    exit 0
  fi
fi

# Create catalog with MinIO configuration
echo "📝 Creating lakehouse catalog..."
CATALOG_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$POLARIS_URL/api/management/v1/catalogs" \
  -d '{
    "catalog": {
      "name": "lakehouse",
      "type": "INTERNAL",
      "properties": {
        "default-base-location": "s3://warehouse/"
      },
      "storageConfigInfo": {
        "storageType": "S3",
        "allowedLocations": ["s3://warehouse/", "s3://raw-data/"],
        "endpoint": "http://minio:9000",
        "pathStyleAccess": true
      }
    }
  }')

# Check for errors
if echo "$CATALOG_RESPONSE" | grep -q '"error"'; then
  echo "❌ Failed to create catalog"
  echo "Response: $CATALOG_RESPONSE"
  exit 1
fi

echo "✅ Lakehouse catalog created successfully!"
echo ""
echo "Catalog configuration:"
echo "  - Name: lakehouse"
echo "  - Type: INTERNAL (Polaris-managed)"
echo "  - Default location: s3://warehouse/"
echo "  - Allowed locations: s3://warehouse/, s3://raw-data/"
echo "  - Storage: MinIO (http://minio:9000)"
echo "  - Path style access: enabled"
echo ""
echo "⚠️  IMPORTANT: Update Trino configuration with these credentials:"
echo "  Edit trino/catalog/lakehouse.properties:"
echo "  iceberg.rest-catalog.oauth2.credential=$CLIENT_ID:$CLIENT_SECRET"
echo ""
echo "Then restart Trino:"
echo "  docker compose restart trino"
echo ""
echo "Next steps:"
echo "  1. Update trino/catalog/lakehouse.properties (see above)"
echo "  2. Restart Trino: docker compose restart trino"
echo "  3. Verify catalog: docker compose exec trino trino --execute \"SHOW CATALOGS;\""
echo "  4. Create schema: CREATE SCHEMA lakehouse.raw_data WITH (location = 's3://raw-data/');"
echo ""
echo "🎉 Done!"