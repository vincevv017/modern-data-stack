#!/bin/bash
# setup-lakehouse-schemas.sh - UPDATED VERSION
# Creates required schemas in lakehouse catalog

set -e

echo "🏗️  Setting up Lakehouse schemas..."
echo ""

# Check if Trino is running
if ! docker-compose ps trino | grep -q "Up"; then
  echo "❌ Trino is not running. Please start it first:"
  echo "   docker-compose up -d trino"
  exit 1
fi

echo "✅ Trino is running"
echo ""

# Check if lakehouse catalog exists
echo "🔍 Checking lakehouse catalog..."
CATALOGS=$(docker-compose exec -T trino trino --execute "SHOW CATALOGS" 2>&1 | grep -v "WARNING")

if ! echo "$CATALOGS" | grep -q "lakehouse"; then
  echo "❌ lakehouse catalog not found!"
  echo "Available catalogs:"
  echo "$CATALOGS"
  echo ""
  echo "Please verify:"
  echo "  1. Polaris is running: docker-compose ps polaris"
  echo "  2. lakehouse.properties exists: cat trino/catalog/lakehouse.properties"
  echo "  3. Polaris is configured: bash setup-polaris.sh"
  exit 1
fi

echo "✅ lakehouse catalog exists"
echo ""

# Try creating schemas WITHOUT location clause first (simpler)
echo "📁 Creating lakehouse schemas (simple mode)..."

# Staging schema
echo "  Creating lakehouse.staging..."
docker-compose exec -T trino trino --execute "
CREATE SCHEMA IF NOT EXISTS lakehouse.staging
" 2>&1 | grep -v "WARNING" || echo "    (may already exist)"

# Intermediate schema  
echo "  Creating lakehouse.intermediate..."
docker-compose exec -T trino trino --execute "
CREATE SCHEMA IF NOT EXISTS lakehouse.intermediate
" 2>&1 | grep -v "WARNING" || echo "    (may already exist)"

# Marts schema
echo "  Creating lakehouse.marts..."
docker-compose exec -T trino trino --execute "
CREATE SCHEMA IF NOT EXISTS lakehouse.marts
" 2>&1 | grep -v "WARNING" || echo "    (may already exist)"

echo ""
echo "✅ Schemas created successfully"
echo ""

# Verify schemas
echo "🔍 Verifying schemas..."
SCHEMAS=$(docker-compose exec -T trino trino --execute "SHOW SCHEMAS IN lakehouse" 2>&1 | grep -v "WARNING")

if echo "$SCHEMAS" | grep -q "staging" && \
   echo "$SCHEMAS" | grep -q "intermediate" && \
   echo "$SCHEMAS" | grep -q "marts"; then
  echo "✅ All schemas verified:"
  echo "$SCHEMAS" | sed 's/^/    /'
  echo ""
else
  echo "❌ Schema verification failed"
  echo "Found schemas:"
  echo "$SCHEMAS"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Lakehouse schemas ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Created schemas:"
echo "  ✓ lakehouse.staging"
echo "  ✓ lakehouse.intermediate"
echo "  ✓ lakehouse.marts"
echo ""
echo "🚀 Next steps:"
echo "  1. Update profiles.yml: cp profiles.yml dbt/profiles.yml"
echo "  2. Update dbt_project.yml: cp dbt_project.yml dbt/dbt_project.yml"
echo "  3. Update Orders.js: cp Orders.js cube/schema/Orders.js"
echo "  4. Run dbt: docker-compose exec dbt dbt run"
echo ""
echo "ℹ️  Note: Schemas created without explicit S3 locations."
echo "   Iceberg will use default locations under the catalog's base path."
echo ""