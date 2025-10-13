.PHONY: help start stop restart logs clean urls test-trino

help:
@echo "Modern Data Stack - Local Development"
@echo ""
@echo "Usage:"
@echo "  make start       - Start all containers"
@echo "  make stop        - Stop all containers"
@echo "  make restart     - Restart all containers"
@echo "  make logs        - Show container logs"
@echo "  make clean       - Remove all containers and volumes"
@echo "  make urls        - Show all service URLs"
@echo "  make test-trino  - Test Trino connection"

start:
docker compose up -d
@echo "⏳ Waiting for services to be healthy (60 seconds)..."
@sleep 60
@make urls

stop:
docker compose down

restart:
docker compose restart

logs:
docker compose logs -f

clean:
docker compose down -v
@echo "⚠️  All data has been removed!"

urls:
@echo ""
@echo "🚀 Service URLs:"
@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
@echo "MinIO Console:    http://localhost:9001"
@echo "  User: admin / Pass: password123"
@echo ""
@echo "Trino UI:         http://localhost:8080"
@echo ""
@echo "Cube.js:          http://localhost:4000"
@echo "Cube.js Dev:      http://localhost:3001"
@echo ""
@echo "Metabase:         http://localhost:3000"
@echo ""
@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
@echo ""

test-trino:
@echo "Testing Trino connection..."
docker compose exec -T trino trino --execute "SHOW CATALOGS;"
@echo ""
@echo "Testing PostgreSQL connection..."
docker compose exec -T trino trino --execute "SELECT COUNT(*) as order_count FROM postgres.public.orders;"
@echo ""
@echo "Testing MySQL connection..."
docker compose exec -T trino trino --execute "SELECT COUNT(*) as product_count FROM mysql.catalog_db.products;"
