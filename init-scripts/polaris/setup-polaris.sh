#!/bin/bash

# Complete Polaris Setup Script
# Creates catalog, grants permissions, and sets up catalog role

set -e

echo "🚀 Setting up Polaris Catalog..."

# Auto-detect credentials from Polaris logs
echo "🔍 Detecting Polaris credentials..."
CREDS=$(docker compose logs polaris 2>/dev/null | grep "root principal credentials" | tail -1 | grep -o '[a-f0-9]\{16\}:[a-f0-9]\{32\}')

if [ -z "$CREDS" ]; then
  echo "❌ Could not find credentials. Make sure Polaris is running:"
  echo "   docker compose ps polaris"
  echo "   docker compose logs polaris | grep 'root principal credentials'"
  exit 1
fi

CLIENT_ID=$(echo "$CREDS" | cut -d':' -f1)
CLIENT_SECRET=$(echo "$CREDS" | cut -d':' -f2)
POLARIS_URL="http://localhost:8181"

echo "✅ Found credentials: $CLIENT_ID:${CLIENT_SECRET:0:8}..."

# Get OAuth token
echo "🔑 Authenticating..."
TOKEN_RESPONSE=$(curl -s -X POST "$POLARIS_URL/api/catalog/v1/oauth/tokens" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=PRINCIPAL_ROLE:ALL")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to authenticate"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Authenticated successfully"

# Check if catalog exists
echo "📋 Checking for existing catalog..."
CATALOG_CHECK=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$POLARIS_URL/api/management/v1/catalogs/lakehouse" 2>/dev/null)

if echo "$CATALOG_CHECK" | grep -q '"name":"lakehouse"'; then
  echo "⚠️  Catalog 'lakehouse' already exists"
  read -p "Delete and recreate? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Deleting existing catalog..."
    curl -s -X DELETE \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      "$POLARIS_URL/api/management/v1/catalogs/lakehouse"
  else
    echo "ℹ️  Using existing catalog"
    exit 0
  fi
fi

# Create catalog with MinIO endpoint
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

if echo "$CATALOG_RESPONSE" | grep -q '"error"'; then
  echo "❌ Failed to create catalog"
  echo "Response: $CATALOG_RESPONSE"
  exit 1
fi

echo "✅ Catalog created successfully"

# Create a catalog role with full permissions
echo "👤 Creating catalog admin role..."
ROLE_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$POLARIS_URL/api/management/v1/catalogs/lakehouse/catalog-roles" \
  -d '{
    "catalogRole": {
      "name": "catalog_admin"
    }
  }')

echo "✅ Catalog role created"

# Grant all catalog privileges
echo "🔑 Granting catalog privileges..."
for privilege in "CATALOG_MANAGE_CONTENT" "CATALOG_MANAGE_ACCESS" "TABLE_CREATE" "TABLE_LIST" "TABLE_READ_DATA" "TABLE_WRITE_DATA" "NAMESPACE_CREATE" "NAMESPACE_LIST"; do
  curl -s -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    "$POLARIS_URL/api/management/v1/catalogs/lakehouse/catalog-roles/catalog_admin/grants" \
    -d "{\"type\": \"catalog\", \"privilege\": \"$privilege\"}" > /dev/null
done

echo "✅ Privileges granted"

# Assign the catalog role to root principal
echo "🔗 Assigning role to root principal..."
ASSIGN_RESPONSE=$(curl -s -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$POLARIS_URL/api/management/v1/principal-roles/catalog-admin/catalog-roles/lakehouse" \
  -d '{
    "catalogRole": {
      "name": "catalog_admin"
    }
  }')

echo "✅ Role assigned"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Polaris setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Catalog configuration:"
echo "  📦 Name: lakehouse"
echo "  🗄️  Type: INTERNAL"
echo "  📍 Default location: s3://warehouse/"
echo "  🔓 Allowed locations: s3://warehouse/, s3://raw-data/"
echo "  💾 Storage: MinIO at http://minio:9000"
echo "  🔐 Permissions: Full catalog admin access granted"
echo ""
echo "⚠️  IMPORTANT: Update Trino configuration"
echo ""
echo "Edit trino/catalog/lakehouse.properties and update this line:"
echo "  iceberg.rest-catalog.oauth2.credential=$CLIENT_ID:$CLIENT_SECRET"
echo ""
echo "Then restart Trino:"
echo "  docker compose restart trino"
echo ""
echo "Test it:"
echo "  docker compose exec trino trino"
echo "  CREATE SCHEMA lakehouse.raw_data WITH (location = 's3://raw-data/');"
echo ""
echo "🎉 Done!"
