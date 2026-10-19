#!/bin/bash
#
# SPDX-FileCopyrightText: © 2026 OpenCHAMI a Series of LF Projects, LLC
# SPDX-License-Identifier: MIT
#
# ExecStartPre guard for postgres.service: refuses to start the container if
# the PostgreSQL major version already present in the data volume does not
# match the major version of the image about to be run. The expected major
# version is derived from the image tag itself (standard docker-library
# postgres tags are "<major>[.<minor>][-variant]", e.g. "18-alpine",
# "15.4-bookworm"), so this script never needs to change when the image is
# bumped to a new release. Only the Image= line in the quadlet drop-in
# needs to change.
#
# This check only runs at service start, not inside
#
#    /docker-entrypoint-initdb.d
#
# because those init scripts only run against an empty data directory;
# this needs to catch a mismatch against a populated volume on every
# restart.
#
# Usage: check-postgres-version.sh <volume-name> <image-reference>
set -eu

function cleanup() {
    # shellcheck disable=SC2317  # this is reachable, but only through the trap
    podman volume unmount "${VOLUME}" > /dev/null 2>&1 || true
}
trap cleanup EXIT

function usage() {
    for m in "${@}"; do
        echo "${m}" >&2
    done
    echo "usage: ${0} <volume-name> <image-reference>" >&2
    exit 2
}

function err() {
    echo "ERROR:"
    for m in "${@}"; do
        echo "${m}" >&2
    done
    exit 2
}

readonly VOLUME="${1}"; shift || usage "missing volume-name"
readonly IMAGE="${1}"; shift || usage "missing image-reference string"

# Pull the major version out of the image's tag (text after the last ':'),
# stopping at the first non-digit character. Covers "18", "18.6",
# "18-alpine", "18.6-bookworm", etc.
tag="${IMAGE##*:}"
expected="${tag%%[!0-9]*}"

if [ -z "${expected}" ]; then
    err \
        "could not determine a PostgreSQL major version from image" \
        "tag '${tag}' (from '${IMAGE}').  Pin Image= to an explicit" \
        "'<major>[.<minor>]-variant' tag (e.g. '18-alpine')," \
	"not a floating tag like 'latest'."
fi

# Mount (or find the existing mountpoint of) the named Podman volume so its
# contents can be inspected directly from the host. Must run as the same
# user that owns postgres.service (root, for this package's system quadlet).
mountpoint="$(podman volume mount "${VOLUME}" || true)"

if [ -n "${mountpoint}" ]; then
    # Look for a PG_VERSION file in any location a prior Postgres version may
    # have left it: this package's current layout (mount root or a
    # version-namespaced "N/docker" subdirectory), or the older fixed "data"
    # subdirectory layout.
    candidates=(
        "${mountpoint}/PG_VERSION"
        "${mountpoint}"/data/PG_VERSION
        "${mountpoint}"/*/docker/PG_VERSION
    )
else
    candidates=()
fi

found=0
for candidate in "${candidates[@]}"; do
    [ -s "${candidate}" ] || continue
    found=1
    on_disk="$(cat "${candidate}")"
    if [ "${on_disk}" != "${expected}" ]; then
	err \
	    "PostgreSQL data in volume '${VOLUME}' was created by major" \
	    "version '${on_disk}' (found in '${candidate}'), but '${IMAGE}'" \
	    "has the major version '${expected}'." \
            "" \
            "Refusing to start to avoid running a newer PostgreSQL" \
	    "image against data it cannot read in place." \
            "" \
	    "To upgrade:" \
	    "1. Back up the volume (snapshot it, or run pg_dumpall" \
	    "   using the previous (version '${expected}') image against" \
            "   this volume)." \
	    "2. Run a one-shot upgrade using the pgautoupgrade image" \
	    "   (https://github.com/pgautoupgrade/docker-pgautoupgrade)" \
	    "   pointed at this same volume, to bring the on-disk" \
	    "   data up to major version '${expected}'." \
	    "3. Start this service again."
    fi
done

if [ "${found}" -eq 0 ]; then
    echo "No existing PostgreSQL data found in volume '${VOLUME}'; treating as a fresh cluster."
fi
exit 0
