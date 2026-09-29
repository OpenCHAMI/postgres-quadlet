# SPDX-FileCopyrightText: 2026 OpenCHAMI Contributors
# SPDX-License-Identifier: MIT

Name:           openchami-postgres-quadlet
Version:        %{version}
Release:        %{rel}%{?dist}
Summary:        OpenCHAMI Postgres Quadlet units

License:        MIT
URL:            https://github.com/OpenCHAMI/postgres-quadlet
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

Requires(post,preun,postun):  systemd
Requires:                     podman >= 5.0.0

%description
Podman Quadlet unit files (container + volume) for running Postgres
as part of an OpenCHAMI deployment.

%prep
%setup -q

%install
install -d %{buildroot}/usr/share/containers/systemd
install -d %{buildroot}/etc/openchami/pg-init
install -m 644 multi-psql-db.sh %{buildroot}/etc/openchami/pg-init/
install -m 644 postgres.container %{buildroot}/usr/share/containers/systemd/
install -d %{buildroot}/usr/share/containers/systemd/postgres.container.d
install -m 644 postgres.container.d/10-defaults.conf \
        %{buildroot}/usr/share/containers/systemd/postgres.container.d/
install -m 644 postgres-data.volume %{buildroot}/usr/share/containers/systemd/

%files
%license LICENSES/MIT.txt
%dir /etc/openchami
%dir /etc/openchami/pg-init
%dir /usr/share/containers/systemd/postgres.container.d
/usr/share/containers/systemd/postgres.container
/usr/share/containers/systemd/postgres.container.d/10-defaults.conf
/usr/share/containers/systemd/postgres-data.volume
/etc/openchami/pg-init/multi-psql-db.sh

%post
# reload systemd so the new Quadlet-generated unit is seen
systemctl daemon-reload || :
if [ $1 -ge 2 ]; then
    systemctl try-restart postgres.service || :
fi

%preun
if [ $1 -eq 0 ]; then
    systemctl stop postgres.service >/dev/null 2>&1 || :
fi

%postun
# reload systemd so the removed unit is dropped
systemctl daemon-reload || :
