#!/bin/bash
# Integration tests for UniFi with MongoDB
# Tests full stack functionality with external database

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-unifi-network:main}"

# Unique resource names based on PID
TEST_ID=$$
MONGODB_CONTAINER="unifi-test-mongodb-$TEST_ID"
UNIFI_CONTAINER="unifi-test-integration-$TEST_ID"
NETWORK_NAME="unifi-test-$TEST_ID"
VOLUME_DATA="unifi-test-data-$TEST_ID"
VOLUME_LOGS="unifi-test-logs-$TEST_ID"

cleanup() {
    log_info "Cleaning up integration test environment..."
    docker rm -f "$MONGODB_CONTAINER" "$UNIFI_CONTAINER" 2>/dev/null || true
    docker volume rm "$VOLUME_DATA" "$VOLUME_LOGS" 2>/dev/null || true
    docker network rm "$NETWORK_NAME" 2>/dev/null || true
}

trap cleanup EXIT

log_info "========================================="
log_info "Integration Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Create network
log_info "Creating test network..."
docker network create "$NETWORK_NAME"

# Create volumes
log_info "Creating data volumes..."
docker volume create "$VOLUME_DATA"
docker volume create "$VOLUME_LOGS"

# Start MongoDB
log_info "Starting MongoDB container..."
docker run -d \
  --name "$MONGODB_CONTAINER" \
  --network "$NETWORK_NAME" \
  --network-alias mongodb \
  -e MONGO_INITDB_DATABASE=unifi \
  mongo:7

# Test 1: Wait for MongoDB to be healthy
log_info "Test 1: MongoDB startup and health check"
MONGODB_READY=false
for i in {1..30}; do
    if docker exec "$MONGODB_CONTAINER" mongosh --eval "db.runCommand('ping')" unifi --quiet 2>/dev/null | grep -q "ok"; then
        log_success "MongoDB is ready and healthy"
        MONGODB_READY=true
        break
    fi
    sleep 2
done

if [ "$MONGODB_READY" = "false" ]; then
    log_error "MongoDB failed to become ready"
    exit 1
fi

# Start UniFi (after MongoDB is healthy)
log_info "Starting UniFi container..."
docker run -d \
  --name "$UNIFI_CONTAINER" \
  --network "$NETWORK_NAME" \
  -e DB_URI=mongodb://mongodb:27017/unifi \
  -e DB_NAME=unifi \
  -p 18080:8080 \
  -p 18443:8443 \
  -v "$VOLUME_DATA":/usr/lib/unifi/data \
  -v "$VOLUME_LOGS":/logs \
  "$IMAGE_NAME"

# Test 2: Both containers running
log_info "Test 2: Both containers are running"
if docker ps | grep -q "$MONGODB_CONTAINER" && docker ps | grep -q "$UNIFI_CONTAINER"; then
    log_success "Both UniFi and MongoDB containers running"
else
    log_error "One or more containers not running"
    docker ps -a
fi

# Test 3: UniFi container stability
log_info "Test 3: UniFi container stability check"
sleep 10
if is_container_running "$UNIFI_CONTAINER"; then
    log_success "UniFi container is stable"
else
    log_error "UniFi container is not stable"
    docker logs "$UNIFI_CONTAINER" | tail -20
fi

# Test 4: Network connectivity between containers
log_info "Test 4: Network connectivity between containers"
if docker exec "$UNIFI_CONTAINER" sh -c "getent hosts mongodb" >/dev/null 2>&1; then
    log_success "UniFi can resolve MongoDB hostname"
else
    log_error "UniFi cannot resolve MongoDB hostname"
fi

# Test 5: Data directories are writable
log_info "Test 5: Data directories are mounted and writable"
if docker exec "$UNIFI_CONTAINER" test -w /usr/lib/unifi/data && \
   docker exec "$UNIFI_CONTAINER" test -w /logs; then
    log_success "Data directories are writable"
else
    log_error "Data directories are not writable"
fi

# Test 6: UniFi initialization and startup check
log_info "Test 6: UniFi service initialization check"
if wait_for_http "https://localhost:18443" 60 "200|302|401"; then
    log_success "UniFi web interface is fully responding"
else
    log_error "UniFi web interface failed to start after 60 seconds"
    docker logs "$UNIFI_CONTAINER" 2>&1 | tail -30
fi

# Test 7: UniFi inform port responding
log_info "Test 7: UniFi inform port responding"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18080 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
    log_success "Inform port responding (HTTP $HTTP_CODE)"
else
    log_error "Inform port not responding"
fi

# Test 8: Check MongoDB connection from UniFi
log_info "Test 8: MongoDB connection from UniFi"
sleep 5
if docker logs "$UNIFI_CONTAINER" 2>&1 | grep -qiE "connected to.*mongo|database.*connected"; then
    log_success "MongoDB connection confirmed in logs"
elif ! docker logs "$UNIFI_CONTAINER" 2>&1 | grep -qiE "mongo.*connection.*fail|database.*error|Cannot connect.*mongo"; then
    log_success "No MongoDB connection errors found"
else
    log_warn "Possible MongoDB connection issues detected"
    docker logs "$UNIFI_CONTAINER" 2>&1 | grep -i mongo | tail -10
fi

# Test 9: UniFi configuration files created
log_info "Test 9: UniFi configuration files created"
sleep 10
if docker exec "$UNIFI_CONTAINER" sh -c "ls /usr/lib/unifi/data/*.properties 2>/dev/null" | grep -q "properties"; then
    log_success "UniFi configuration files created"
else
    log_warn "No configuration files found yet (may still be initializing)"
fi

# Test 10: Check for setup wizard or API endpoints
log_info "Test 10: UniFi interface content verification"
RESPONSE=$(curl -k -s https://localhost:18443/ 2>/dev/null || echo "")
if echo "$RESPONSE" | grep -qiE "unifi|setup|wizard|controller"; then
    log_success "UniFi interface responding with expected content"
else
    log_warn "Could not verify UniFi interface content"
fi

# Test 11: API endpoint check
log_info "Test 11: API endpoint responding"
API_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost:18443/api/status 2>/dev/null || echo "000")
if [ "$API_CODE" != "000" ] && [ -n "$API_CODE" ]; then
    log_success "API endpoint responding (HTTP $API_CODE)"
else
    log_warn "API endpoint may not be ready yet"
fi

# Test 12: No critical errors in logs
log_info "Test 12: No critical errors in logs"
if docker logs "$UNIFI_CONTAINER" 2>&1 | grep -iE "fatal error|Cannot start|Failed to start|OutOfMemory|OOM killed"; then
    log_error "Critical errors found in logs"
else
    log_success "No critical errors in logs"
fi

# Test 13: Verify data persistence volumes
log_info "Test 13: Docker volumes created"
if docker volume ls | grep -q "$VOLUME_DATA" && docker volume ls | grep -q "$VOLUME_LOGS"; then
    log_success "Data persistence volumes created"
else
    log_warn "Could not verify all volumes"
fi

# Print summary and exit
print_summary "Integration Tests"
exit $TEST_FAILED
