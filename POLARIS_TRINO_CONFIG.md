# Polaris + Trino Configuration Notes

## Critical Configuration: fs.native-s3.enabled=true

Essential property for Polaris + MinIO + Trino:
```properties
fs.native-s3.enabled=true
```

Without this, you'll get: "No factory for location: s3://warehouse/..." errors.

## Complete Working Configuration

See trino/catalog/lakehouse.properties for full configuration.
