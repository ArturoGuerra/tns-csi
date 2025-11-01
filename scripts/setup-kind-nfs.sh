#!/bin/bash
set -e

# Script to setup Kind cluster with NFS support for TrueNAS CSI Driver testing
# This script installs NFS client packages in Kind nodes

CLUSTER_NAME="${1:-truenas-csi-test}"

echo "================================================"
echo "Setting up Kind cluster for NFS support"
echo "Cluster: $CLUSTER_NAME"
echo "================================================"
echo

# Check if kind cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Error: Kind cluster '$CLUSTER_NAME' not found."
    echo "Please create the cluster first using:"
    echo "  kind create cluster --config kind-config.yaml"
    exit 1
fi

echo "Step 1: Getting list of Kind nodes..."
NODES=$(kind get nodes --name "$CLUSTER_NAME")

if [ -z "$NODES" ]; then
    echo "Error: No nodes found in cluster $CLUSTER_NAME"
    exit 1
fi

echo "Found nodes:"
echo "$NODES"
echo

echo "Step 2: Installing NFS client packages on each node..."
for node in $NODES; do
    echo "  Processing node: $node"
    
    # Update apt cache
    echo "    - Updating apt cache..."
    docker exec "$node" apt-get update -qq 2>&1 | grep -v "^Ign:" | head -5 || true
    
    # Install nfs-common
    echo "    - Installing nfs-common..."
    docker exec "$node" apt-get install -y nfs-common >/dev/null 2>&1
    
    # Verify installation
    if docker exec "$node" which mount.nfs >/dev/null 2>&1; then
        echo "    ✓ NFS client installed successfully"
    else
        echo "    ✗ Failed to install NFS client"
        exit 1
    fi
    
    # Load NFS kernel modules (if available)
    echo "    - Loading NFS kernel modules..."
    docker exec "$node" modprobe nfs 2>/dev/null || echo "    Note: NFS module already loaded or not needed"
    docker exec "$node" modprobe nfsd 2>/dev/null || echo "    Note: NFSD module already loaded or not needed"
    
    echo
done

echo "================================================"
echo "✓ NFS support setup complete!"
echo "================================================"
echo
echo "Next steps:"
echo "1. Load your CSI driver image into Kind:"
echo "   kind load docker-image fenio/tns-csi:latest --name $CLUSTER_NAME"
echo
echo "2. Deploy the CSI driver:"
echo "   kubectl apply -f deploy/"
echo
echo "3. Create test PVC:"
echo "   kubectl apply -f test-pvc.yaml"
echo
