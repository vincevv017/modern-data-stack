#!/bin/bash

# Quick diagnostic - what broke between yesterday and today?

echo "🔍 Quick Lakehouse Diagnostics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Check if lakehouse catalog exists in Polaris
echo "1️⃣  Checking if Polaris still has the lakehouse catalog..."
TOKEN=$(curl -s -X POST http://localhost:8181/api/catalog/v1/oauth/tokens \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=c0eb8bd3cf05ffaa" \
  -d "client_secret=7657a109c2c9473bb9cc00992417f877" \
  -d "scope=PRINCIPAL_ROLE:ALL" 2>&1)

if echo "$TOKEN" | grep -q "access_token"; then
  echo "  ✅ Can authenticate to Polaris"
  ACCESS_TOKEN=$(echo "$TOKEN" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
  
  CATALOG=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
    http://localhost:8181/api/management/v1/catalogs/lakehouse)
  
  if echo "$CATALOG" | grep -q '"name":"lakehouse"'; then
    echo "  ✅ Catalog 'lakehouse' exists in Polaris"
  else
    echo "  ❌ Catalog 'lakehouse' NOT FOUND in Polaris"
    echo "     This is likely the problem!"
    echo ""
    echo "  Fix: Recreate the catalog"
    echo "    bash setup-polaris.sh"
    exit 1
  fi
else
  echo "  ❌ Cannot authenticate to Polaris"
  echo "     Response: $TOKEN"
  exit 1
fi
echo ""

# 2. Check if Trino can see lakehouse catalog
echo "2️⃣  Checking if Trino can see lakehouse catalog..."
CATALOGS=$(docker-compose exec -T trino trino --execute "SHOW CATALOGS" 2>&1)

if echo "$CATALOGS" | grep -q "lakehouse"; then
  echo "  ✅ Trino can see lakehouse catalog"
else
  echo "  ❌ Trino CANNOT see lakehouse catalog"
  echo "     Available catalogs:"
  echo "$CATALOGS" | sed 's/^/       /'
  echo ""
  echo "  This means Trino cannot connect to Polaris"
  echo ""
  echo "  Check trino/catalog/lakehouse.properties has correct credentials:"
  echo "    iceberg.rest-catalog.oauth2.credential=c0eb8bd3cf05ffaa:7657a109c2c9473bb9cc00992417f877"
  exit 1
fi
echo ""

# 3. Try to query existing schemas
echo "3️⃣  Checking existing schemas in lakehouse..."
SCHEMAS=$(docker-compose exec -T trino trino --execute "SHOW SCHEMAS IN lakehouse" 2>&1)

if echo "$SCHEMAS" | grep -q "Query.*failed"; then
  echo "  ❌ Cannot query schemas - 'Cannot obtain metadata' error"
  echo ""
  echo "  This usually means:"
  echo "    - Polaris lost its catalog configuration"
  echo "    - MinIO is not accessible"
  echo "    - Catalog was deleted/recreated"
else
  echo "  ✅ Can query schemas"
  echo "     Existing schemas:"
  echo "$SCHEMAS" | sed 's/^/       /'
fi
echo ""

# 4. Check MinIO
echo "4️⃣  Checking MinIO accessibility..."
if docker-compose exec -T mc mc ls myminio/warehouse >/dev/null 2>&1; then
  echo "  ✅ MinIO warehouse bucket is accessible"
else
  echo "  ❌ Cannot access MinIO warehouse bucket"
  exit 1
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Most Likely Issue:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The lakehouse catalog was probably deleted or Polaris was restarted."
echo ""
echo "🔧 Fix:"
echo "  1. Recreate the catalog in Polaris:"
echo ""
echo "     TOKEN=\$(curl -s -X POST http://localhost:8181/api/catalog/v1/oauth/tokens \\"
echo "       -H \"Content-Type: application/x-www-form-urlencoded\" \\"
echo "       -d \"grant_type=client_credentials\" \\"
echo "       -d \"client_id=c0eb8bd3cf05ffaa\" \\"
echo "       -d \"client_secret=7657a109c2c9473bb9cc00992417f877\" \\"
echo "       -d \"scope=PRINCIPAL_ROLE:ALL\" | grep -o '\"access_token\":\"[^\"]*' | cut -d'\"' -f4)"
echo ""
echo "     curl -X POST -H \"Content-Type: application/json\" -H \"Authorization: Bearer \$TOKEN\" \\"
echo "       http://localhost:8181/api/management/v1/catalogs -d '{"
echo "         \"catalog\": {\"name\": \"lakehouse\", \"type\": \"INTERNAL\","
echo "           \"properties\": {\"default-base-location\": \"s3://warehouse/\"},"
echo "           \"storageConfigInfo\": {\"storageType\": \"S3\","
echo "             \"allowedLocations\": [\"s3://warehouse/\", \"s3://raw-data/\"],"
echo "             \"endpoint\": \"http://minio:9000\", \"pathStyleAccess\": true}}}'"
echo ""
echo "  2. Restart Trino:"
echo "     docker-compose restart trino"
echo ""
echo "  3. Try creating schemas again"
echo ""
