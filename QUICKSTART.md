# TrueNAS CSI Driver - Quick Start Guide

## Prerequisites
- Kubernetes cluster (tested with kind v1.31.0)
- TrueNAS system with API access
- TrueNAS API key
- Storage pool available on TrueNAS

## Installation

### 1. Build and Load Driver Image (for kind)
```bash
# Build the driver
docker build -t tns-csi-driver:test .

# Load into kind cluster
kind load docker-image tns-csi-driver:test --name truenas-csi-test
```

### 2. Create TrueNAS Credentials Secret
Edit `deploy/secret.yaml` with your TrueNAS details:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: truenas-csi-secret
  namespace: kube-system
type: Opaque
stringData:
  server: "10.10.20.100"      # Your TrueNAS IP
  port: "1443"                 # TrueNAS API port
  apiKey: "your-api-key-here"  # Your API key
```

Apply the secret:
```bash
kubectl apply -f deploy/secret.yaml
```

### 3. Deploy CSI Driver Components
```bash
# Deploy in order
kubectl apply -f deploy/rbac.yaml
kubectl apply -f deploy/csidriver.yaml
kubectl apply -f deploy/controller.yaml
kubectl apply -f deploy/node.yaml
```

### 4. Create Storage Class
Edit `deploy/storageclass.yaml`:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tns-nfs
provisioner: tns.csi.io
parameters:
  protocol: "nfs"              # "nfs" or "nvmeof"
  pool: "storage"              # Your TrueNAS pool name
  server: "10.10.20.100"       # TrueNAS NFS server IP
volumeBindingMode: Immediate
allowVolumeExpansion: true
reclaimPolicy: Delete
```

Apply the storage class:
```bash
kubectl apply -f deploy/storageclass.yaml
```

## Usage

### Creating a Persistent Volume Claim

Create a PVC (example: `my-pvc.yaml`):
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: tns-nfs
```

Apply:
```bash
kubectl apply -f my-pvc.yaml
```

Check status:
```bash
kubectl get pvc my-app-data
```

### Using PVC in a Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: nginx:latest
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-app-data
```

### Using PVC in a StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: my-statefulset
spec:
  serviceName: my-service
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: tns-nfs
      resources:
        requests:
          storage: 10Gi
```

## Verification Commands

### Check Driver Status
```bash
# Check controller pod
kubectl get pods -n kube-system | grep tns-csi-controller

# Check node pods
kubectl get pods -n kube-system | grep tns-csi-node

# View controller logs
kubectl logs -n kube-system tns-csi-controller-0 -c tns-csi-plugin

# View node logs
kubectl logs -n kube-system <node-pod-name> -c tns-csi-plugin
```

### Check Volumes
```bash
# List PVCs
kubectl get pvc -A

# List PVs
kubectl get pv

# Describe a specific PVC
kubectl describe pvc <pvc-name>

# Check volume mount in pod
kubectl exec <pod-name> -- df -h
```

### Test Data Persistence
```bash
# Write test data
kubectl exec <pod-name> -- sh -c "echo 'test data' > /data/test.txt"

# Read data
kubectl exec <pod-name> -- cat /data/test.txt

