# Vendor-Agnostic Modern Data Stack

A complete modern data lakehouse implementation using 100% open-source tools, demonstrating federation, transformation, and analytics with full data sovereignty.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://www.docker.com/)
[![Open Source](https://img.shields.io/badge/Open%20Source-100%25-green)](https://opensource.org/)

---

## 🎯 What This Project Demonstrates

- **Data Federation**: Query across PostgreSQL, MySQL, and object storage (MinIO) in real-time without data movement
- **Modern Transformations**: SQL-based data modeling with dbt Core, version-controlled and tested
- **Semantic Layer**: Business metrics with Cube.js including pre-aggregation
- **Self-Service BI**: Dashboards with Metabase for business users
- **Data Sovereignty**: 100% self-hosted, GDPR-compliant architecture
- **Infrastructure as Code**: All configurations in Git, enabling true DataOps practices
- **Hybrid Deployment**: Architecture supports mixing self-hosted and managed cloud services

**Read the full article**: [Is a Vendor-Agnostic Modern Data Stack Possible?](LINK_TO_YOUR_LINKEDIN_ARTICLE)

---

## 🏗️ Architecture

```
PostgreSQL (Orders)  ────┐
MySQL (Products)     ────┼──> Trino ──> dbt ──> Cube.js ──> Metabase
MinIO (Events)       ────┘
```

### Technology Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| **Storage** | MinIO | S3-compatible object storage for lakehouse |
| **Databases** | PostgreSQL, MySQL | Operational data sources |
| **Federation** | Trino | Cross-database query engine (35+ connectors) |
| **Transformation** | dbt Core | SQL-based data modeling with testing |
| **Semantic** | Cube.js | Metrics layer with RLS/CLS and caching |
| **Visualization** | Metabase | Self-service BI platform |
| **Orchestration** | Docker Compose | Local deployment and coordination |

---

## 🚀 Quick Start

### Prerequisites

- **Docker** and **Docker Compose** installed
- **16GB RAM** minimum (8GB works but slower)
- **Basic SQL** knowledge helpful
- **Git** for version control

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/vincevv017/modern-data-stack.git
cd modern-data-stack

# 2. Start all services (takes 2-3 minutes)
docker compose up -d

# 3. Wait for services to be ready
sleep 120

# 4. Run dbt transformations to build analytics tables
docker compose exec dbt dbt run
```

### Access the User Interfaces

- **Trino UI**: http://localhost:8080
- **Cube.js Playground**: http://localhost:4000
- **Metabase**: http://localhost:3000
- **MinIO Console**: http://localhost:9001
  - Username: `admin`
  - Password: `password123`

### Try the Demo Query

Test federation across all data sources:

```bash
docker compose exec trino trino --execute "
SELECT 
    product_name,
    supplier_country,
    SUM(revenue) as total_revenue
FROM postgres.analytics_marts.fct_orders
GROUP BY product_name, supplier_country
ORDER BY total_revenue DESC
LIMIT 5;"
```

This query joins data across PostgreSQL and MySQL, applies dbt transformations, and returns aggregated results—demonstrating the entire stack in one command.

---

## 📊 Sample Data

The stack includes synthetic e-commerce data:

- **PostgreSQL**: 50+ order transactions with amounts, dates, and statuses
- **MySQL**: Product catalog with 7 products and 5 suppliers across multiple countries
- **MinIO**: User event data in Parquet format (page views, add-to-cart events)

All sample data is automatically loaded when services start for the first time.

---

## 🔧 Project Structure

```
modern-data-stack/
├── docker-compose.yml           # Infrastructure as code
├── .gitignore                   # Git exclusions
├── README.md                    # This file
├── LICENSE                      # MIT License
├── cube/
│   ├── cube.js                  # Cube.js configuration
│   └── model/
│       └── Orders.js            # Semantic layer definitions
├── dbt/
│   ├── dbt_project.yml          # dbt configuration
│   ├── profiles.yml             # Connection profiles
│   └── models/
│       ├── staging/             # Source data cleaning
│       ├── intermediate/        # Business logic
│       └── marts/               # Analytics-ready tables
├── trino/
│   ├── catalog/
│   │   ├── postgres.properties  # PostgreSQL connector
│   │   ├── mysql.properties     # MySQL connector
│   │   └── lakehouse.properties # MinIO/Hive connector
│   └── config/
│       └── config.properties    # Trino configuration
├── init-scripts/
│   ├── postgres/
│   │   └── 01-init-greencard-data.sql
│   └── mysql/
│       └── 01-init-catalog-data.sql
└── lakehouse-data/
    └── user_events/     
│       └── 01-init-catalog-data.sql # Sample lakehouse data
```

---

## 💡 Key Features

### Data Federation

Query across multiple databases in real-time without ETL:

```sql
-- Single query spanning three different systems
SELECT 
    o.order_id,
    p.product_name,
    s.country,
    e.event_type
FROM postgres.public.orders o
LEFT JOIN mysql.catalog_db.products p ON o.product_id = p.id
LEFT JOIN mysql.catalog_db.suppliers s ON p.supplier_id = s.id
LEFT JOIN lakehouse.raw_data.user_events e ON o.customer_id = e.user_id;
```

### Semantic Layer with Security

Cube.js provides:
- **Single source of truth** for business metrics
- **Pre-aggregations** for sub-second query performance
- **Row-level security (RLS)** - restrict data by user role
- **Column-level security (CLS)** - hide sensitive columns
- **Multi-tenancy** support out of the box

### Git-Based Development

All configurations are version-controlled:

```bash
# Make changes to dbt models
vim dbt/models/marts/fct_orders.sql

# Test locally
docker compose exec dbt dbt run --select fct_orders
docker compose exec dbt dbt test

# Commit to version control
git add dbt/models/marts/fct_orders.sql
git commit -m "Add customer segment to orders fact table"
git push

# Deploy to production (via CI/CD pipeline)
```

---

## 🔐 Security Features

- **Data sovereignty** - complete control over data location (critical for GDPR compliance)
- **Audit logging** - track all data access
- **Network isolation** - services communicate on private Docker network

---

## 📈 Scaling to Production

This demo runs on Docker Compose. For production, consider:

### Infrastructure Evolution
- **Kubernetes**: Replace Docker Compose for orchestration and auto-scaling
- **Cloud Storage**: AWS S3, Google Cloud Storage, or Azure Blob instead of MinIO
- **Monitoring**: Prometheus + Grafana for observability
- **Secrets Management**: HashiCorp Vault or cloud provider secrets
- **CI/CD**: GitHub Actions or GitLab CI for automated testing and deployment

### Managed Service Options

Each component has enterprise managed alternatives:

- **Starburst Galaxy**: Managed Trino with Warp Speed indexing and enterprise security
- **dbt Cloud**: Automated scheduling, IDE, and AI-powered SQL generation
- **Cube Cloud**: Auto-scaling, AI/BI frontend with agentic analytics
- **Metabase Cloud**: Automated backups, Metabot AI assistant, alerts/subscriptions

The architecture supports hybrid deployments—mix self-hosted and managed services based on your needs.

---


## 🐛 Troubleshooting

### Services won't start

```bash
# Check service status
docker compose ps

# View logs for specific service
docker compose logs trino
docker compose logs dbt
docker compose logs cubejs

# Restart specific service
docker compose restart trino
```

### Query failures in Trino

```bash
# Verify catalogs are loaded
docker compose exec trino trino --execute "SHOW CATALOGS;"

# Check catalog connectivity
docker compose exec trino trino --execute "SHOW SCHEMAS FROM postgres;"
docker compose exec trino trino --execute "SHOW SCHEMAS FROM mysql;"
```

### dbt failures

```bash
# Debug dbt connection
docker compose exec dbt dbt debug

# Run with verbose logging
docker compose exec dbt dbt run --select <model> --full-refresh --debug
```

### Reset everything

```bash
# Stop and remove all containers and volumes
docker compose down -v

# Restart fresh
docker compose up -d
sleep 120
docker compose exec dbt dbt run
```

---

## 📚 Documentation

- **Full Architecture Article**: [Link to LinkedIn article]
- **Trino Documentation**: https://trino.io/docs/current/
- **dbt Documentation**: https://docs.getdbt.com/
- **Cube.js Documentation**: https://cube.dev/docs/
- **Metabase Documentation**: https://www.metabase.com/docs/

---

## 🤝 Contributing

Contributions are welcome! This project demonstrates architectural patterns and can be extended in many ways:

### Potential Enhancements

- **Apache Iceberg**: Implement full lakehouse capabilities (ACID transactions, time travel)
- **Apache Airflow**: Add workflow orchestration for complex pipelines
- **Great Expectations**: Add comprehensive data quality testing
- **OpenLineage**: Implement end-to-end data lineage tracking

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly (`docker compose up -d` and verify)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

---

## ⚠️ Known Limitations

### What Works
✅ Federation across PostgreSQL, MySQL, and MinIO  
✅ dbt transformations with testing  
✅ Cube.js semantic layer with pre-aggregation
✅ Metabase self-service analytics  
✅ Docker Compose orchestration  
✅ Version-controlled infrastructure  

### What's Simplified
⚠️ **Apache Iceberg**: The demo uses file-based Hive metastore with Parquet files rather than full Iceberg implementation due to JAR dependency complexity on Apple Silicon  
⚠️ **Production readiness**: Docker Compose is suitable for development; production requires Kubernetes  
⚠️ **Monitoring**: Basic health checks included; comprehensive monitoring requires Prometheus/Grafana  
⚠️ **Security**: Development mode enabled; production requires OAuth/SAML, TLS, and secrets management  

See the full article for details on what worked and what didn't during implementation.

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

Built with amazing open-source projects:
- [Trino](https://trino.io) - Distributed SQL query engine
- [dbt](https://www.getdbt.com) - Data transformation tool
- [Cube.js](https://cube.dev) - Semantic layer platform
- [Metabase](https://www.metabase.com) - Business intelligence tool
- [MinIO](https://min.io) - S3-compatible object storage
- [PostgreSQL](https://www.postgresql.org) - Relational database
- [MySQL](https://www.mysql.com) - Relational database

---

## 📧 Contact

**LinkedIn**: [LinkedIn Profile]([https://www.linkedin.com/in/vincent-vikor-8662984/])

**Project Link**: https://github.com/vincevv017/modern-data-stack

---

## ⭐ Star History

If this project helped you understand modern data architectures or saved you money on cloud bills, please consider giving it a star!

[![Star History Chart](https://api.star-history.com/svg?repos=vincevv017/modern-data-stack&type=Date)](https://star-history.com/#vincevv017/modern-data-stack&Date)

---

**Built with ❤️ for the open-source data community**

*Demonstrating that vendor-agnostic, sovereignty-focused data infrastructure is not just possible—it's practical.*
