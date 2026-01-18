#!/bin/bash
# Android Emulator Load Test Script
# Launches multiple Android emulators and runs the Gatekeep app to simulate load

set -e

# Configuration
NUM_EMULATORS="${NUM_EMULATORS:-10}"
BASE_URL="${BASE_URL:-http://10.0.2.2:8080}"
EVENT_ID="${EVENT_ID:-android-load-test}"
AVD_NAME="${AVD_NAME:-Pixel_5_API_33}"
PACKAGE_NAME="com.example.gatekeep_example"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🤖 Android Emulator Load Test${NC}"
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Number of emulators: ${NUM_EMULATORS}"
echo -e "  Base URL: ${BASE_URL}"
echo -e "  Event ID: ${EVENT_ID}"
echo -e "  AVD Name: ${AVD_NAME}"
echo ""

# Check prerequisites
if ! command -v adb >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: adb not found. Install Android SDK Platform Tools${NC}"
    exit 1
fi

if ! command -v emulator >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: emulator not found. Install Android SDK Emulator${NC}"
    exit 1
fi

# Check if AVD exists
if ! emulator -list-avds | grep -q "^${AVD_NAME}$"; then
    echo -e "${RED}❌ Error: AVD '${AVD_NAME}' not found${NC}"
    echo -e "${YELLOW}Available AVDs:${NC}"
    emulator -list-avds
    exit 1
fi

# Function to wait for emulator to be ready
wait_for_emulator() {
    local port=$1
    local max_attempts=60
    local attempt=0
    
    echo -e "${YELLOW}⏳ Waiting for emulator on port ${port}...${NC}"
    
    while [ $attempt -lt $max_attempts ]; do
        if adb -s emulator-${port} shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; then
            echo -e "${GREEN}✅ Emulator on port ${port} is ready${NC}"
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ Timeout waiting for emulator on port ${port}${NC}"
    return 1
}

# Function to launch emulator
launch_emulator() {
    local port=$1
    local avd=$2
    
    echo -e "${BLUE}🚀 Launching emulator ${port}...${NC}"
    
    # Start emulator in background
    emulator -avd "$avd" -port $port -no-snapshot-load -wipe-data > /dev/null 2>&1 &
    local emulator_pid=$!
    
    # Wait for emulator to be ready
    if wait_for_emulator $port; then
        echo "$emulator_pid:$port"
        return 0
    else
        kill $emulator_pid 2>/dev/null || true
        return 1
    fi
}

# Function to install and launch app on emulator
setup_emulator() {
    local port=$1
    local base_url=$2
    local event_id=$3
    
    echo -e "${BLUE}📱 Setting up emulator ${port}...${NC}"
    
    # Install app (assuming it's built)
    if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
        adb -s emulator-${port} install -r build/app/outputs/flutter-apk/app-debug.apk
        echo -e "${GREEN}✅ App installed on emulator ${port}${NC}"
    else
        echo -e "${YELLOW}⚠️  APK not found, building...${NC}"
        flutter build apk --debug
        adb -s emulator-${port} install -r build/app/outputs/flutter-apk/app-debug.apk
    fi
    
    # Set up test data via ADB (you may need to customize this)
    # For now, we'll just launch the app
    adb -s emulator-${port} shell am start -n "${PACKAGE_NAME}/.MainActivity" \
        --es "BASE_URL" "${base_url}" \
        --es "EVENT_ID" "${event_id}"
    
    echo -e "${GREEN}✅ Emulator ${port} setup complete${NC}"
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up emulators...${NC}"
    
    # Kill all emulators
    adb devices | grep "emulator-" | cut -f1 | while read device; do
        echo -e "${YELLOW}  Stopping ${device}...${NC}"
        adb -s "$device" emu kill 2>/dev/null || true
    done
    
    # Wait a bit for cleanup
    sleep 3
    
    # Force kill any remaining emulator processes
    pkill -f "emulator.*${AVD_NAME}" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Trap to cleanup on exit
trap cleanup EXIT INT TERM

# Main execution
echo -e "${GREEN}🚀 Starting ${NUM_EMULATORS} Android emulators...${NC}"

EMULATOR_PIDS=()
START_PORT=5554

# Launch emulators
for i in $(seq 1 $NUM_EMULATORS); do
    port=$((START_PORT + (i - 1) * 2))
    
    if result=$(launch_emulator $port "$AVD_NAME"); then
        pid=$(echo $result | cut -d: -f1)
        EMULATOR_PIDS+=("$pid:$port")
        echo -e "${GREEN}✅ Emulator ${i}/${NUM_EMULATORS} launched (port ${port})${NC}"
        
        # Stagger launches to avoid overwhelming system
        if [ $i -lt $NUM_EMULATORS ]; then
            sleep 5
        fi
    else
        echo -e "${RED}❌ Failed to launch emulator ${i}${NC}"
    fi
done

echo -e "${GREEN}✅ All emulators launched${NC}"
echo -e "${YELLOW}⏳ Waiting for all emulators to be fully ready...${NC}"
sleep 10

# Setup each emulator
for entry in "${EMULATOR_PIDS[@]}"; do
    port=$(echo $entry | cut -d: -f2)
    setup_emulator $port "$BASE_URL" "$EVENT_ID" &
done

# Wait for all setups to complete
wait

echo -e "${GREEN}✅ All emulators are running and configured${NC}"
echo -e "${YELLOW}📊 Monitoring emulators...${NC}"
echo -e "${YELLOW}   Press Ctrl+C to stop${NC}"

# Monitor emulators
while true; do
    running=$(adb devices | grep "emulator-" | wc -l)
    echo -e "${BLUE}📱 Running emulators: ${running}/${NUM_EMULATORS}${NC}"
    sleep 30
done
