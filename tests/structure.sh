#!/bin/bash
# Structure tests for UniFi Docker image
# Pure bash implementation - no external dependencies
# Tests: user/permissions, ports, file existence, packages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-unifi:master}"
CONTAINER_NAME="unifi-test-structure-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

log_info "========================================="
log_info "Structure Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Start container for inspection
log_info "Starting container for structure inspection..."
docker run -d --name "$CONTAINER_NAME" "$IMAGE_NAME" sleep 3600 >/dev/null 2>&1

# Test 1: UniFi user exists with correct UID
log_info "Test 1: UniFi user exists with UID 5000"
UID_CHECK=$(docker exec "$CONTAINER_NAME" id -u unifi 2>/dev/null || echo "")
if [ "$UID_CHECK" = "5000" ]; then
    log_success "UniFi user has correct UID (5000)"
else
    log_error "UniFi user UID is '$UID_CHECK', expected 5000"
fi

# Test 2: UniFi group exists with correct GID
log_info "Test 2: UniFi group exists with GID 5000"
GID_CHECK=$(docker exec "$CONTAINER_NAME" id -g unifi 2>/dev/null || echo "")
if [ "$GID_CHECK" = "5000" ]; then
    log_success "UniFi group has correct GID (5000)"
else
    log_error "UniFi group GID is '$GID_CHECK', expected 5000"
fi

# Test 3: Exposed ports metadata
log_info "Test 3: Image exposes correct ports (8080, 8443)"
EXPOSED_PORTS=$(docker inspect "$IMAGE_NAME" --format='{{json .Config.ExposedPorts}}' 2>/dev/null || echo "")
if echo "$EXPOSED_PORTS" | grep -q "8080" && echo "$EXPOSED_PORTS" | grep -q "8443"; then
    log_success "Ports 8080 and 8443 are exposed"
else
    log_error "Expected ports not exposed: $EXPOSED_PORTS"
fi

# Test 4: Container runs as unifi user
log_info "Test 4: Container user is set to 'unifi'"
CONTAINER_USER=$(docker inspect "$IMAGE_NAME" | grep -o '"User": "[^"]*"' | cut -d'"' -f4)
if [ "$CONTAINER_USER" = "unifi" ]; then
    log_success "Container user is 'unifi'"
else
    log_error "Container user is '$CONTAINER_USER', expected 'unifi'"
fi

# Test 5: UniFi ACE JAR exists
log_info "Test 5: UniFi ACE JAR exists"
if docker exec "$CONTAINER_NAME" test -f /usr/lib/unifi/lib/ace.jar; then
    log_success "UniFi ACE JAR exists"
else
    log_error "UniFi ACE JAR not found"
fi

# Test 6: Data directory exists with correct ownership
log_info "Test 6: UniFi data directory exists with correct ownership"
if docker exec "$CONTAINER_NAME" test -e /usr/lib/unifi/data; then
    # Check the actual target (might be a symlink to /var/lib/unifi)
    DATA_DIR_UID=$(docker exec "$CONTAINER_NAME" stat -c '%u' -L /usr/lib/unifi/data)
    DATA_DIR_GID=$(docker exec "$CONTAINER_NAME" stat -c '%g' -L /usr/lib/unifi/data)
    if [ "$DATA_DIR_UID" = "5000" ] && [ "$DATA_DIR_GID" = "5000" ]; then
        log_success "Data directory exists with correct ownership (5000:5000)"
    else
        log_error "Data directory ownership is $DATA_DIR_UID:$DATA_DIR_GID, expected 5000:5000"
    fi
else
    log_error "Data directory /usr/lib/unifi/data does not exist"
fi

