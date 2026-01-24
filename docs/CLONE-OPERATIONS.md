# Clone and Snapshot Operations Guide

This document explains the different snapshot and clone operations available in the TrueNAS CSI driver, their underlying ZFS mechanisms, and when to use each approach.

## Table of Contents

- [ZFS Fundamentals](#zfs-fundamentals)
- [CSI Operations Overview](#csi-operations-overview)
- [StorageClass Parameters](#storageclass-parameters)
- [VolumeSnapshotClass Parameters](#volumesnapshotclass-parameters)
- [Operation Matrix](#operation-matrix)
- [Democratic-CSI Compatibility](#democratic-csi-compatibility)
- [Decision Guide](#decision-guide)

## ZFS Fundamentals

Understanding these ZFS concepts is essential for choosing the right operation:

### ZFS Snapshot

A **snapshot** is a read-only, point-in-time copy of a dataset.

```
pool/volume                    # Original dataset
pool/volume@snap-2025-01-24    # Snapshot (read-only)
```

**Characteristics:**
- Instant creation (no data copy)
- Space-efficient (Copy-on-Write - only stores changes)
- Read-only (cannot be modified)
- Depends on the source dataset (deleted if source is deleted)

### ZFS Clone

A **clone** is a writable copy created FROM a snapshot.

```
pool/volume@snap-2025-01-24    # Source snapshot
pool/clone-volume              # Clone (writable)
```

**Characteristics:**
- Instant creation (no data copy)
- Space-efficient (shares blocks with snapshot until modified)
- Writable (independent modifications)
- **Depends on the source snapshot** - the snapshot cannot be deleted while clones exist

### ZFS Promote

**Promotion** reverses the parent-child relationship between a clone and its origin snapshot.

```
Before promote:
  pool/volume@snap → pool/clone (clone depends on snapshot)

After promote:
  pool/clone@snap → pool/volume (original now depends on clone's snapshot)
```

**After promotion:**
- Clone becomes independent
- Original snapshot can be deleted
- Clone no longer has any dependency

### ZFS Send/Receive

**Send/receive** creates a completely independent copy of a dataset by streaming the data.

```bash
zfs send pool/source@snap | zfs receive pool/target
```

**Characteristics:**
- Full data copy (not instant)
- Completely independent (no shared blocks)
- No dependency on source
- Uses more storage space

## CSI Operations Overview

The CSI spec defines two ways to create volumes from existing data:

### 1. Create Volume from Snapshot (VolumeSnapshot source)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  dataSource:
    kind: VolumeSnapshot
    name: my-snapshot
    apiGroup: snapshot.storage.k8s.io
```

This restores data from a VolumeSnapshot to a new PVC.

### 2. Create Volume from Volume (PVC source)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  dataSource:
    kind: PersistentVolumeClaim
    name: source-pvc
```

This clones an existing PVC to a new PVC.

## StorageClass Parameters

These parameters control how volumes are created when using a data source:

### `detachedVolumesFromSnapshots`

Controls volume creation when restoring **from a VolumeSnapshot**.

| Value | Behavior | ZFS Operation |
|-------|----------|---------------|
| `"false"` (default) | COW clone, depends on snapshot | `zfs clone` |
| `"true"` | Independent volume | `zfs clone` + `zfs promote` |

**Example StorageClass:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: truenas-nfs-detached-snapshots
provisioner: tns.csi.io
parameters:
  protocol: nfs
  pool: tank
  server: truenas.local
  detachedVolumesFromSnapshots: "true"  # Volumes restored from snapshots are independent
```

### `detachedVolumesFromVolumes`

Controls volume creation when cloning **from another volume (PVC)**.

| Value | Behavior | ZFS Operation |
|-------|----------|---------------|
| `"false"` (default) | COW clone, temp snapshot kept | `zfs snapshot` + `zfs clone` |
| `"true"` | Independent volume, temp snapshot deleted | `zfs snapshot` + `zfs clone` + `zfs promote` |

**Example StorageClass:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: truenas-nfs-detached-volumes
provisioner: tns.csi.io
parameters:
  protocol: nfs
  pool: tank
  server: truenas.local
  detachedVolumesFromVolumes: "true"  # Volumes cloned from other volumes are independent
```

**Note on temp snapshots:** When cloning from a volume, a temporary snapshot is created. With `detachedVolumesFromVolumes: "false"`, this snapshot is kept (named `volume-source-for-volume-<pvc-name>`) because the clone depends on it. With `"true"`, the clone is promoted and the temp snapshot is deleted.

## VolumeSnapshotClass Parameters

### `detachedSnapshots`

Controls how snapshots are created.

| Value | Behavior | ZFS Operation |
|-------|----------|---------------|
| `"false"` (default) | Standard COW snapshot | `zfs snapshot` |
| `"true"` | Independent dataset copy | `zfs snapshot` + `replication.run_onetime` (zfs send/receive) |

**Example VolumeSnapshotClass:**

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: truenas-detached-snapshots
driver: tns.csi.io
deletionPolicy: Delete
parameters:
  detachedSnapshots: "true"  # Snapshots survive source volume deletion
  detachedSnapshotsParentDataset: "tank/backups"  # Optional: custom location
```

**Key difference:** Detached snapshots are stored as independent datasets (not ZFS snapshots) and survive the deletion of the source volume. Regular snapshots are deleted when the source volume is deleted.

## Operation Matrix

| Operation | Source | StorageClass Param | VolumeSnapshotClass Param | Result |
|-----------|--------|-------------------|---------------------------|--------|
| **Create Snapshot** | Volume | - | `detachedSnapshots: "false"` | ZFS snapshot (depends on source) |
| **Create Detached Snapshot** | Volume | - | `detachedSnapshots: "true"` | Independent dataset (survives source deletion) |
| **Restore from Snapshot (COW)** | Snapshot | `detachedVolumesFromSnapshots: "false"` | - | Clone depends on snapshot |
| **Restore from Snapshot (Promoted)** | Snapshot | `detachedVolumesFromSnapshots: "true"` | - | Independent volume |
| **Clone Volume (COW)** | Volume | `detachedVolumesFromVolumes: "false"` | - | Clone + temp snapshot kept |
| **Clone Volume (Promoted)** | Volume | `detachedVolumesFromVolumes: "true"` | - | Independent volume, temp snapshot deleted |

## Democratic-CSI Compatibility

Our parameters are designed to match [democratic-csi](https://github.com/democratic-csi/democratic-csi) naming:

| Democratic-CSI Parameter | Our Parameter | Location |
|-------------------------|---------------|----------|
| `detachedSnapshots` | `detachedSnapshots` | VolumeSnapshotClass |
| `detachedVolumesFromSnapshots` | `detachedVolumesFromSnapshots` | StorageClass |
| `detachedVolumesFromVolumes` | `detachedVolumesFromVolumes` | StorageClass |

**Implementation difference:** Democratic-csi uses `zfs send/receive` for detached volumes. We use `zfs clone` + `zfs promote` for efficiency (instant operation).

## Decision Guide

### When to use each operation:

#### Regular Snapshot (`detachedSnapshots: "false"`)
- Point-in-time backups for quick rollback
- Test/dev environments
- When source volume will persist
- Maximum space efficiency

#### Detached Snapshot (`detachedSnapshots: "true"`)
- Disaster recovery (snapshot must survive source deletion)
- Long-term archival
- Compliance requirements (independent backup copies)
- Data migration (source will be deleted)

#### COW Clone from Snapshot (`detachedVolumesFromSnapshots: "false"`)
- Quick test copies
- Space-efficient clones
- When snapshot must be preserved anyway

#### Promoted Clone from Snapshot (`detachedVolumesFromSnapshots: "true"`)
- Snapshot rotation (need to delete old snapshots)
- Independent production copies
- Cleanup flexibility

#### COW Clone from Volume (`detachedVolumesFromVolumes: "false"`)
- Test copies of production data
- Space-efficient development environments
- When source volume is stable

#### Promoted Clone from Volume (`detachedVolumesFromVolumes: "true"`)
- Independent copies for separate lifecycle
- Migration scenarios
- When temp snapshot cleanup is important

### Space Efficiency vs Independence Trade-off

```
Most Space Efficient                    Most Independent
        |                                      |
        v                                      v
    COW Clone  ←————————————————————→  Promoted Clone
    (shared blocks)                    (no dependencies)
```

**Rule of thumb:** Use COW (default) for space efficiency when dependencies are acceptable. Use promoted/detached when you need independence and can afford the space overhead.

## Complete Example

Here's a complete example showing all parameter combinations:

```yaml
---
# StorageClass for standard volumes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: truenas-nfs
provisioner: tns.csi.io
parameters:
  protocol: nfs
  pool: tank
  server: truenas.local
  # Default: COW clones (space efficient, has dependencies)

---
# StorageClass for independent volumes (cloned from snapshots or volumes)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: truenas-nfs-independent
provisioner: tns.csi.io
parameters:
  protocol: nfs
  pool: tank
  server: truenas.local
  detachedVolumesFromSnapshots: "true"  # Restores from snapshots are independent
  detachedVolumesFromVolumes: "true"    # Clones from volumes are independent

---
# VolumeSnapshotClass for regular snapshots
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: truenas-nfs-snapshot
driver: tns.csi.io
deletionPolicy: Delete
# Default: Regular COW snapshots (depend on source)

---
# VolumeSnapshotClass for detached snapshots (DR/archival)
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: truenas-nfs-snapshot-detached
driver: tns.csi.io
deletionPolicy: Delete
parameters:
  detachedSnapshots: "true"  # Survives source deletion
```

## See Also

- [SNAPSHOTS.md](SNAPSHOTS.md) - Detailed snapshot usage guide
- [democratic-csi documentation](https://github.com/democratic-csi/democratic-csi)
- [ZFS documentation](https://openzfs.github.io/openzfs-docs/)
