# storage system Scale CSI Driver - Deployment Guide

This guide explains how to deploy the storage system Scale CSI driver on a Kubernetes cluster.

## Prerequisites

1. **Kubernetes Cluster**: Version 1.20 or later
2. **storage system Scale**: Version 22.12 or later with API access
3. **Network Access**: Kubernetes nodes must be able to reach storage system server
4. **Storage Protocol Requirements**:
   
   **For NFS Support:**
   ```bash
   # Install on Ubuntu/Debian
   sudo apt-get install -y nfs-common
   
   # Install on RHEL/CentOS
   sudo yum install -y nfs-utils
   ```
   
   **For NVMe-oF Support:**
   ```bash
   # Install nvme-cli tools on all nodes
   # Ubuntu/Debian
   sudo apt-get install -y nvme-cli
   
   # RHEL/CentOS
   sudo yum install -y nvme-cli
   
   # Load NVMe-oF kernel modules
   sudo modprobe nvme-tcp
   
   # Make module loading persistent
   echo "nvme-tcp" | sudo tee /etc/modules-load.d/nvme.conf
   
   # Verify nvme-cli is installed
   nvme version
   ```

## Step 1: Prepare storage system Scale

### 1.1 Create API Key

1. Log in to storage system Scale web interface
2. Navigate to **System Settings** > **API Keys**
3. Click **Add**
4. Give it a name (e.g., "kubernetes-csi")
5. Copy the generated API key (you won't be able to see it again)

### 1.2 Create Storage Pool

If you don't already have a pool:
1. Navigate to **Storage** > **Create Pool**
2. Follow the wizard to create a pool (e.g., "pool1")

### 1.3 (Optional) Create Parent Dataset

For better organization, create a parent dataset for Kubernetes volumes:
1. Navigate to **Datasets**
2. Select your pool
3. Click **Add Dataset**
4. Name it (e.g., "k8s")
5. Keep default settings and click **Save**

### 1.4 Enable NVMe-oF Service (For NVMe-oF Support)

If you plan to use NVMe-oF storage:
1. Navigate to **System Settings** > **Services**
2. Find **NVMe-oF** service
3. Click the toggle to enable it
4. Click the pencil icon to configure:
   - Set the transport type (TCP recommended for most deployments)
   - Configure the listen address (0.0.0.0 for all interfaces)
   - Set the port (default: 4420 for TCP)
5. Click **Save** and verify the service is running

## Step 2: Build and Push Docker Image

### 2.1 Build the Docker Image

```bash
# From the project root directory
make build

# Build Docker image
docker build -t your-registry/tns-csi-driver:v0.1.0 .
```

### 2.2 Push to Container Registry

```bash
# Push to your registry (DockerHub, GitHub Container Registry, etc.)
docker push your-registry/tns-csi-driver:v0.1.0
```

If using a private registry, ensure your Kubernetes cluster has pull access.

## Step 3: Configure Deployment Manifests

### 3.1 Update Secret

Edit `deploy/secret.yaml` and replace placeholders:

```yaml
stringData:
  # WebSocket URL (use ws:// for HTTP or wss:// for HTTPS)
  url: "ws://10.10.20.100/websocket"
  # API key from Step 1.1
  api-key: "1-abcdef123456789..."
```

### 3.2 Update Image References

Edit `deploy/controller.yaml` and `deploy/node.yaml`:

Replace:
```yaml
image: your-registry/tns-csi-driver:latest
```

With:
```yaml
image: your-registry/tns-csi-driver:v0.1.0
```

### 3.3 Update StorageClass

Edit `deploy/storageclass.yaml` and configure parameters:

**For NFS:**
```yaml
parameters:
  protocol: "nfs"
  pool: "pool1"              # Your storage system pool name
  # parentDataset: "pool1/k8s"  # Optional parent dataset
  server: "10.10.20.100"     # Your storage system IP/hostname
```

**For NVMe-oF:**
```yaml
parameters:
  protocol: "nvmeof"
  pool: "storage"            # Your storage system pool name
  server: "10.10.20.100"     # Your storage system IP/hostname
  # Optional parameters:
  # filesystem: "ext4"       # Filesystem type: ext4 (default), ext3, or xfs
  # blocksize: "16K"         # Block size for ZVOL (default: 16K)
```

Note: NVMe-oF volumes use `ReadWriteOnce` access mode (block storage), while NFS uses `ReadWriteMany` (shared filesystem).

## Step 4: Deploy to Kubernetes

### 4.1 Deploy CSI Driver

Apply manifests in the following order:

```bash
# 1. Create secret with storage system credentials
kubectl apply -f deploy/secret.yaml

# 2. Create RBAC resources
kubectl apply -f deploy/rbac.yaml

# 3. Create CSIDriver resource
kubectl apply -f deploy/csidriver.yaml

# 4. Deploy controller (StatefulSet)
kubectl apply -f deploy/controller.yaml

# 5. Deploy node plugin (DaemonSet)
kubectl apply -f deploy/node.yaml

# 6. Create StorageClass
kubectl apply -f deploy/storageclass.yaml
```

### 4.2 Verify Deployment

```bash
# Check controller pod
kubectl get pods -n kube-system -l app=tns-csi-controller

# Check node pods (should be one per node)
kubectl get pods -n kube-system -l app=tns-csi-node

# Check CSIDriver
kubectl get csidrivers

# Check StorageClass
kubectl get storageclass
```

Expected output:
```
NAME                              READY   STATUS    RESTARTS   AGE
tns-csi-controller-0          5/5     Running   0          1m
tns-csi-node-xxxxx            2/2     Running   0          1m
tns-csi-node-yyyyy            2/2     Running   0          1m
```

## Step 5: Test the Driver

### 5.1 Create Test PVC

**For NFS:**
```bash
kubectl apply -f deploy/example-pvc.yaml
```

**For NVMe-oF:**
```bash
kubectl apply -f deploy/example-nvmeof-pvc.yaml
```

### 5.2 Verify PVC is Bound

```bash
kubectl get pvc test-pvc

# Expected output:
# NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
# test-pvc   Bound    pvc-12345678-1234-1234-1234-123456789012   10Gi       RWX            tns-nfs     30s
```

### 5.3 Verify in storage system

**For NFS volumes:**
1. Log in to storage system web interface
2. Navigate to **Datasets**
3. You should see a new dataset: `pool1/test-pvc` (or `pool1/k8s/test-pvc` if using parent dataset)
4. Navigate to **Shares** > **NFS**
5. You should see a new NFS share for the dataset

**For NVMe-oF volumes:**
1. Log in to storage system web interface
2. Navigate to **Datasets**
3. You should see a new ZVOL (block device): `pool1/test-nvmeof-pvc`
4. Navigate to **Sharing** > **Block (iSCSI/NVMe-oF)**
5. Click the **NVMe-oF** tab
6. You should see a new subsystem and namespace for the volume
7. On the Kubernetes node, verify the NVMe device is connected:
   ```bash
   # List NVMe devices
   sudo nvme list
   
   # Check specific connection
   kubectl exec test-nvmeof-pod -- df -h /data
   ```

### 5.4 Create Test Pod

The example manifest includes a test pod. Verify it's running:

```bash
kubectl get pod test-pod

# Check if volume is mounted
kubectl exec test-pod -- df -h /data
```

### 5.5 Cleanup Test Resources

```bash
kubectl delete -f deploy/example-pvc.yaml
```

Verify the dataset and NFS share are removed from storage system (if reclaimPolicy is Delete).

## Troubleshooting

### Check Controller Logs

```bash
kubectl logs -n kube-system tns-csi-controller-0 -c tns-csi-plugin
```

### Check Node Plugin Logs

```bash
# Get node plugin pod name
kubectl get pods -n kube-system -l app=tns-csi-node

# View logs
kubectl logs -n kube-system tns-csi-node-xxxxx -c tns-csi-plugin
```

### Common Issues

1. **Pod stuck in ContainerCreating**
   - Check node plugin logs
   - Verify NFS client is installed on nodes (for NFS)
   - Verify nvme-cli is installed on nodes (for NVMe-oF)
   - Check network connectivity to storage system

2. **PVC stuck in Pending**
   - Check controller logs
   - Verify storage system credentials in secret
   - Check storage system pool has available space

3. **Authentication failures**
   - Verify API key is correct
   - Check storage system API is accessible: `curl http://10.10.20.100/api/docs/`

4. **NFS mount failures**
   - Verify NFS service is enabled on storage system
   - Check firewall rules allow NFS traffic (port 2049)
   - Verify NFS share exists in storage system

5. **NVMe-oF connection failures**
   - Verify nvme-cli is installed: `nvme version`
   - Check NVMe-oF kernel module is loaded: `lsmod | grep nvme_tcp`
   - Verify NVMe-oF service is running on storage system
   - Check firewall allows port 4420 (default NVMe-oF TCP port)
   - Test connectivity: `sudo nvme discover -t tcp -a 10.10.20.100 -s 4420`
   - Check node plugin logs for detailed error messages

6. **NVMe device not appearing**
   - Wait a few seconds for device discovery
   - Check dmesg for NVMe errors: `sudo dmesg | grep nvme`
   - Verify subsystem exists: `sudo nvme list-subsys`
   - Check /sys/class/nvme for device entries

### Enable Debug Logging

Edit the deployment and increase verbosity:

```yaml
args:
  - "--v=5"  # Change to --v=10 for more verbose output
```

Then restart the pods:
```bash
kubectl rollout restart statefulset -n kube-system tns-csi-controller
kubectl rollout restart daemonset -n kube-system tns-csi-node
```

## Uninstall

To remove the CSI driver:

```bash
# Delete test resources
kubectl delete -f deploy/example-pvc.yaml

# Delete StorageClass
kubectl delete -f deploy/storageclass.yaml

# Delete driver components
kubectl delete -f deploy/node.yaml
kubectl delete -f deploy/controller.yaml
kubectl delete -f deploy/csidriver.yaml
kubectl delete -f deploy/rbac.yaml
kubectl delete -f deploy/secret.yaml
```

## Production Considerations

1. **High Availability**: Increase controller replicas for HA
   ```yaml
   spec:
     replicas: 3  # In controller.yaml
   ```

2. **Resource Limits**: Adjust CPU/memory limits based on workload

3. **Security**:
   - Use HTTPS/WSS for storage system API connection
   - Implement network policies
   - Use encrypted storage classes
   - Regularly rotate API keys

4. **Monitoring**: Set up monitoring for CSI driver metrics

5. **Backup**: Ensure storage system pool has proper backup strategy

## Protocol Support

This CSI driver supports multiple storage protocols:

- **NFS** (Network File System): Shared filesystem storage with `ReadWriteMany` support
- **NVMe-oF** (NVMe over Fabrics): High-performance block storage with `ReadWriteOnce` support
- **iSCSI**: Planned for future release

## Next Steps

- **iSCSI Support**: Add block storage support via iSCSI protocol
- **Snapshots**: Implement CSI snapshot support using storage system snapshots
- **Volume Expansion**: Test and validate volume expansion
- **Volume Cloning**: Implement CSI volume cloning using storage system clone features
- **Metrics**: Add Prometheus metrics endpoint
- **Topology**: Add topology awareness for multi-zone deployments
