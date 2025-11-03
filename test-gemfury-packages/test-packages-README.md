# Package Installation Testing

Test Dockerfiles for verifying xiond package installations across different package managers.

## Quick Start

Test all package formats with a single command:

```bash
./test-all-packages.sh 21.0.1
```

Or test each format individually (see sections below).

## DEB (Ubuntu/Debian - apt)

### Build and run with default version (21.0.1):

```bash
docker build -f Dockerfile.test-deb -t xiond-test-deb .
docker run --rm xiond-test-deb
```

### Build with specific version:

```bash
docker build -f Dockerfile.test-deb --build-arg XIOND_VERSION=21.0.1 -t xiond-test-deb:21.0.1 .
docker run --rm xiond-test-deb:21.0.1
```

### Build with credentials (if needed for future private access):

```bash
docker build -f Dockerfile.test-deb \
  --build-arg FURY_TOKEN="your-token-here" \
  --build-arg GPG_FINGERPRINT="your-fingerprint-here" \
  -t xiond-test-deb .
```

### Interactive testing:

```bash
docker run --rm -it xiond-test-deb /bin/bash
# Inside container, run:
xiond version
xiond version --long
apt list -a xiond
```

## RPM (Rocky Linux/RHEL/CentOS - yum/dnf)

### Build and run with default version (21.0.1):

```bash
docker build -f Dockerfile.test-rpm -t xiond-test-rpm .
docker run --rm xiond-test-rpm
```

### Build with specific version:

```bash
docker build -f Dockerfile.test-rpm --build-arg XIOND_VERSION=21.0.1 -t xiond-test-rpm:21.0.1 .
docker run --rm xiond-test-rpm:21.0.1
```

### Interactive testing:

```bash
docker run --rm -it xiond-test-rpm /bin/bash
# Inside container, run:
xiond version
xiond version --long
yum list xiond --showduplicates
```

## APK (Alpine Linux - apk)

### Build and run with default version (21.0.1):

```bash
docker build -f Dockerfile.test-apk -t xiond-test-apk .
docker run --rm xiond-test-apk
```

### Build with specific version:

```bash
docker build -f Dockerfile.test-apk --build-arg XIOND_VERSION=21.0.1 -t xiond-test-apk:21.0.1 .
docker run --rm xiond-test-apk:21.0.1
```

### Interactive testing:

```bash
docker run --rm -it xiond-test-apk /bin/sh
# Inside container, run:
xiond version
xiond version --long
apk info xiond
```

## Test All Package Formats

Quick script to test all three package formats:

```bash
# Build all
docker build -f Dockerfile.test-deb -t xiond-test-deb .
docker build -f Dockerfile.test-rpm -t xiond-test-rpm .
docker build -f Dockerfile.test-apk -t xiond-test-apk .

# Run all and verify
echo "=== DEB (apt) ==="
docker run --rm xiond-test-deb xiond version --long

echo -e "\n=== RPM (yum) ==="
docker run --rm xiond-test-rpm xiond version --long

echo -e "\n=== APK (apk) ==="
docker run --rm xiond-test-apk xiond version --long
```

## Expected Output

The container should output version information similar to:

```
21.0.1
```

For detailed version information:

```bash
docker run --rm xiond-test-deb xiond version --long
```

## Repository Information

- **DEB/APT Repository**: https://packages.burnt.com/apt
  - GPG Key: https://packages.burnt.com/apt/gpg.key
- **RPM/YUM Repository**: https://packages.burnt.com/yum/
  - GPG Key: https://packages.burnt.com/yum/gpg.key
- **APK/Alpine Repository**: https://alpine.fury.io/burnt
  - RSA Key: https://alpine.fury.io/burnt/burnt@fury.io-b8abd990.rsa.pub
- **Gemfury Management**: https://manage.fury.io/burnt

## Troubleshooting

### Version mismatch
If the installed version doesn't match Gemfury:
1. Check Gemfury dashboard for latest published version
2. Verify packages.burnt.com is synced with Gemfury
3. Clear apt cache: `apt-get clean && apt-get update`


