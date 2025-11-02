# Quick Start: NVMe-oF Testing on macOS

**Branch:** `local-nvmeof-testing`

This branch adds complete local NVMe-oF testing capability for macOS using Multipass VMs.

## Problem Solved

You can't test NVMe-oF or iSCSI from macOS because:
- ❌ No NVMe-oF initiator support
- ❌ No iSCSI initiator (removed in recent macOS)
- ❌ Docker Desktop runs in isolated VM
- ❌ Kind on macOS can't access block devices

## Solution

✅ Multipass VM with Ubuntu 22.04 + k3s + NVMe-oF tools  
✅ Full kernel module support (nvme-tcp, nvme-fabrics)  
✅ Network access to your TrueNAS  
✅ Control everything from macOS terminal  
✅ Free and runs locally  

## 3-Step Setup

### 1. Install Multipass (one-time)

```bash
brew install multipass
```

### 2. Create Test Environment

```bash
./scripts/setup-nvmeof-test-vm.sh
```

Creates Ubuntu VM with k3s and NVMe-oF support (~5 minutes)

### 3. Deploy & Test

```bash
# Deploy CSI driver to VM
./scripts/deploy-nvmeof-test.sh

# Run test suite
./scripts/test-nvmeof.sh
```

## What You Get

```
Your macOS
    │
    ├── Edit code normally
    ├── Use kubectl from terminal
    └── Run automated tests
         │
         ▼
    Ubuntu VM (Multipass)
    ├── k3s Kubernetes
    ├── NVMe-oF initiator (nvme-cli)
    ├── CSI driver deployed
    └── Test pods with NVMe devices
         │
         ▼
    TrueNAS (your network)
    ├── NVMe-oF target
    ├── ZFS pools
    └── Block storage
```

## Daily Workflow

```bash
# 1. Edit code on macOS (as usual)
vim pkg/driver/node.go

# 2. Deploy changes
./scripts/deploy-nvmeof-test.sh

# 3. Test
./scripts/test-nvmeof.sh

# 4. Debug if needed
export KUBECONFIG=~/.kube/k3s-nvmeof-test
kubectl logs -n kube-system -l app.kubernetes.io/component=node -c tns-csi-plugin -f

# 5. When done for the day
./scripts/cleanup-nvmeof-test.sh  # Choose option 3 to stop VM
```

## Files Added

| File | Purpose |
|------|---------|
| `NVMEOF_TESTING.md` | Complete documentation |
| `scripts/setup-nvmeof-test-vm.sh` | Create VM with k3s |
| `scripts/deploy-nvmeof-test.sh` | Deploy CSI driver |
| `scripts/test-nvmeof.sh` | Run test suite |
| `scripts/cleanup-nvmeof-test.sh` | Cleanup environment |
| `scripts/README-NVMEOF.md` | Quick reference |
| `QUICKSTART-NVMEOF.md` | This file |

## Tests Run

✅ NFS baseline (verify environment works)  
✅ NVMe-oF PVC creation (ZVOL, subsystem, namespace on TrueNAS)  
✅ NVMe-oF device mounting in pod  
✅ NVMe device visibility in VM  
✅ I/O operations (write 100MB test)  

## Advantages

| vs Docker Desktop/Kind | vs Cloud VM | vs Bare Metal |
|------------------------|-------------|---------------|
| ✅ Real block devices | ✅ No costs | ✅ Fastest |
| ✅ NVMe-oF support | ✅ No networking setup | ✅ Always available |
| ✅ Full kernel access | ✅ Local/fast | ✅ Most realistic |
| | ❌ Need VPN | ❌ Need hardware |

## VM Resource Usage

- **CPU:** 4 cores
- **RAM:** 4 GB  
- **Disk:** 50 GB
- **Network:** Bridged (accesses your TrueNAS)

Can be stopped when not in use: `multipass stop truenas-nvme-test`

## Next Steps

1. Try it: `./scripts/setup-nvmeof-test-vm.sh`
2. Read full docs: [NVMEOF_TESTING.md](NVMEOF_TESTING.md)
3. Customize for your needs
4. Add more tests to `test-nvmeof.sh`

## Merge Back to Main?

Once you verify this works, you can:

```bash
# Test everything first
./scripts/setup-nvmeof-test-vm.sh
./scripts/deploy-nvmeof-test.sh
./scripts/test-nvmeof.sh

# If all works, merge to main
git checkout main
git merge local-nvmeof-testing
git push
```

## Support

Issues? Check:
1. VM has network to TrueNAS: `multipass exec truenas-nvme-test -- ping 10.10.20.100`
2. Modules loaded: `multipass exec truenas-nvme-test -- lsmod | grep nvme`
3. k3s healthy: `kubectl --kubeconfig ~/.kube/k3s-nvmeof-test get nodes`

See [NVMEOF_TESTING.md](NVMEOF_TESTING.md) troubleshooting section for more.

---

**Ready to test NVMe-oF locally? Start here:** `./scripts/setup-nvmeof-test-vm.sh`
