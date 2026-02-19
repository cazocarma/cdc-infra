#!/bin/bash
set -euo pipefail

INIT_MARKER="/var/opt/mssql/.cdc_initialized"
SCRIPTS_DIR="${DB_INIT_SCRIPTS_DIR:-/docker-entrypoint-initdb.d}"
INIT_MODE="${DB_INIT_MODE:-once}" # once | always
RUN_DOWN="${DB_INIT_RUN_DOWN:-true}"

/opt/mssql/bin/sqlservr &
sql_pid=$!

echo "Waiting for SQL Server to be ready..."
ready=0
for _ in {1..90}; do
  if /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "${MSSQL_SA_PASSWORD}" -Q "SELECT 1" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done

if [ "${ready}" -ne 1 ]; then
  echo "SQL Server was not ready in expected time."
  kill "${sql_pid}" >/dev/null 2>&1 || true
  exit 1
fi

run_sql() {
  local file_path="$1"
  local can_fail="${2:-false}"
  if [ -f "${file_path}" ]; then
    echo "Executing ${file_path}"
    if ! /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "${MSSQL_SA_PASSWORD}" -d master -b -i "${file_path}"; then
      if [ "${can_fail}" = "true" ]; then
        echo "Warning: ${file_path} failed, continuing..."
      else
        echo "Error: ${file_path} failed."
        return 1
      fi
    fi
  fi
}

run_additional_scripts() {
  local down_file="${SCRIPTS_DIR}/DOWN.sql"
  local up_file="${SCRIPTS_DIR}/UP.sql"
  local seed_file="${SCRIPTS_DIR}/SEED.sql"

  shopt -s nullglob
  for script in "${SCRIPTS_DIR}"/*.sql; do
    if [ "${script}" = "${down_file}" ] || [ "${script}" = "${up_file}" ] || [ "${script}" = "${seed_file}" ]; then
      continue
    fi
    run_sql "${script}" false
  done
  shopt -u nullglob
}

should_run_init=0
if [ "${INIT_MODE}" = "always" ]; then
  should_run_init=1
  rm -f "${INIT_MARKER}"
elif [ "${INIT_MODE}" = "once" ]; then
  if [ ! -f "${INIT_MARKER}" ]; then
    should_run_init=1
  fi
else
  echo "Unsupported DB_INIT_MODE=${INIT_MODE}. Use 'once' or 'always'."
  kill "${sql_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if [ "${should_run_init}" -eq 1 ]; then
  echo "Running database init scripts from ${SCRIPTS_DIR} (mode=${INIT_MODE})..."

  down_file="${SCRIPTS_DIR}/DOWN.sql"
  up_file="${SCRIPTS_DIR}/UP.sql"
  seed_file="${SCRIPTS_DIR}/SEED.sql"

  if [ "${RUN_DOWN}" = "true" ]; then
    run_sql "${down_file}" true
  fi
  run_sql "${up_file}" false
  run_sql "${seed_file}" false
  run_additional_scripts

  if [ ! -f "${up_file}" ] && [ ! -f "${seed_file}" ]; then
    echo "UP.sql/SEED.sql not found, executing *.sql files in lexical order."
    shopt -s nullglob
    for script in "${SCRIPTS_DIR}"/*.sql; do
      run_sql "${script}" false
    done
    shopt -u nullglob
  fi

  touch "${INIT_MARKER}"
  echo "Database init completed."
else
  echo "Database already initialized, skipping init scripts (mode=${INIT_MODE})."
fi

wait "${sql_pid}"
