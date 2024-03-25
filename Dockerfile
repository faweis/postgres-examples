FROM flyway/flyway:9.15-alpine as base

COPY ./migrations/ /flyway/sql/
USER root
ENTRYPOINT ["flyway", "migrate"]
