# SPDX-FileCopyrightText: 2026 OpenCHAMI Contributors
# SPDX-License-Identifier: MIT
#
# See `make rpm-build` and docs/RPM_PACKAGING.md for the tag-to-version
# mapping and how the packaged quadlet's image tag is pinned to it.

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
cp scripts/multi-psql-db.sh %{buildroot}/etc/openchami/pg-init/multi-psql-db.sh

grep -q '@IMAGE_TAG@' postgres.container
sed "s|@IMAGE_TAG@|v%{version}|" postgres.container \
    > %{buildroot}/usr/share/containers/systemd/postgres.container
chmod 644 %{buildroot}/usr/share/containers/systemd/postgres.container
install -d %{buildroot}/usr/share/containers/systemd/postgres.container.d
install -m 644 postgres.container.d/10-defaults.conf \
    %{buildroot}/usr/share/containers/systemd/postgres.container.d/

install -m 644 postgres-data.volume \
    %{buildroot}/usr/share/containers/systemd/postgres-data.volume

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
