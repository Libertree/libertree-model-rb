#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export LIBERTREE_ENV=test
export LIBERTREE_DB=${LIBERTREE_DB:-libertree_test}

bundle exec rspec --format documentation "$@"
