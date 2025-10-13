FROM trinodb/trino:435

# Preserve existing jars and copy new ones on top
COPY trino-jars/*.jar /usr/lib/trino/plugin/hive/lib/
COPY hadoop-conf/core-site.xml /etc/hadoop/conf/core-site.xml
