# TNS CSI Driver

A Kubernetes CSI (Container Storage Interface) driver for storage systems with TNS-compatible APIs.

## Important Disclaimer

**This is an independent, community-developed project and is NOT affiliated with, endorsed by, or supported by iXsystems Inc. or the TrueNAS project.**

This driver is designed to work with storage systems that provide TrueNAS-compatible APIs, but:
- It is not an official TrueNAS product
- It is not supported by iXsystems Inc.
- TrueNAS is a registered trademark of iXsystems Inc.
- Use of this software is entirely at your own risk

If you need official support, please use the official TrueNAS CSI driver available at https://github.com/truenas/charts

## Overview

This CSI driver enables Kubernetes to provision and manage persistent volumes on storage systems with TNS-compatible APIs. It supports multiple storage protocols:

- **NFS** - Network File System for file-based storage
- **NVMe-oF** - NVMe over Fabrics for high-performance block storage
- **iSCSI** - (Planned) Internet Small Computer Systems Interface

## Features

- Dynamic volume provisioning
- Multiple protocol support (NFS, NVMe-oF)
- Volume lifecycle management
- Support for ReadWriteOnce and ReadWriteMany access modes
- Integration with Kubernetes storage classes

## Prerequisites

- Kubernetes 1.20+
- Storage system with TNS-compatible API (v2.0 WebSocket API)
- For NFS: NFS client utilities on all nodes (`nfs-common` on Debian/Ubuntu, `nfs-utils` on RHEL/CentOS)
- For NVMe-oF: 
  - `nvme-cli` package installed on all nodes
  - Kernel modules: `nvme-tcp`, `nvme-fabrics`
  - Network connectivity to storage system on port 4420

## Quick Start

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed installation and configuration instructions.

### Basic Installation

1. Create namespace and RBAC:
```bash
kubectl apply -f deploy/rbac.yaml
```

2. Configure storage system credentials:
```bash
# Copy the example secret file and edit with your actual credentials
cp deploy/secret.yaml deploy/secret.local.yaml
# Edit deploy/secret.local.yaml with your TrueNAS IP and API key
kubectl apply -f deploy/secret.local.yaml
```

**Note:** The files in the `deploy/` directory contain placeholder values. Create `*.local.yaml` versions with your actual configuration. These local files are automatically ignored by git.

3. Deploy the CSI driver:
```bash
kubectl apply -f deploy/csidriver.yaml
kubectl apply -f deploy/controller.yaml
kubectl apply -f deploy/node.yaml
```

4. Create a storage class:
```bash
kubectl apply -f deploy/storageclass.yaml
```

## Configuration

The driver is configured via command-line flags and Kubernetes secrets:

### Command-Line Flags

- `--endpoint` - CSI endpoint (default: `unix:///var/lib/kubelet/plugins/tns.csi.io/csi.sock`)
- `--node-id` - Node identifier (typically the node name)
- `--driver-name` - CSI driver name (default: `tns.csi.io`)
- `--api-url` - Storage system API URL (e.g., `ws://10.10.20.100/api/v2.0/websocket`)
- `--api-key` - Storage system API key

### Storage Class Parameters

**NFS Volumes:**
```yaml
parameters:
  protocol: nfs
  server: 10.10.20.100
  pool: tank
  path: /mnt/tank/k8s
```

**NVMe-oF Volumes:**
```yaml
parameters:
  protocol: nvmeof
  server: 10.10.20.100
  pool: tank
  path: /mnt/tank/k8s/nvmeof
  fsType: ext4  # or xfs
```

## Known Limitations

- **Volume Deletion**: Implemented for NFS and NVMe-oF. Datasets, shares, subsystems, and namespaces are cleaned up on PVC deletion. (iSCSI deletion not yet implemented).
- **Protocol Support**: NFS and NVMe-oF are implemented. iSCSI is planned for future releases.
- **Volume Expansion**: Not yet implemented
- **Snapshots**: Not yet implemented
- **Testing**: Limited testing on production environments - use with caution

## Troubleshooting

See [DEPLOYMENT.md](DEPLOYMENT.md#troubleshooting) for detailed troubleshooting steps.

**Common Issues:**

1. **Pods stuck in ContainerCreating**: 
   - For NFS: Check that NFS client utilities are installed on nodes
   - For NVMe-oF: Check that nvme-cli is installed and kernel modules are loaded
2. **Failed to create volume**: Verify storage API credentials and network connectivity
3. **Mount failed**: 
   - For NFS: Ensure NFS service is running on storage system and accessible from nodes
   - For NVMe-oF: Ensure NVMe-oF service is enabled and firewall allows port 4420

**View Logs:**
```bash
# Controller logs
kubectl logs -n kube-system -l app=tns-csi,component=controller

# Node logs
kubectl logs -n kube-system -l app=tns-csi,component=node
```

## Development

### Building

```bash
make build
```

### Testing

See [TESTING.md](TESTING.md) for testing procedures.

### Building Container Image

```bash
make docker-build
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0) - see the LICENSE file for details.

## Acknowledgments

This driver is designed to work with storage systems that provide TrueNAS-compatible APIs. TrueNAS is a trademark of iXsystems Inc.
