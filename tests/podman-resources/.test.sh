#!/usr/bin/env bash
set -e

podman machine list | grep devenv-resources
[ "$(podman machine inspect devenv-resources --format '{{.Resources.Memory}}')" = "3072" ]
[ "$(podman machine inspect devenv-resources --format '{{.Resources.CPUs}}')" = "2" ]
