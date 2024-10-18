#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

set -e

MNT_PATH="oidc"
PLUGIN_NAME="openbao-plugin-auth-jwt"
PLUGIN_CATALOG_NAME="oidc"

#
# Helper script for local development. Automatically builds and registers the
# plugin. Requires `bao` is installed and available on $PATH.
#

# Get the right dir
DIR="$(cd "$(dirname "$(readlink "$0")")" && pwd)"

echo "==> Starting dev"

echo "--> Scratch dir"
echo "    Creating"
SCRATCH="$DIR/tmp"
mkdir -p "$SCRATCH/plugins"

echo "--> Vault server"
echo "    Writing config"
tee "$SCRATCH/config.hcl" > /dev/null <<EOF
plugin_directory = "$SCRATCH/plugins"
EOF

echo "    Envvars"
export BAO_DEV_ROOT_TOKEN_ID="root"
export BAO_ADDR="http://127.0.0.1:8200"

echo "    Starting"
bao server \
  -dev \
  -log-level="debug" \
  -config="$SCRATCH/config.hcl" \
  -dev-ha -dev-transactional -dev-root-token-id=root \
  &
sleep 2
BAO_PID=$!

function cleanup {
  echo ""
  echo "==> Cleaning up"
  kill -INT "$BAO_PID"
  rm -rf "$SCRATCH"
}
trap cleanup EXIT

echo "    Authing"
bao login root &>/dev/null

echo "--> Building"
go build -o "$SCRATCH/plugins/$PLUGIN_NAME" "./cmd/$PLUGIN_NAME" 
SHASUM=$(shasum -a 256 "$SCRATCH/plugins/$PLUGIN_NAME" | cut -d " " -f1)

echo "    Registering plugin"
bao write sys/plugins/catalog/$PLUGIN_CATALOG_NAME \
  sha_256="$SHASUM" \
  command="$PLUGIN_NAME"

echo "    Mounting plugin"
bao auth enable -path=$MNT_PATH -plugin-name=$PLUGIN_CATALOG_NAME -listing-visibility=unauth plugin

if [ -e scripts/custom.sh ]
then
  . scripts/custom.sh
fi

echo "==> Ready!"
wait $!

