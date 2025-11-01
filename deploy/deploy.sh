#!/bin/bash
set -e

echo "=========================================="
echo "TrueNAS Scale CSI Driver - Quick Deploy"
echo "=========================================="
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster."
    exit 1
fi

echo "Step 1: Checking prerequisites..."
echo

# Prompt for TrueNAS configuration
read -p "Enter TrueNAS IP/hostname (e.g., 10.10.20.100): " TNS_IP
read -p "Enter TrueNAS API key: " TNS_API_KEY
read -p "Enter TrueNAS pool name (e.g., pool1): " TNS_POOL
read -p "Enter container image (e.g., your-registry/tns-csi-driver:v0.1.0): " CONTAINER_IMAGE

echo
echo "Configuration:"
echo "  TrueNAS IP: $TNS_IP"
echo "  Pool: $TNS_POOL"
echo "  Image: $CONTAINER_IMAGE"
echo

read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

echo
echo "Step 2: Creating secret..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: tns-csi-secret
  namespace: kube-system
type: Opaque
stringData:
  url: "ws://${TNS_IP}/websocket"
  api-key: "${TNS_API_KEY}"
EOF

echo
echo "Step 3: Deploying RBAC..."
kubectl apply -f deploy/rbac.yaml

echo
echo "Step 4: Deploying CSIDriver resource..."
kubectl apply -f deploy/csidriver.yaml

echo
echo "Step 5: Deploying controller..."
# Update image in controller.yaml
sed "s|image: your-registry/tns-csi-driver:latest|image: ${CONTAINER_IMAGE}|g" deploy/controller.yaml | kubectl apply -f -

echo
echo "Step 6: Deploying node plugin..."
# Update image in node.yaml
sed "s|image: your-registry/tns-csi-driver:latest|image: ${CONTAINER_IMAGE}|g" deploy/node.yaml | kubectl apply -f -

echo
echo "Step 7: Creating StorageClass..."
# Update pool and server in storageclass.yaml
sed -e "s|pool: \"pool1\"|pool: \"${TNS_POOL}\"|g" \
    -e "s|server: \"10.10.20.100\"|server: \"${TNS_IP}\"|g" \
    deploy/storageclass.yaml | kubectl apply -f -

echo
echo "Step 8: Waiting for pods to be ready..."
echo "Waiting for controller..."
kubectl wait --for=condition=ready pod -n kube-system -l app=tns-csi-controller --timeout=120s

echo "Waiting for node plugins..."
kubectl wait --for=condition=ready pod -n kube-system -l app=tns-csi-node --timeout=120s

echo
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo
echo "Verify deployment:"
echo "  kubectl get pods -n kube-system | grep tns-csi"
echo "  kubectl get storageclass"
echo
echo "Test with example PVC:"
echo "  kubectl apply -f deploy/example-pvc.yaml"
echo "  kubectl get pvc"
echo
echo "View logs:"
echo "  kubectl logs -n kube-system tns-csi-controller-0 -c tns-csi-plugin"
echo