# Test 7: Logs directory exists with correct ownership
log_info "Test 7: Logs directory exists with correct ownership"
if docker exec "$CONTAINER_NAME" test -d /logs; then
    LOGS_DIR_UID=$(docker exec "$CONTAINER_NAME" stat -c '%u' /logs)
    LOGS_DIR_GID=$(docker exec "$CONTAINER_NAME" stat -c '%g' /logs)
    if [ "$LOGS_DIR_UID" = "5000" ] && [ "$LOGS_DIR_GID" = "5000" ]; then
        log_success "Logs directory exists with correct ownership (5000:5000)"
    else
        log_error "Logs directory ownership is $LOGS_DIR_UID:$LOGS_DIR_GID, expected 5000:5000"
    fi
else
    log_error "Logs directory /logs does not exist"
fi

# Test 8: Run directory exists with correct ownership
log_info "Test 8: UniFi run directory exists with correct ownership"
if docker exec "$CONTAINER_NAME" test -d /usr/lib/unifi/run; then
    RUN_DIR_UID=$(docker exec "$CONTAINER_NAME" stat -c '%u' /usr/lib/unifi/run)
    RUN_DIR_GID=$(docker exec "$CONTAINER_NAME" stat -c '%g' /usr/lib/unifi/run)
    if [ "$RUN_DIR_UID" = "5000" ] && [ "$RUN_DIR_GID" = "5000" ]; then
        log_success "Run directory exists with correct ownership (5000:5000)"
    else
        log_error "Run directory ownership is $RUN_DIR_UID:$RUN_DIR_GID, expected 5000:5000"
    fi
else
    log_error "Run directory /usr/lib/unifi/run does not exist"
fi

# Test 9: Java is installed
log_info "Test 9: Java is installed and executable"
if docker exec "$CONTAINER_NAME" java -version 2>&1 | grep -q "version"; then
    log_success "Java is installed"
else
    log_error "Java is not installed or not executable"
fi

# Test 10: UniFi GPG key exists
log_info "Test 10: UniFi GPG key exists"
if docker exec "$CONTAINER_NAME" test -f /etc/apt/trusted.gpg.d/unifi-repo.gpg; then
    log_success "UniFi GPG key exists"
else
    log_error "UniFi GPG key not found"
fi

# Test 11: UniFi repository configured
log_info "Test 11: UniFi repository configured"
if docker exec "$CONTAINER_NAME" grep -q "deb https://www.ui.com/downloads/unifi/debian stable ubiquiti" /etc/apt/sources.list.d/100-ubnt-unifi.list 2>/dev/null; then
    log_success "UniFi repository configured correctly"
else
    log_error "UniFi repository not configured or incorrect"
fi

# Test 12: UniFi package installed
log_info "Test 12: UniFi package installed"
if docker exec "$CONTAINER_NAME" dpkg -l unifi 2>/dev/null | grep -q "^ii.*unifi"; then
    log_success "UniFi package is installed"
else
    log_error "UniFi package is not installed"
fi

# Test 13: MongoDB dummy package installed
log_info "Test 13: MongoDB dummy package installed"
if docker exec "$CONTAINER_NAME" dpkg -l mongodb-server 2>/dev/null | grep -q "^ii.*mongodb-server"; then
    log_success "MongoDB dummy package is installed"
else
    log_error "MongoDB dummy package is not installed"
fi

# Test 14: CA certificates installed
log_info "Test 14: CA certificates installed"
if docker exec "$CONTAINER_NAME" test -f /etc/ssl/certs/ca-certificates.crt; then
    log_success "CA certificates are installed"
else
    log_error "CA certificates not found"
fi

# Test 15: No temporary files left behind
log_info "Test 15: No temporary files left in /tmp"
TMP_COUNT=$(docker exec "$CONTAINER_NAME" sh -c 'ls /tmp 2>&1 | wc -l' 2>/dev/null || echo "1")
if [ "$TMP_COUNT" = "0" ]; then
    log_success "No temporary files in /tmp"
else
    log_warn "Found $TMP_COUNT items in /tmp (may be expected)"
fi

# Print summary and exit
print_summary "Structure Tests"
exit $TEST_FAILED
