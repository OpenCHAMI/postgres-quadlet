# Quadlet based Postgres Deployment for OpenCHAMI

This repository provides systemd quadlet based deployment and basic
configuration to support OpenCHAMI services running in the systemd
quadlet deployment model.

## Structure of the Repository

The files needed to build an openchami-postgres-quadlet package are
found in the `packaging/common` sub-tree, which is where any
additional files should be placed. The files needed for building an
RPM that deploys Postgres for use by OpenCHAMI in a quadlet deployment
are then symbolically linked from the `packaging/common` tree into the
`packaging/rpm-quadlet` tree where the rpm-build target of the
Makefile will expect to find them. As future package types and
deployment models are added to this repository, new `packaging/...`
sub-trees should be added that link new content from the
`packaging/common` sub-tree into themselves.

## Building an RPM for Quadlet Deployment

To build an RPM for quadlet deployment, simply clone this repository
and run `make rpm-build` in the root directory. To remove the build
artifacts and RPM run `make rpm-clean`. For RPM builds, the resulting
RPM file can be found in the

```
dist/rpmbuild/RPMS/noarch
```

sub-tree of the cloned repository.

To build all available package types, simply typing `make` in the root
of the clone is sufficient.

  NOTE: at present only Quadlet Deployment RPMs are available

## Installing `openchami-postgres-quadlet` from a Local Build

To install `openchami-postgres-quadlet` from a locally built RPM,
first navigate to the root of the repo where the RPM was built and
then issue the following command:

```bash
sudo dnf -y dist/rpmbuild/RPMS/noarch/openchami-postgres-quadlet-*.rpm
```

## Running OpenCHAMI Postgres Quadlet on an OpenCHAMI Management Node

Before starting Postgres on an OpenCHAMI management node some external
environment needs to be set up. Specifically, there are Podman secrets
that are used to deploy Postgres and there are networks that need to
be available to the OpenCHAMI quadlet services including
Postgres. Finally, Postgres can be started, stopped, restarted and so
forth using `systemctl`. An attempt is made upon installation of the
`openchami-postgres-quadlet` package to start Postgres. If this
attempt is successful, Postgres will be up and running at the
conclusion of installation.

### Setting up Secrets for OpenCHAMI Postgres Quadlet

Prior to starting this service, Podman needs to be minimally
configured with the following secrets:

- `postgres_password`

  the overall administrative password used for managing all databases.
  
- `smd_postgres_password`

  the password associated with the SMD Postgres user.

- `postgres_multiple_databases`

  a string containing a comma separated list of colon delimited
  triples in which each triple contains the name of a database served
  by Postgres, the username of the user who has access to that
  database, and the password of that user. At a minimum, this should
  contain:

    `hmsds:smd-user:<the value of smd_postgres_password above>`

  which describes the HSM Dataset used by SMD and its clients.

Each secret can be set by supplying the secret value on standard input
to the following command:

```bash
sudo podman secret create <secret-name> - > /dev/null
```

The redirection into `/dev/null` here is needed to keep the secret
from being written to standard output by the `podman` command and,
potentially, captured in logs.

Since it is best to keep the secret values off of the command line, it
is best to generate or retrieve secret data programmatically and pipe
it into the above. For example:

```bash
openssl rand -base64 32 | \
    tr -d '\n' | \
    sudo podman secret create smd_postgres_password - > /dev/null
```

or
```bash
SMD_PASSWORD="$(\
    sudo podman secret inspect smd_postgres_password --showsecret | \
    jq -r '.[0].SecretData'\
)" && \
echo -n "hmsds:smd-user:$SMD_PASSWORD" | \
    sudo podman secret create postgres_multiple_databases - > /dev/null
```

### Required Networks for the OpenCHAMI Postgres Quadlet

For deployments of OpenCHAMI on a single management host, the default
configuration, there are two Podman supplied networks required by
Postgres to allow it to interact with other OpenCHAMI components. In
the default configuration these are:

- `openchami-internal.network`

The network used for general network traffic between component and
proxied traffic arriving from managed nodes. On a single management
host cluster, this is a virtual network within Podman provided by a
separate package outside the scope of the Postgres wrapper.

- `openchami-jwt-internal.network`

A separate network used for securely isolated traffic relating to JWT
verificatoin and cryptographic key distribution within the OpenCHAMI
management plane. On a single management host cluster, this is a
virtual network within Podman provided by a separate package outside
the scope of the Postgres wrapper.

### Configuring the Quadlet Container for OpenCHAMI Postgres Quadlet

This package installs a default deployment configuration found in 

```
/usr/share/containers/systemd/postgres.container.d/10-defaults.conf
```

Any values in this file can be overridden by creating a podman drop-in
configuration numbered higher than `10-` and placed in

```
/etc/containers/systemd/postgres.container.d/
```

### Starting the OpenCHAMI Postgres Service on a Management Node

This service declares itself as part of the `openchami.target`
dependencies, and should start with the following command once
`openchami.target` is defined:

```bash
systemctl start openchami.target
```

Similar commands for stopping, reloading and restarting `openchami.target` are available.

To start the Postgres service by itself, use:

```
systemctl start postgres.service
```

and use the corresponding `systemctl` commands for other operations on
the service.
