#!/bin/bash
# Common test utilities for UniFi Docker tests
# Provides logging, cleanup, and waiting functions

# Global test failure flag
TEST_FAILED=0

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
    TEST_FAILED=1
}

log_warn() {
    echo "[WARN] $1"
}

log_step() {
    echo "===> $1"
}

log_success() {
    echo "✓ $1"
}

# Container cleanup function
cleanup_container() {
    local container_name="$1"
    if [ -n "$container_name" ]; then
        log_info "Cleaning up container: $container_name"
        docker rm -f "$container_name" 2>/dev/null || true
    fi
}

# Cleanup multiple containers
cleanup_containers() {
    for container in "$@"; do
        cleanup_container "$container"
    done
}

# Wait for HTTP endpoint with exponential backoff
# Usage: wait_for_http <url> <max_wait_seconds> [expected_codes]
wait_for_http() {
    local url="$1"
    local max_wait="${2:-120}"
    local expected_codes="${3:-200|302|401}"
    local wait_time=0
    local backoff=1

    log_info "Waiting for HTTP endpoint: $url (max: ${max_wait}s)"

    while [ $wait_time -lt $max_wait ]; do
        local http_code
        http_code=$(curl -k -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

        if echo "$http_code" | grep -qE "$expected_codes"; then
            log_info "✓ Endpoint ready after ${wait_time}s (HTTP $http_code)"
            return 0
        fi

        sleep "$backoff"
        wait_time=$((wait_time + backoff))

        # Exponential backoff: 1, 2, 4, 8, then stay at 8
        if [ $backoff -lt 8 ]; then
            backoff=$((backoff * 2))
        fi
    done

    log_info "✗ Endpoint not ready after ${max_wait}s"
    return 1
}

# Wait for container port to be listening
# Usage: wait_for_port <container_name> <port> <max_wait_seconds>
wait_for_port() {
    local container="$1"
    local port="$2"
    local max_wait="${3:-60}"
    local wait_time=0
    local backoff=1

    log_info "Waiting for port $port in container $container"

    # Convert port to hex for /proc/net/tcp lookup
    local port_hex
    port_hex=$(printf '%04X' "$port")

    while [ $wait_time -lt $max_wait ]; do
        if docker exec "$container" sh -c "grep -q ':$port_hex ' /proc/net/tcp*" 2>/dev/null; then
            log_info "✓ Port $port listening after ${wait_time}s"
            return 0
        fi

        sleep "$backoff"
        wait_time=$((wait_time + backoff))

        # Exponential backoff: 1, 2, 4, 8
        if [ $backoff -lt 8 ]; then
            backoff=$((backoff * 2))
        fi
    done

    log_warn "⚠ Port $port not listening after ${max_wait}s"
    return 1
}

# Wait for container to stay running
# Usage: wait_container_stable <container_name> <seconds>
wait_container_stable() {
    local container="$1"
    local seconds="${2:-10}"

    log_info "Checking container stability for ${seconds}s"
    sleep "$seconds"

    if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
        log_info "✓ Container stable and running"
        return 0
    else
        log_error "✗ Container exited prematurely"
        docker logs "$container" 2>&1 | tail -20
        return 1
    fi
}

# Check if container is running
is_container_running() {
    local container="$1"
    docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"
}

# Print test summary
print_summary() {
    local test_name="$1"
    echo ""
    echo "========================================="
    if [ $TEST_FAILED -eq 0 ]; then
        log_info "$test_name PASSED"
        echo "========================================="
        return 0
    else
        log_error "$test_name FAILED"
        echo "========================================="
        return 1
    fi
}

# Execute a test and track result
run_test() {
    local test_name="$1"
    local test_command="$2"

    log_info "Test: $test_name"
    if eval "$test_command"; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}