# Delete and recreate pod, verify data persists
kubectl delete pod <pod-name>
kubectl apply -f <pod-yaml>
kubectl exec <pod-name> -- cat /data/test.txt
```

## Troubleshooting

### Driver Not Starting
1. Check secret is created correctly:
   ```bash
   kubectl get secret truenas-csi-secret -n kube-system
   ```

2. Verify TrueNAS connectivity:
   ```bash
   # From any cluster node
   curl -k https://<truenas-ip>:1443/api/v2.0/
   ```

3. Check controller logs for errors:
   ```bash
   kubectl logs -n kube-system tns-csi-controller-0 -c tns-csi-plugin
   ```

### PVC Stuck in Pending
1. Check storage class exists:
   ```bash
   kubectl get storageclass
   ```

2. Check controller logs:
   ```bash
   kubectl logs -n kube-system tns-csi-controller-0 -c tns-csi-plugin --tail=50
   ```

3. Describe the PVC for events:
   ```bash
   kubectl describe pvc <pvc-name>
   ```

### Pod Cannot Mount Volume
1. Check node driver is running:
   ```bash
   kubectl get pods -n kube-system -l app=tns-csi-node
   ```

2. Check node driver logs:
   ```bash
   kubectl logs -n kube-system <node-pod-name> -c tns-csi-plugin
   ```

3. Verify NFS connectivity from node:
   ```bash
   # SSH to the node or use a debug pod
   showmount -e <truenas-ip>
   ```

### WebSocket Connection Issues
The driver includes automatic reconnection with exponential backoff. If you see connection errors:

1. Verify API key is valid
2. Check TrueNAS firewall allows WebSocket connections (port 1443)
3. Ensure TLS certificate is valid or self-signed certs are accepted
4. Check logs for authentication failures

**Do not modify the WebSocket ping/pong logic** - it is working correctly and follows TrueNAS API requirements.

## Storage Protocols

### NFS (Tested ✅)
- **Access Modes**: ReadWriteMany (RWX), ReadWriteOnce (RWO)
- **Mount Options**: NFSv4.2, nolock
- **Use Case**: Shared storage across multiple pods
- **Status**: Production ready

### NVMe-oF (Implementation Present)
- **Access Modes**: ReadWriteOnce (RWO)
- **Use Case**: High-performance block storage
- **Status**: Code implemented, requires TrueNAS NVMe-oF target configuration

## Advanced Configuration

### Custom Mount Options
Modify `pkg/driver/node.go` to add custom NFS mount options:
```go
// Line ~245
mountOptions := []string{
    "vers=4.2",
    "nolock",
    // Add your custom options here
}
```

### Volume Expansion
The storage class has `allowVolumeExpansion: true` enabled. To expand a volume:

1. Edit the PVC:
   ```bash
   kubectl edit pvc <pvc-name>
   ```

2. Change the storage size:
   ```yaml
   spec:
     resources:
       requests:
         storage: 20Gi  # Increase size
   ```

3. The driver will automatically expand the dataset on TrueNAS

## Performance Considerations

### NFS Performance
- Uses NFSv4.2 for best performance and features
- `nolock` option reduces locking overhead
- Suitable for most workloads including databases (with proper configuration)

### Network
- Ensure low-latency network between Kubernetes nodes and TrueNAS
- Consider using dedicated storage network
- Monitor NFS mount statistics: `nfsstat -m`

## Security

### API Key Management
- Store API key in Kubernetes Secret
- Use RBAC to restrict secret access
- Rotate API keys regularly
- Use TrueNAS read-only API keys where possible (for future implementations)

### Network Security
- Use TLS for WebSocket connections (default: wss://)
- Implement network policies to restrict access
- Consider VPN or private network for storage traffic

## Monitoring

### Health Checks
```bash
# Check CSI driver health
kubectl get csidrivers

# Check pod health
kubectl get pods -n kube-system -l app.kubernetes.io/name=tns-csi-driver
```

### Metrics
The driver exposes standard CSI metrics that can be scraped by Prometheus:
- Volume operations (create, delete, mount, unmount)
- Operation latencies
- Error rates

## Support

For issues or questions:
1. Check logs: controller and node driver logs
2. Review AGENTS.md for development guidelines
3. Check TESTING_RESULTS.md for known working configurations
4. Create an issue with:
   - Kubernetes version
   - TrueNAS version
   - Driver logs
   - Steps to reproduce

## References

- [CSI Specification](https://github.com/container-storage-interface/spec)
- [TrueNAS API Documentation](https://www.truenas.com/docs/api/)
- [Kubernetes Storage Documentation](https://kubernetes.io/docs/concepts/storage/)
