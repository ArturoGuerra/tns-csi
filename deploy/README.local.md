# Local Configuration Files

This directory contains example configuration files with placeholder values for public distribution.

## Setting Up Local Testing

To test the CSI driver locally, you need to create local configuration files with your actual credentials:

### 1. Create Local Secret File

```bash
cp deploy/secret.yaml deploy/secret.local.yaml
```

Edit `deploy/secret.local.yaml` and replace:
- `YOUR-TRUENAS-IP` with your TrueNAS server IP or hostname
- `YOUR-API-KEY-HERE` with your actual API key from TrueNAS

### 2. Create Local StorageClass File

```bash
cp deploy/storageclass.yaml deploy/storageclass.local.yaml
```

Edit `deploy/storageclass.local.yaml` and replace:
- `YOUR-TRUENAS-IP` with your TrueNAS server IP in all StorageClass definitions

### 3. Deploy with Local Files

```bash
kubectl apply -f deploy/secret.local.yaml
kubectl apply -f deploy/storageclass.local.yaml
```

## Important Notes

- `*.local.yaml` files are automatically ignored by git (see `.gitignore`)
- Never commit files containing real credentials
- The example files in the repository use placeholder values only
