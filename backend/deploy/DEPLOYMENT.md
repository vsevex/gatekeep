# Staging Deployment Guide

This guide covers deploying the Gatekeep backend to a staging server behind Cloudflare and running load tests.

## Architecture

```plain
Internet → Cloudflare Workers → Staging Server (Go Backend) → Redis
                ↓
            (DDoS Protection, Rate Limiting, Caching)
```

## Prerequisites

1. **Staging Server**: Linux server (Ubuntu 20.04+ recommended)
2. **Cloudflare Account**: With Workers plan
3. **Redis**: Running on staging server or separate instance
4. **Domain**: Configured in Cloudflare (optional)
5. **SSH Access**: To staging server

## Step 1: Prepare Staging Server

### 1.1 Server Setup

```bash
# SSH into your staging server
ssh user@your-staging-server.com

# Create application user
sudo useradd -r -s /bin/false gatekeep
sudo mkdir -p /opt/gatekeep
sudo mkdir -p /opt/gatekeep/logs
sudo chown -R gatekeep:gatekeep /opt/gatekeep
```

### 1.2 Install Redis

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install redis-server -y
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Verify Redis
redis-cli ping
# Should return: PONG
```

### 1.3 Install Go (if building on server)

```bash
# Or build locally and deploy binary
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

## Step 2: Configure Environment

### 2.1 Create `.env.staging` on Server

```bash
# On staging server
sudo nano /opt/gatekeep/.env.staging
```

```bash
PORT=8080
REDIS_ADDR=localhost:6379
REDIS_PASSWORD=
TOKEN_SECRET=staging-secret-key-must-be-at-least-32-characters-long-for-security-change-this
ADMIN_API_KEY=staging-admin-api-key-12345-change-this
LOG_LEVEL=info
METRICS_PORT=9090
```

**⚠️ Security Note**: Change the secrets in production!

### 2.2 Configure Firewall

```bash
# Allow HTTP/HTTPS traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp  # For direct access (optional, behind Cloudflare)
sudo ufw enable
```

## Step 3: Deploy Application

### 3.1 Local Deployment Script

```bash
# On your local machine
cd backend

# Set environment variables
export STAGING_HOST=your-staging-server.com
export STAGING_USER=deploy
export STAGING_PORT=22

# Make deploy script executable
chmod +x deploy/staging-deploy.sh

# Run deployment
./deploy/staging-deploy.sh
```

### 3.2 Manual Deployment

```bash
# Build locally
cd backend
go build -o bin/server ./cmd/server

# Copy to server
scp bin/server user@staging-server.com:/opt/gatekeep/bin/
scp .env.staging user@staging-server.com:/opt/gatekeep/

# SSH and start
ssh user@staging-server.com
cd /opt/gatekeep
chmod +x bin/server
./bin/server
```

## Step 4: Setup Systemd Service

### 4.1 Install Service

```bash
# On server
sudo cp /opt/gatekeep/prod_systemd.service /etc/systemd/system/gatekeep.service
sudo systemctl daemon-reload
sudo systemctl enable gatekeep
sudo systemctl start gatekeep
```

### 4.2 Verify Service

```bash
# Check status
sudo systemctl status gatekeep-staging

# View logs
sudo journalctl -u gatekeep-staging -f

# Test endpoint
curl http://localhost:8080/health
```

## Step 5: Configure Cloudflare

### 5.1 Deploy Cloudflare Worker

See [CLOUDFLARE.md](../docs/CLOUDFLARE.md) for detailed instructions.

Quick setup:

```bash
# Install Wrangler
npm install -g wrangler

# Login
wrangler login

# Create worker project (if not exists)
mkdir gatekeep-workers
cd gatekeep-workers
wrangler init

# Configure wrangler.toml
# Set ORIGIN_HOST to your staging server IP or domain
```

### 5.2 Update Worker Configuration

```toml
# wrangler.toml
name = "gatekeep-staging"
main = "src/index.ts"

[env.staging]
vars = { ORIGIN_HOST = "your-staging-server.com:8080" }
```

### 5.3 Deploy Worker

```bash
wrangler deploy --env staging
```

### 5.4 Configure DNS (Optional)

