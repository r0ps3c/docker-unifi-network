# UniFi Docker Image Tests

This directory contains comprehensive tests for the UniFi Network Application Docker image.

## Test Suites

### 1. Structure Tests (`structure.sh`)
Validates the built image structure and configuration:
- Correct exposed ports (8080, 8443)
- Required files exist with correct permissions
- UniFi user configured correctly (UID 5000)
- Java and UniFi packages installed
- No leftover temp files
- Proper directory ownership

**Run:** `make test-structure`

### 2. Standalone Tests (`standalone.sh`)
Validates container runtime behavior in isolation:
- Container starts and stays running
- Processes run as correct user (UID 5000)
- Ports are listening (8080, 8443)
- Log files created
- Data directories writable
- UniFi web interface accessible
- API endpoints responding correctly

**Run:** `make test-standalone`

### 3. Integration Tests (`integration.sh`)
Validates multi-container deployment with external MongoDB:
- UniFi + MongoDB working together
- Network connectivity between containers
- Database connection successful
- Data persistence across restarts
- All services healthy
- Full stack operation

**Run:** `make test-integration`

## Running Tests
### Run all tests:
```bash
make test-all
```

This runs all three test suites sequentially.

### Run individual test suites:
```bash
make test-structure    # Fast (~15-20 seconds)
make test-standalone   # Medium (~60-90 seconds)
make test-integration  # Slow (~90-120 seconds)
```

### Clean up test artifacts:
```bash
make clean-test
```

## Test Implementation

All test scripts are located in `/tests` and use a shared library for common functionality.

### Shared Library (`lib/common.sh`)

The test suite includes a shared library that provides:

- **Logging functions**: Color-coded output (info, error, warning, success)
- **Container cleanup**: Automatic cleanup of test containers
- **Wait helpers**: Exponential backoff for HTTP endpoints and container ports
- **Test tracking**: Automatic pass/fail tracking and summary reporting

All test scripts source this library for consistent behavior and output formatting.

Example usage in test scripts:
```bash
source "$(dirname "$0")/lib/common.sh"

log_step "Starting test phase"
wait_for_http "https://localhost:8443" 120 "200|302|401"
log_success "Test passed"
```

## CI/CD Integration

Tests run automatically on:
- Every push to master/main
- Every pull request
- Manual workflow trigger

Successful test runs trigger image push to container registry.

## Requirements

- Docker 20.10+
- Make
- Bash 4.0+
- curl (for standalone/integration tests)

## Test Output

All tests provide clear output with status indicators:
- `[INFO]`: Informational messages
- `✓`: Test passed
- `[ERROR]`: Test failed
- `[WARN]`: Warning (test passed with caveats)

Failed tests include diagnostic information and container logs.

## Troubleshooting

### Tests timing out
- Note that UniFi and mongodb take ~1m to fully initialize
- Tests use exponential backoff with appropriate timeouts
- Check container logs: `docker logs unifi-test-standalone` or `docker logs unifi-test-integration`

### Port conflicts
- Standalone tests use ports 8080, 8443
- Integration tests use ports 18080, 18443
- Ensure these ports are available before running tests
- Use `make clean-test` to remove old containers
- Check for conflicts: `docker ps` and `lsof -i :8080`

### Container exits immediately
- Check Docker logs: `docker logs unifi-test-<name>`
- Verify image built successfully: `docker images | grep unifi`
- Ensure sufficient disk space: `df -h`
- Check for permission issues in mounted volumes

### Integration tests fail
- Check MongoDB is accessible: `docker ps | grep mongo`
- Verify network connectivity: `docker network ls`
- Clean up volumes: `docker volume prune -f` then retry
- Check Docker is running: `docker ps`
