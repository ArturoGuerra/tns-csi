#!/bin/bash
set -e

# Configuration Helper Script for TrueNAS CSI Driver
# This script helps configure the deployment manifests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")/deploy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}INFO: $1${NC}"
}

warn() {
    echo -e "${YELLOW}WARN: $1${NC}"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

prompt() {
    echo -e "${BLUE}$1${NC}"
}

# Backup function
backup_file() {
    local file=$1
    if [[ -f "$file" ]] && [[ ! -f "${file}.original" ]]; then
        cp "$file" "${file}.original"
        info "Created backup: ${file}.original"
    fi
}

# Interactive configuration
prompt "=========================================="
prompt "TrueNAS CSI Driver Configuration"
prompt "=========================================="
echo ""

# 1. Docker Image
prompt "Step 1: Configure Docker Image"
echo ""
echo "Enter the full image name (e.g., yourusername/tns-csi-driver:v0.1.0)"
read -p "Image name: " IMAGE_NAME

if [[ -z "$IMAGE_NAME" ]]; then
    error "Image name cannot be empty"
fi

# 2. TrueNAS Configuration
prompt ""
prompt "Step 2: Configure TrueNAS Connection"
echo ""
read -p "TrueNAS IP address or hostname: " TNS_IP
read -sp "TrueNAS API Key: " TNS_API_KEY
echo ""

if [[ -z "$TNS_IP" ]] || [[ -z "$TNS_API_KEY" ]]; then
    error "TrueNAS IP and API Key are required"
fi

TNS_URL="ws://${TNS_IP}/websocket"

# 3. Storage Configuration
prompt ""
prompt "Step 3: Configure Storage"
echo ""
read -p "ZFS Pool name (e.g., tank): " POOL_NAME
read -p "Parent dataset (optional, press enter to use pool name): " PARENT_DATASET

if [[ -z "$POOL_NAME" ]]; then
    error "Pool name is required"
fi

if [[ -z "$PARENT_DATASET" ]]; then
    PARENT_DATASET="$POOL_NAME"
fi

# Confirm configuration
prompt ""
prompt "=========================================="
prompt "Configuration Summary"
prompt "=========================================="
echo "Docker Image:     $IMAGE_NAME"
echo "TrueNAS URL:      $TNS_URL"
echo "TrueNAS IP:       $TNS_IP"
echo "API Key:          ${TNS_API_KEY:0:10}..." 
echo "ZFS Pool:         $POOL_NAME"
echo "Parent Dataset:   $PARENT_DATASET"
prompt "=========================================="
echo ""

read -p "Continue with this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Configuration cancelled"
    exit 0
fi

# Update files
cd "$DEPLOY_DIR"

# Backup original files
backup_file "controller.yaml"
backup_file "node.yaml"
backup_file "secret.yaml"
backup_file "storageclass.yaml"

info "Updating deployment manifests..."

# Update controller.yaml
if [[ -f "controller.yaml" ]]; then
    sed -i.tmp "s|image: .*tns-csi-driver.*|image: ${IMAGE_NAME}|g" controller.yaml
    rm -f controller.yaml.tmp
    info "Updated controller.yaml"
fi

# Update node.yaml
if [[ -f "node.yaml" ]]; then
    sed -i.tmp "s|image: .*tns-csi-driver.*|image: ${IMAGE_NAME}|g" node.yaml
    rm -f node.yaml.tmp
    info "Updated node.yaml"
fi

# Update secret.yaml
if [[ -f "secret.yaml" ]]; then
    sed -i.tmp "s|url: .*|url: \"${TNS_URL}\"|g" secret.yaml
    sed -i.tmp "s|api-key: .*|api-key: \"${TNS_API_KEY}\"|g" secret.yaml
    rm -f secret.yaml.tmp
    info "Updated secret.yaml"
fi

# Update storageclass.yaml - only update the NFS storage class
if [[ -f "storageclass.yaml" ]]; then
    # This is a bit tricky - we need to update only the first StorageClass (NFS)
    # Create a temporary file with updated values
    awk -v pool="$POOL_NAME" -v server="$TNS_IP" -v parent="$PARENT_DATASET" '
    /^---$/ { section++ }
    section == 1 {
        if (/pool:/) { print "  pool: \"" pool "\""; next }
        if (/server:/) { print "  server: \"" server "\""; next }
        if (/# parentDataset:/) { print "  parentDataset: \"" parent "\""; next }
    }
    { print }
    ' storageclass.yaml > storageclass.yaml.tmp
    
    mv storageclass.yaml.tmp storageclass.yaml
    info "Updated storageclass.yaml"
fi

info ""
info "Configuration complete!"
info ""
info "Modified files:"
info "  - controller.yaml"
info "  - node.yaml"
info "  - secret.yaml"
info "  - storageclass.yaml"
info ""
info "Original files backed up with .original extension"
info ""
prompt "Next steps:"
echo "1. Review the updated files in: $DEPLOY_DIR"
echo "2. Ensure your Kubernetes nodes have NFS client installed:"
echo "     Ubuntu/Debian: sudo apt-get install -y nfs-common"
echo "     RHEL/CentOS:   sudo yum install -y nfs-utils"
echo "3. Deploy the driver:"
echo "     kubectl apply -f $DEPLOY_DIR/rbac.yaml"
echo "     kubectl apply -f $DEPLOY_DIR/secret.yaml"
echo "     kubectl apply -f $DEPLOY_DIR/csidriver.yaml"
echo "     kubectl apply -f $DEPLOY_DIR/controller.yaml"
echo "     kubectl apply -f $DEPLOY_DIR/node.yaml"
echo "     kubectl apply -f $DEPLOY_DIR/storageclass.yaml"
echo "4. Verify deployment:"
echo "     kubectl get pods -n kube-system -l app=tns-csi"
echo "5. See TESTING.md for complete testing procedures"
