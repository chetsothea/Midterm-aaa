#!/usr/bin/env bash
# Creates (first time) or starts the phoneshop_mysql container.
# Credentials come from ../.env so they never have to be typed or shown.
# Usage (Git Bash):  bash docker/start-mysql.sh
set -euo pipefail
cd "$(dirname "$0")/.."

env_value() { grep -E "^$1=" .env | head -1 | cut -d= -f2- | tr -d '"\r'; }

if docker ps -a --format '{{.Names}}' | grep -qx phoneshop_mysql; then
  docker start phoneshop_mysql >/dev/null
  echo "phoneshop_mysql started (existing data kept)"
  exit 0
fi

# Exported, then passed with "-e NAME" (no value) so they stay out of the process list
export MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$(env_value DB_DATABASE)
MYSQL_USER=$(env_value DB_USERNAME)
MYSQL_PASSWORD=$(env_value DB_PASSWORD)
MYSQL_ROOT_PASSWORD=$(env_value DB_ROOT_PASSWORD)

# MSYS_NO_PATHCONV stops Git Bash from rewriting the container paths below
MSYS_NO_PATHCONV=1 docker run -d \
  --name phoneshop_mysql \
  --restart unless-stopped \
  -p 3307:3306 \
  -e MYSQL_DATABASE -e MYSQL_USER -e MYSQL_PASSWORD -e MYSQL_ROOT_PASSWORD \
  -v phoneshop_mysql_data:/var/lib/mysql \
  -v "$(pwd -W)/docker/phoneshop_db_backup.sql:/docker-entrypoint-initdb.d/01-phoneshop.sql:ro" \
  mysql:8.4 \
  --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci >/dev/null

echo "phoneshop_mysql created; importing the backup on first start..."
