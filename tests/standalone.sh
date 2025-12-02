#!/bin/bash
# Standalone runtime tests for UniFi container
# Tests basic container functionality without MongoDB dependency
# Merges runtime-test.sh and smoke-test.sh best parts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-unifi:master}"
CONTAINER_NAME="unifi-test-standalone-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

log_info "========================================="
log_info "Standalone Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Start container
log_info "Starting UniFi container in standalone mode..."
if docker run -d --name "$CONTAINER_NAME" \
    -e UNIFI_HTTP_PORT=8080 \
    -e UNIFI_HTTPS_PORT=8443 \
    "$IMAGE_NAME"; then
    log_success "Container started successfully"
else
    log_error "Container failed to start"
    exit 1
fi

# Test 1: Container stays running
log_info "Test 1: Container stability check"
if wait_container_stable "$CONTAINER_NAME" 10; then
    log_success "Container is stable and running"
else
    log_error "Container is not stable"
fi

# Test 2: Process runs as correct user
log_info "Test 2: Java process runs as unifi user"
if docker exec "$CONTAINER_NAME" ps aux | grep -v grep | grep java | grep -q "^unifi"; then
    log_success "Process running as unifi user"
else
    log_error "Process not running as unifi user"
    docker exec "$CONTAINER_NAME" ps aux | grep java || true
fi

# Test 3: Data directory is writable
log_info "Test 3: Data directory is writable"
if docker exec "$CONTAINER_NAME" test -w /usr/lib/unifi/data; then
    log_success "Data directory is writable"
else
    log_error "Data directory is not writable"
fi

# Test 4: Log files are being created
log_info "Test 4: Log files are created"
sleep 5
if docker exec "$CONTAINER_NAME" sh -c "ls /logs/*.log 2>/dev/null" | grep -q ".log"; then
    log_success "Log files created in /logs"
else
    log_error "No log files found in /logs"
    docker exec "$CONTAINER_NAME" ls -la /logs || true
fi

# Test 5: JVM memory settings applied
log_info "Test 5: JVM memory settings applied"
if docker exec "$CONTAINER_NAME" ps aux | grep java | grep -q -- "-Xmx1024M"; then
    log_success "Memory settings applied correctly"
else
    log_error "Memory settings not applied"
    docker exec "$CONTAINER_NAME" ps aux | grep java || true
fi

# Test 6: Java process health
log_info "Test 6: Java process is healthy"
if docker exec "$CONTAINER_NAME" ps aux | grep java | grep -q ace.jar; then
    log_success "Java process running with ace.jar"
else
    log_error "Java process not healthy"
    docker exec "$CONTAINER_NAME" ps aux || true
fi

# Test 7: No Out of Memory errors
log_info "Test 7: No memory errors"
if docker logs "$CONTAINER_NAME" 2>&1 | grep -qiE "OutOfMemory|OOM killed"; then
    log_error "Out of memory errors detected"
else
    log_success "No memory errors"
fi

# Test 8: Check for critical startup errors
log_info "Test 8: Checking for critical errors"
if docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "fatal error|Cannot start|Failed to start" | grep -v "ErrorFile"; then
    log_warn "Found critical errors in logs"
else
    log_success "No critical startup errors"
fi

# Test 9: UniFi attempts to start (even without MongoDB)
log_info "Test 9: UniFi initialization check"
sleep 20  # Give UniFi time to initialize
if docker logs "$CONTAINER_NAME" 2>&1 | grep -qiE "Starting.*unifi|UniFi.*started|Listening on"; then
    log_success "UniFi initialization detected"
else
    # This is expected if MongoDB is not available
    if docker logs "$CONTAINER_NAME" 2>&1 | grep -qiE "mongo|database"; then
        log_warn "UniFi waiting for MongoDB (expected in standalone mode)"
    else
        log_warn "Could not confirm UniFi initialization"
    fi
fi

# Test 10: Container still running after all tests
log_info "Test 10: Container still running"
if is_container_running "$CONTAINER_NAME"; then
    log_success "Container still running after all tests"
else
    log_error "Container stopped during tests"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -30
fi

# Test 11: Required directories are accessible
log_info "Test 11: Required directories accessible"
DIRS_OK=true
for dir in /usr/lib/unifi/data /usr/lib/unifi/run /logs; do
    if docker exec "$CONTAINER_NAME" test -d "$dir"; then
        log_success "Directory $dir is accessible"
    else
        log_error "Directory $dir is not accessible"
        DIRS_OK=false
    fi
done

# Test 12: Configuration files can be written
log_info "Test 12: Configuration can be written"
if docker exec "$CONTAINER_NAME" sh -c 'echo "test=true" > /usr/lib/unifi/data/test.properties' 2>/dev/null; then
    log_success "Can write configuration files"
    docker exec "$CONTAINER_NAME" rm /usr/lib/unifi/data/test.properties 2>/dev/null || true
else
    log_error "Cannot write configuration files"
fi

# Print summary and exit
print_summary "Standalone Tests"
exit $TEST_FAILED
