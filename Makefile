PKGNAME:=unifi-network
TAG:=main
DOCKERFILE:=Dockerfile

.PHONY: build push test test-all test-structure test-standalone test-integration clean-test

build:
	docker build --pull -t $(PKGNAME):$(TAG) -f $(DOCKERFILE) .

test-structure: build
	@echo "========================================="
	@echo "Running Structure Tests"
	@echo "========================================="
	./tests/structure.sh $(PKGNAME):$(TAG)

test-standalone: build
	@echo "========================================="
	@echo "Running Standalone Tests"
	@echo "========================================="
	./tests/standalone.sh $(PKGNAME):$(TAG)

test-integration: build
	@echo "========================================="
	@echo "Running Integration Tests"
	@echo "========================================="
	./tests/integration.sh $(PKGNAME):$(TAG)

test-all: test-structure test-standalone test-integration
	@echo ""
	@echo "========================================="
	@echo "All test suites PASSED!"
	@echo "========================================="

test: test-all

clean-test:
	docker rm -f unifi-test-* 2>/dev/null || true
	docker volume rm -f unifi-test-* 2>/dev/null || true
	docker network rm unifi-test-* 2>/dev/null || true
