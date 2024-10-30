#!/bin/sh
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Assign command line arguments to variables or read from environment
KUBE_VERSION=${1:-$KUBE_VERSION}
DEFAULT_PORT1=${2:-${PORT1:-1080}}  # Use command line argument, then environment variable, then 1080 as default
DEFAULT_PORT2=${3:-${PORT2:-2080}}  # Use command line argument, then environment variable, then 2080 as default

# Validate that the Kubernetes version argument has been provided
if [ -z "$KUBE_VERSION" ]; then
    echo "Error: Kubernetes version is missing. Provide it as an argument or set the KUBE_VERSION environment variable."
    echo "Usage: sh $0 [v]X.Y.Z [DEFAULT_PORT1] [DEFAULT_PORT2]"
    echo "Example: sh $0 1.26.3 or sh $0 v1.26.3"
    exit 1
fi

# Validate the Kubernetes version format (vX.Y.Z)
VERSION_REGEX='^v[0-9]+\.[0-9]+\.[0-9]+$'
if ! echo "$KUBE_VERSION" | grep -E "$VERSION_REGEX" > /dev/null; then
    echo "Error: Kubernetes version format is invalid. Expected '[v]X.Y.Z'."
    echo "Example: sh $0 1.26.3 or sh $0 v1.26.3"
    exit 2
fi

# Extract the minor version part (Y) from the Kubernetes version
MINOR_VERSION=$(echo "$KUBE_VERSION" | cut -d'.' -f2)

# Validate that the DRONE_BUILD_NUMBER environment variable is set and is an integer
if [ -z "$DRONE_BUILD_NUMBER" ] || ! echo "$DRONE_BUILD_NUMBER" | grep -E '^[0-9]+$' > /dev/null; then
    echo "Error: DRONE_BUILD_NUMBER is not set or is not an integer."
    exit 3
fi

# Calculate unique port numbers based on the major Kubernetes version, DRONE_BUILD_NUMBER, and default port values
UNIQUE_PORT1=$((MINOR_VERSION + DRONE_BUILD_NUMBER + DEFAULT_PORT1))
UNIQUE_PORT2=$((MINOR_VERSION + DRONE_BUILD_NUMBER + DEFAULT_PORT2))

# Ensure unique ports are greater than 1024 and less than 30000
if [ "$UNIQUE_PORT1" -le 1024 ] || [ "$UNIQUE_PORT1" -ge 30000 ] || [ "$UNIQUE_PORT2" -le 1024 ] || [ "$UNIQUE_PORT2" -ge 30000 ]; then
    echo "Error: Calculated ports must be greater than 1024 and less than 30000. HTTP_PORT = $UNIQUE_PORT2 HTTPS_PORT = $UNIQUE_PORT1"
    exit 4
fi

CLUSTER_NAME="${DRONE_REPO_NAME}-${DRONE_BUILD_NUMBER}-harbor-${KUBE_VERSION}"
DEFAULT_OUTPUT=./

CONFIG_FILE="${DEFAULT_OUTPUT}config-${CLUSTER_NAME}.yaml"
cat > "$CONFIG_FILE" <<EOF
# Configuration file generated for Kubernetes using Kind
# This file was automatically generated by the script. Do not modify it manually.
---
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: ${CLUSTER_NAME}
nodes:
  - role: control-plane
    image: registry.sighup.io/fury/kindest/node:$KUBE_VERSION # Specified Kubernetes version
  - role: worker
    image: registry.sighup.io/fury/kindest/node:$KUBE_VERSION # Specified Kubernetes version
    extraPortMappings:
      - containerPort: 31080 # nginx ingress controller http
        hostPort: ${UNIQUE_PORT1}
        listenAddress: 127.0.0.1
        # This is the http port
      - containerPort: 31443 # nginx ingress controller https
        hostPort: ${UNIQUE_PORT2}
        listenAddress: 127.0.0.1
        # This is the https port
EOF

# Save details for Drone CI

DRONE_ENV_REF="${DEFAULT_OUTPUT}env-${CLUSTER_NAME}.env"
cat > "$DRONE_ENV_REF" <<EOF
export HTTP_PORT=$UNIQUE_PORT1
export HTTPS_PORT=$UNIQUE_PORT2
export KIND_CONFIG=$CONFIG_FILE
export KUBE_VERSION=$KUBE_VERSION
EOF

echo "HTTP port configured: $UNIQUE_PORT1"
echo "HTTPS port configured: $UNIQUE_PORT2"
echo "Kubernetes version used: $KUBE_VERSION"
echo "Environment file saved in: $DRONE_ENV_REF"
echo "Kind configuration file saved in: $CONFIG_FILE"