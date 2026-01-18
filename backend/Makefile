.PHONY: build run test clean deps fmt vet lint staging run-staging k6-load k6-stress k6-install

# Build the application
build:
	go build -o bin/server ./cmd/server

# Run the application
run:
	go run ./cmd/server

# Build the mock server
build-mock:
	go build -o bin/mock-server ./cmd/mock-server

# Run the mock server
run-mock:
	go run ./cmd/mock-server

# Run tests
test:
	go test -v ./...

# Run tests with coverage
test-coverage:
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Clean build artifacts
clean:
	rm -rf bin/
	rm -f coverage.out coverage.html

# Download dependencies
deps:
	go mod download
	go mod tidy

# Format code
fmt:
	go fmt ./...

# Run go vet
vet:
	go vet ./...

# Run linter (requires golangci-lint)
lint:
	golangci-lint run

# Install dependencies
install:
	go mod download

# Run all checks
check: fmt vet test

# Staging environment setup
# Note: Create .env.staging file with staging configuration
# Example:
# PORT=8080
# REDIS_ADDR=localhost:6379
# REDIS_PASSWORD=
# TOKEN_SECRET=staging-secret-key-must-be-at-least-32-characters-long-for-security
# ADMIN_API_KEY=staging-admin-api-key-12345
# LOG_LEVEL=info
# METRICS_PORT=9090
staging:
	@echo "Starting server with staging configuration..."
	@if [ -f .env.staging ]; then \
		export $$(cat .env.staging | grep -v '^#' | xargs) && go run ./cmd/server; \
	else \
		echo "Error: .env.staging file not found. Creating template..."; \
		echo "PORT=8080" > .env.staging; \
		echo "REDIS_ADDR=localhost:6379" >> .env.staging; \
		echo "REDIS_PASSWORD=" >> .env.staging; \
		echo "TOKEN_SECRET=staging-secret-key-must-be-at-least-32-characters-long-for-security" >> .env.staging; \
		echo "ADMIN_API_KEY=staging-admin-api-key-12345" >> .env.staging; \
		echo "LOG_LEVEL=info" >> .env.staging; \
		echo "METRICS_PORT=9090" >> .env.staging; \
		echo ".env.staging created. Please review and run 'make staging' again."; \
	fi

# Run server with staging environment variables
run-staging:
	@if [ -f .env.staging ]; then \
		export $$(cat .env.staging | grep -v '^#' | xargs) && go run ./cmd/server; \
	else \
		echo "Error: .env.staging file not found. Run 'make staging' first."; \
		exit 1; \
	fi

# Install k6 (if not already installed)
k6-install:
	@echo "Installing k6..."
	@if command -v k6 >/dev/null 2>&1; then \
		echo "k6 is already installed: $$(k6 version)"; \
	else \
		echo "Please install k6 from https://k6.io/docs/getting-started/installation/"; \
		echo "Or use: brew install k6 (macOS) / choco install k6 (Windows)"; \
	fi

# Run k6 load test with 4k users
k6-load:
	@if command -v k6 >/dev/null 2>&1; then \
		k6 run --out json=results-load.json k6/load-test.js; \
	else \
		echo "Error: k6 not found. Install it first with 'make k6-install' or visit https://k6.io"; \
		exit 1; \
	fi

# Run k6 stress test with 4k users (rapid ramp-up)
k6-stress:
	@if command -v k6 >/dev/null 2>&1; then \
		k6 run --out json=results-stress.json k6/stress-test.js; \
	else \
		echo "Error: k6 not found. Install it first with 'make k6-install' or visit https://k6.io"; \
		exit 1; \
	fi

# Run k6 load test with custom base URL
k6-load-custom:
	@if command -v k6 >/dev/null 2>&1; then \
		read -p "Enter base URL (default: http://localhost:8080): " url; \
		k6 run -e BASE_URL=$${url:-http://localhost:8080} k6/load-test.js; \
	else \
		echo "Error: k6 not found. Install it first with 'make k6-install' or visit https://k6.io"; \
		exit 1; \
	fi

# Run k6 load test against remote staging server
# Usage: make k6-load-remote BASE_URL=https://staging.example.com
k6-load-remote:
	@if [ -z "$(BASE_URL)" ]; then \
		echo "Error: BASE_URL is required. Usage: make k6-load-remote BASE_URL=https://staging.example.com"; \
		exit 1; \
	fi
	@if command -v k6 >/dev/null 2>&1; then \
		k6 run -e BASE_URL=$(BASE_URL) -e EVENT_ID=$(or $(EVENT_ID),staging-test-event-001) -e ADMIN_API_KEY=$(or $(ADMIN_API_KEY),staging-admin-api-key-12345) --out json=results-remote-$$(date +%Y%m%d-%H%M%S).json k6/load-test-remote.js; \
	else \
		echo "Error: k6 not found. Install it first with 'make k6-install' or visit https://k6.io"; \
		exit 1; \
	fi
