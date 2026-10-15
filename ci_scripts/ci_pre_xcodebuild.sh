#!/bin/sh
set -eu

cd "${CI_PRIMARY_REPOSITORY_PATH:?CI_PRIMARY_REPOSITORY_PATH is required}"
python3 scripts/check-protected-rates.py
