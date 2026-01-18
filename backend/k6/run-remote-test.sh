#!/bin/bash
# Script to run k6 load test against remote staging server

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
BASE_URL="${BASE_URL:-}"
EVENT_ID="${EVENT_ID:test-event}"
ADMIN_API_KEY="${ADMIN_API_KEY:-staging-admin-api-key-12345}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if BASE_URL is set
if [ -z "$BASE_URL" ]; then
    echo -e "${RED}❌ Error: BASE_URL environment variable is required${NC}"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  BASE_URL=https://staging.example.com ./run-remote-test.sh"
    echo -e "  or"
    echo -e "  export BASE_URL=https://staging.example.com"
    echo -e "  ./run-remote-test.sh"
    exit 1
fi

# Check if k6 is installed
if ! command -v k6 >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: k6 is not installed${NC}"
    echo -e "${YELLOW}Install k6:${NC}"
    echo -e "  macOS: brew install k6"
    echo -e "  Windows: choco install k6"
    echo -e "  Linux: See https://k6.io/docs/getting-started/installation/"
    exit 1
fi

# Verify server is accessible
echo -e "${GREEN}🔍 Verifying server is accessible...${NC}"
if curl -f -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health" | grep -q "200\|OK"; then
    echo -e "${GREEN}✅ Server is accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Could not verify server health endpoint${NC}"
    echo -e "${YELLOW}   Continuing anyway...${NC}"
fi

# Run the test
echo -e "${GREEN}🚀 Starting k6 load test...${NC}"
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Base URL: ${BASE_URL}"
echo -e "  Event ID: ${EVENT_ID}"
echo -e "  Admin API Key: ${ADMIN_API_KEY:0:20}..."
echo ""

# Change to script directory to ensure correct paths
cd "$SCRIPT_DIR"

k6 run \
    -e BASE_URL="${BASE_URL}" \
    -e EVENT_ID="${EVENT_ID}" \
    -e ADMIN_API_KEY="${ADMIN_API_KEY}" \
    --out json=results-remote-$(date +%Y%m%d-%H%M%S).json \
    "${SCRIPT_DIR}/load-test-remote.js"

echo -e "${GREEN}✅ Test completed!${NC}"
