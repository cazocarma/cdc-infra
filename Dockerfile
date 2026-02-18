FROM mcr.microsoft.com/mssql/server:2022-latest

USER root
RUN mkdir -p /docker-entrypoint-initdb.d /usr/local/bin
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 750 /usr/local/bin/docker-entrypoint.sh && chown mssql:root /usr/local/bin/docker-entrypoint.sh
USER mssql

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
