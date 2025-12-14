#!/bin/bash

# Quick fix - Recreate Polaris catalog with your working credentials

set -e

echo "🔧 Recreating Polaris Catalog"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Your working credentials from yesterday
CLIENT_ID="42f137db0abd914c"
CLIENT_SECRET="d8306177805c259a74f21b5cf72a4e9f"
POLARIS_URL="http://localhost:8181"

echo "1️⃣  Authenticating to Polaris..."
TOKEN=$(curl -s -X POST "$POLARIS_URL/api/catalog/v1/oauth/tokens" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=PRINCIPAL_ROLE:ALL" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "  ❌ Authentication failed"
  echo "  Your credentials might have changed"
  exit 1
fi

echo "  ✅ Authenticated"
echo ""

echo "2️⃣  Checking if catalog exists..."
CATALOG_CHECK=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$POLARIS_URL/api/management/v1/catalogs/lakehouse")

if echo "$CATALOG_CHECK" | grep -q '"name":"lakehouse"'; then
  echo "  ⚠️  Catalog already exists"
  read -p "  Delete and recreate? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  Deleting catalog..."
    curl -s -X DELETE -H "Authorization: Bearer $TOKEN" \
      "$POLARIS_URL/api/management/v1/catalogs/lakehouse"
    echo "  ✅ Deleted"
  else
    echo "  Keeping existing catalog"
    exit 0
  fi
fi
echo ""

echo "3️⃣  Creating lakehouse catalog..."
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
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

if echo "$RESPONSE" | grep -q '"name":"lakehouse"'; then
  echo "  ✅ Catalog created successfully"
else
  echo "  ❌ Failed to create catalog"
  echo "  Response: $RESPONSE"
  exit 1
fi
echo ""

echo "4️⃣  Granting permissions..."
# Create catalog role
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  "$POLARIS_URL/api/management/v1/catalogs/lakehouse/catalog-roles" \
  -d '{"catalogRole": {"name": "catalog_admin"}}' > /dev/null

# Grant privileges
for privilege in "CATALOG_MANAGE_CONTENT" "CATALOG_MANAGE_ACCESS" "TABLE_CREATE" "TABLE_LIST" "TABLE_READ_DATA" "TABLE_WRITE_DATA" "NAMESPACE_CREATE" "NAMESPACE_LIST"; do
  curl -s -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    "$POLARIS_URL/api/management/v1/catalogs/lakehouse/catalog-roles/catalog_admin/grants" \
    -d "{\"type\": \"catalog\", \"privilege\": \"$privilege\"}" > /dev/null
done

# Assign role
curl -s -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  "$POLARIS_URL/api/management/v1/principal-roles/catalog-admin/catalog-roles/lakehouse" \
  -d '{"catalogRole": {"name": "catalog_admin"}}' > /dev/null

echo "  ✅ Permissions granted"
echo ""

echo "5️⃣  Restarting Trino..."
docker-compose restart trino >/dev/null 2>&1
echo "  ⏳ Waiting for Trino to restart..."
sleep 10
echo "  ✅ Trino restarted"
echo ""

echo "6️⃣  Verifying..."
if docker-compose exec -T trino trino --execute "SHOW CATALOGS" 2>&1 | grep -q "lakehouse"; then
  echo "  ✅ Trino can see lakehouse catalog"
else
  echo "  ⚠️  Trino cannot see lakehouse catalog yet"
  echo "     Wait a few more seconds and try: docker-compose exec trino trino"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Catalog recreated!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Create schemas:"
echo "     docker-compose exec trino trino --execute \""
echo "       CREATE SCHEMA IF NOT EXISTS lakehouse.staging;"
echo "       CREATE SCHEMA IF NOT EXISTS lakehouse.intermediate;"
echo "       CREATE SCHEMA IF NOT EXISTS lakehouse.marts;\""
echo ""
echo "  2. Run dbt:"
echo "     docker-compose exec dbt dbt run"
echo ""
