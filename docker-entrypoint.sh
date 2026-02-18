#!/bin/bash
set -euo pipefail

INIT_MARKER="/var/opt/mssql/.cdc_initialized"

/opt/mssql/bin/sqlservr &
sql_pid=$!

echo "Waiting for SQL Server to be ready..."
for _ in {1..90}; do
  if /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "${MSSQL_SA_PASSWORD}" -Q "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if [ ! -f "${INIT_MARKER}" ]; then
  echo "Running one-time init scripts..."
  shopt -s nullglob
  for script in /docker-entrypoint-initdb.d/*.sql; do
    echo "Executing ${script}"
    /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "${MSSQL_SA_PASSWORD}" -d master -i "${script}"
  done
  shopt -u nullglob
  touch "${INIT_MARKER}"
else
  echo "Database already initialized, skipping init scripts."
fi

wait "${sql_pid}"
