# UniFi Network Application Docker Image

Docker image for Ubiquiti's UniFi Network Application with automated daily builds and comprehensive testing.

## Features

- Based on Ubuntu
- Latest UniFi Network Application from official repository
- Dummy MongoDB package for external database support
- Non-root user (UID 5000)
- Automated daily builds with testing
- Comprehensive test coverage

## Quick Start

```bash
# Build the image
make build

# Run tests
make test-all

# Run container
docker run -d \
  -p 8080:8080 \
  -p 8443:8443 \
  --name unifi \
  unifi-network
```

## Image Tags

This project maintains multiple Docker image tags for different use cases:

### Tag Strategy

- **`latest`** - Most recent build (may include new major versions)
  - Updates: Automatically on every successful build
  - Use for: Testing, development, staying current

- **`<major>`** (e.g., `7`, `8`) - Latest build for specific UniFi major version
  - Updates: Automatically when new minor/patch versions released
  - Use for: Pinning to a major version while getting updates

- **`stable`** - Production-ready stable release
  - Updates: Automatically for minor/patch versions; requires PR approval for major versions
  - Use for: Production deployments requiring stability with automatic security/bug fixes

- **`<full-version>`** (e.g., `7.5.187`) - Specific version pin
  - Updates: Never (immutable)
  - Use for: Exact version reproducibility

### Examples

```bash
# Always latest (may jump major versions)
docker pull ghcr.io/r0ps3c/docker-unifi-network:latest

# Latest UniFi 7.x (auto-updates within v7)
docker pull ghcr.io/r0ps3c/docker-unifi-network:7

# Stable release (manually promoted)
docker pull ghcr.io/r0ps3c/docker-unifi-network:stable

# Exact version pin
docker pull ghcr.io/r0ps3c/docker-unifi-network:7.5.187
```

### Update Policy

- **Ubuntu base image**: Monitored by Dependabot, automatic PRs for security updates
- **UniFi package**: Checked daily, builds triggered automatically on new releases
- **Major version promotions**: Require manual PR approval before updating `stable` tag

## Testing

This image includes comprehensive automated tests organized into three focused suites:

```bash
make test-all

# Run individual test suites
make test-structure    # Image structure validation
make test-standalone   # Standalone container tests
make test-integration  # Multi-container with MongoDB
```

The test suite uses a shared library for consistent logging, cleanup, and wait operations. See [tests/README.md](tests/README.md) for detailed documentation.

## Usage

### Standalone (no external MongoDB)
```bash
docker run -d \
  -p 8080:8080 \
  -p 8443:8443 \
  -v unifi-data:/usr/lib/unifi/data \
  -v unifi-logs:/logs \
  unifi-network
```

### With External MongoDB
```bash
docker run -d \
  -p 8080:8080 \
  -p 8443:8443 \
  -e DB_URI=mongodb://mongodb:27017/unifi \
  -e DB_NAME=unifi \
  -v unifi-data:/usr/lib/unifi/data \
  -v unifi-logs:/logs \
  unifi-network
```

## Ports

- `8080` - Device inform
- `8443` - Web interface (HTTPS)

## Volumes

- `/usr/lib/unifi/data` - UniFi data directory
- `/logs` - Application logs

## Environment Variables

- `DB_URI` - MongoDB connection string
- `DB_NAME` - MongoDB database name

## License

This Docker image packaging is licensed under the MIT License.

The UniFi Network Application software is proprietary and owned by [Ubiquiti Inc.](https://www.ui.com/legal/termsofservice/)

