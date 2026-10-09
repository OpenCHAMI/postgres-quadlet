# postgres-quadlet

Podman Quadlet packaging for the Postgres database of an OpenCHAMI
deployment. The RPM ships `postgres.container`, a `10-defaults.conf`
drop-in carrying the deployment glue (volumes, secrets, networks), the
`postgres-data` volume, and `multi-psql-db.sh`, which creates the
per-service databases on first start. Upstream Postgres is pulled from
`docker.io/library/postgres`; this package's version tracks the
packaging, not Postgres itself.

## Usage

```bash
make rpm-build
sudo dnf install ./dist/rpmbuild/RPMS/noarch/openchami-postgres-quadlet-*.rpm
smd_pw="$(openssl rand -base64 30)"
printf '%s' "$(openssl rand -base64 30)" | sudo podman secret create postgres_password -
printf '%s' "$smd_pw" | sudo podman secret create smd_postgres_password -
printf '%s' "hmsds:smd-user:$smd_pw" | sudo podman secret create postgres_multiple_databases -
sudo systemctl daemon-reload && sudo systemctl start postgres.service
```

Override settings with a drop-in numbered greater than `10-xxx` under
`/etc/containers/systemd/postgres.container.d/`, not by editing the
packaged one. Note `postgres_multiple_databases` (comma-separated
`database:user:password triples`) applies on first start only:
changing it later requires discarding the `postgres-data` volume.
