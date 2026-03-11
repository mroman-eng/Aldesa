#!/usr/bin/env bash
set -euo pipefail

TERRAFORM_VERSION="${1:-1.14.4}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl unzip make jq
rm -rf /var/lib/apt/lists/*

curl -fsSL -o /tmp/terraform.zip \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"

unzip -q /tmp/terraform.zip -d /usr/local/bin
chmod +x /usr/local/bin/terraform

terraform version