- Point subdomain to Cloudflare Worker
- Or use Workers route for your domain

## Step 6: Run Load Tests

### 6.1 Test Against Staging Server

```bash
# From your local machine
cd backend/k6

# Set staging server URL
export BASE_URL=https://your-staging-worker.workers.dev
# Or direct: export BASE_URL=http://your-staging-server.com:8080

# Run load test
chmod +x run-remote-test.sh
./run-remote-test.sh
```

### 6.2 Test with k6 Directly

```bash
k6 run \
  -e BASE_URL=https://your-staging-worker.workers.dev \
  -e EVENT_ID=staging-test-001 \
  -e ADMIN_API_KEY=staging-admin-api-key-12345 \
  load-test-remote.js
```

## Step 7: Android Emulator Load Test

### 7.1 Prerequisites

- Android SDK installed
- Android emulator AVD created
- Flutter app built

### 7.2 Run Emulator Test

```bash
# From package/example directory
cd package/example

# Configure
export BASE_URL=http://10.0.2.2:8080  # For local staging
# Or use your staging server IP if testing remote
export NUM_EMULATORS=10
export EVENT_ID=android-load-test

# Make script executable
chmod +x android_load_test.sh

# Run test
./android_load_test.sh
```

### 7.3 Customize Emulator Test

```bash
# Use more emulators
NUM_EMULATORS=20 ./android_load_test.sh

# Use different AVD
AVD_NAME=Pixel_6_API_33 ./android_load_test.sh

# Test against remote server (use server's IP)
BASE_URL=http://192.168.1.100:8080 ./android_load_test.sh
```

## Monitoring

### Server Metrics

```bash
# Check service status
sudo systemctl status gatekeep-staging

# View logs
sudo journalctl -u gatekeep-staging -f --lines=100

# Check Redis
redis-cli info stats

# Check system resources
htop
```

### Cloudflare Analytics

- Workers Analytics: Cloudflare Dashboard → Workers → Analytics
- Request volume, error rates, CPU time
- Cache hit ratios

### Application Metrics

```bash
# Prometheus metrics endpoint
curl http://your-staging-server.com:9090/metrics

# Health check
curl http://your-staging-server.com:8080/health
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo journalctl -u gatekeep-staging -n 50

# Check Redis connection
redis-cli ping

# Verify environment variables
sudo cat /opt/gatekeep/.env.staging

# Test manually
sudo -u gatekeep /opt/gatekeep/bin/server
```

### High Error Rates in Load Tests

1. **Check server resources**: `htop`, `free -h`
2. **Check Redis memory**: `redis-cli info memory`
3. **Review server logs**: `sudo journalctl -u gatekeep-staging -f`
4. **Check network**: `netstat -tuln`
5. **Verify Cloudflare Worker**: Check Worker logs in dashboard

### Emulator Issues

1. **Emulator won't start**: Check available memory, increase AVD RAM
2. **App won't install**: Rebuild APK, check package name
3. **Connection refused**: Verify BASE_URL, check firewall rules

## Security Checklist

- [ ] Change default `TOKEN_SECRET` to strong random value
- [ ] Change default `ADMIN_API_KEY` to strong random value
- [ ] Use HTTPS in production (via Cloudflare)
- [ ] Restrict server access (firewall, SSH keys only)
- [ ] Enable Redis password authentication
- [ ] Use systemd service with limited privileges
- [ ] Regular security updates: `sudo apt update && sudo apt upgrade`
- [ ] Monitor logs for suspicious activity

## Next Steps

1. ✅ Deploy to staging
2. ✅ Run k6 load tests
3. ✅ Test with Android emulators
4. ✅ Monitor metrics and performance
5. ✅ Optimize based on results
6. ✅ Prepare for production deployment

## Rollback

If issues occur:

```bash
# Stop service
sudo systemctl stop gatekeep-staging

# Revert to previous version
sudo systemctl start gatekeep-staging@previous

# Or disable service
sudo systemctl disable gatekeep-staging
```

## Support

- Server issues: Check logs, system resources
- Cloudflare issues: Check Worker logs, DNS configuration
- Load test issues: Verify BASE_URL, check network connectivity
