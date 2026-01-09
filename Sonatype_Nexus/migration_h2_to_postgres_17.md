#!/bin/bash
#
# Nexus Repository H2 → PostgreSQL Migration Summary
# Alma Linux / PostgreSQL / Nexus Repository
#
# This script documents the exact steps taken to migrate
# Nexus Repository from the embedded H2 database to PostgreSQL.
#
# It is NOT meant to be run end-to-end automatically.
# Each step must be executed deliberately and verified.
#
# This migration was performed on an Alma Linux 10 Server 
# Postgres Version: 17

###############################################################################
# 1. Preconditions
###############################################################################

# - Nexus Repository installed and running
# - Nexus version supports PostgreSQL
# - PostgreSQL installed and running (Version 17)
# - Nexus service STOPPED before migration
# - H2 database still present
#
# Verify Nexus is stopped:
#   systemctl stop nexus
#   systemctl status nexus

###############################################################################
# 2. PostgreSQL Preparation
###############################################################################

# Login to PostgreSQL as superuser:
#   sudo -u postgres psql

# Create PostgreSQL role for Nexus:
#   CREATE ROLE nexus
#     WITH LOGIN
#     PASSWORD 'STRONG_PASSWORD'
#     NOSUPERUSER
#     NOCREATEDB
#     NOCREATEROLE;

# Create PostgreSQL database:
#   CREATE DATABASE nexus
#     OWNER nexus
#     ENCODING 'UTF8'
#     LC_COLLATE = 'en_US.UTF-8'
#     LC_CTYPE  = 'en_US.UTF-8'
#     TEMPLATE template0;

# Connect to database:
#   \c nexus

# Create schema owned by Nexus:
#   CREATE SCHEMA nexus AUTHORIZATION nexus;

# Set default schema search path:
#   ALTER ROLE nexus SET search_path = nexus;

###############################################################################
# 3. PostgreSQL Extensions
###############################################################################

# Extensions must be created by a superuser,
# but should be OWNED by the Nexus role.

# Ensure a clean state:
#   DROP EXTENSION IF EXISTS pg_trgm;

# Temporarily assume the Nexus role so ownership is correct:
#   SET ROLE nexus;

# Create the extension inside the Nexus schema:
#   CREATE EXTENSION pg_trgm SCHEMA nexus;

# Return to superuser role:
#   RESET ROLE;

# Verify extension installation:
#   \dx


###############################################################################
# 4. Run Nexus DB Migrator
###############################################################################

# Navigate to the Nexus H2 database directory:
#   cd /opt/nexus/sonatype-work/nexus3/db

# Verify H2 files exist (e.g. nexus.mv.db)

# Run the migrator from this directory:
#
#   java -Xmx8G -Xms8G -XX:+UseG1GC -XX:MaxDirectMemorySize=2G \
#     -jar nexus-db-migrator-*.jar \
#     --migration_type=h2_to_postgres \
#     --db_url="jdbc:postgresql://localhost:5432/nexus?user=nexus&password=STRONG_PASSWORD&currentSchema=nexus"
#
# Expected result:
#   [COMPLETED]

###############################################################################
# 5. Post-Migration Database Cleanup
###############################################################################

# Reclaim space and analyze tables:
#   sudo -u postgres psql nexus
#   VACUUM (FULL, ANALYZE, VERBOSE);

###############################################################################
# 6. Configure Nexus to Use PostgreSQL
###############################################################################

# Edit the active Nexus configuration file:
#   /opt/nexus/sonatype-work/nexus3/etc/nexus.properties
#
# Add:
#
#   nexus.datastore.enabled=true
#   nexus.datastore.nexus.jdbcUrl=jdbc:postgresql://localhost:5432/nexus
#   nexus.datastore.nexus.username=nexus
#   nexus.datastore.nexus.password=STRONG_PASSWORD
#   nexus.datastore.nexus.schema=nexus
#
# Ensure NO H2 configuration remains.

###############################################################################
# 7. Start Nexus and Verify
###############################################################################

# Start Nexus:
#   systemctl start nexus

# Monitor logs:
#   tail -f /opt/nexus/sonatype-work/nexus3/log/nexus.log

# Verify:
# - PostgreSQL is used as datastore
# - No H2 references
# - Repositories and artifacts are accessible

###############################################################################
# End of Migration Summary
###############################################################################
