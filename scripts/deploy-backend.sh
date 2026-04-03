#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Book Review App — Backend Bootstrap Script
# Node.js + Express API (App Tier — PRIVATE EC2)
# Ubuntu 22.04 LTS — runs once on first EC2 boot via user_data
#
# Architecture:
#   Internal ALB:3001 → THIS EC2 → Node.js:3001 → RDS MySQL
#
# Terraform templatefile() injects at deploy time:
#   db_host         — RDS primary endpoint hostname
#   db_name         — MySQL database name
#   db_user         — MySQL admin username
#   db_password     — MySQL admin password
#   jwt_secret      — JWT signing secret
#   allowed_origins — CORS origins (Public ALB DNS)
# ═══════════════════════════════════════════════════════════════════

exec > /var/log/book-review-setup.log 2>&1
echo "================================================"
echo " Book Review Backend Bootstrap Started"
echo " $(date)"
echo "================================================"

# ── 1. System Update ──────────────────────────────────────────────
echo "[1/8] Updating system packages..."
apt update -y && apt upgrade -y
apt install -y curl git mysql-client unzip software-properties-common
echo "  System update complete."

# ── 2. Install Node.js 18 LTS ─────────────────────────────────────
echo "[2/8] Installing Node.js 18 LTS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
echo "  Node.js: $(node -v)  npm: $(npm -v)"

# ── 3. Install PM2 ────────────────────────────────────────────────
echo "[3/8] Installing PM2..."
npm install -g pm2
echo "  PM2: $(pm2 --version)"

# ── 4. Clone Repository ───────────────────────────────────────────
echo "[4/8] Cloning repository..."
cd /home/ubuntu
if [ ! -d "book-review-app" ]; then
  git clone https://github.com/pravinmishraaws/book-review-app.git
fi
chown -R ubuntu:ubuntu /home/ubuntu/book-review-app
echo "  Repository cloned."

# ── 5. Install Backend Dependencies ───────────────────────────────
echo "[5/8] Installing npm dependencies..."
cd /home/ubuntu/book-review-app/backend
sudo -u ubuntu npm install
echo "  npm install complete."

# ── 6. Write .env ─────────────────────────────────────────────────
# All $${...} values are injected by Terraform templatefile()
echo "[6/8] Writing backend .env..."

cat > /home/ubuntu/book-review-app/backend/.env << ENVEOF
# Database — injected by Terraform from RDS module outputs
DB_HOST=${db_host}
DB_USER=${db_user}
DB_PASS=${db_password}
DB_NAME=${db_name}
DB_DIALECT=mysql

# JWT
JWT_SECRET=${jwt_secret}

# CORS — allow requests from the public ALB (browser origin)
ALLOWED_ORIGINS=${allowed_origins}

# Server
NODE_ENV=production
PORT=3001
ENVEOF

chown ubuntu:ubuntu /home/ubuntu/book-review-app/backend/.env
chmod 600 /home/ubuntu/book-review-app/backend/.env
echo "  .env written."
echo "  DB_HOST=${db_host}"
echo "  ALLOWED_ORIGINS=${allowed_origins}"

# ── 7. Wait for RDS and Create Database ───────────────────────────
echo "[7/8] Waiting for RDS MySQL..."
MAX_RETRIES=40
RETRY_COUNT=0

until mysql \
  -h "${db_host}" \
  -u "${db_user}" \
  -p"${db_password}" \
  -e "SELECT 1;" > /dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "ERROR: RDS not reachable after $MAX_RETRIES attempts. Exiting."
    exit 1
  fi
  echo "  Attempt $RETRY_COUNT/$MAX_RETRIES — retrying in 15s..."
  sleep 15
done
echo "  RDS is ready."

# Create database if it does not exist
mysql \
  -h "${db_host}" \
  -u "${db_user}" \
  -p"${db_password}" \
  -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
echo "  Database '${db_name}' ready."

# ── 8. Start Backend with PM2 ─────────────────────────────────────
# The backend uses Sequelize which auto-creates tables and seeds data
# on first run — no manual SQL import needed
echo "[8/8] Starting backend with PM2..."

sudo -u ubuntu bash << 'PM2EOF'
  cd /home/ubuntu/book-review-app/backend
  pm2 delete book-review-backend 2>/dev/null || true
  pm2 start src/server.js \
    --name "book-review-backend" \
    --time
  pm2 save
PM2EOF

env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu
systemctl enable pm2-ubuntu
echo "  PM2 started."

# ── Health Check ──────────────────────────────────────────────────
echo "Waiting 15s for server to start..."
sleep 15

HTTP_CODE=$(curl -s -o /dev/null -w "%%{http_code}" \
  http://localhost:3001/api/books || echo "000")

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "  Backend health check: PASSED (HTTP 200)"
else
  echo "  WARNING: /api/books returned HTTP $HTTP_CODE"
  echo "  Check: pm2 logs book-review-backend"
fi

echo ""
echo "================================================"
echo " Backend Bootstrap Complete: $(date)"
echo "------------------------------------------------"
echo " API listening on port 3001"
echo " DB host: ${db_host}"
echo "------------------------------------------------"
echo " Expected Sequelize startup output:"
echo "   Server running on port 3001"
echo "   Database schema updated successfully"
echo "   Sample books added"
echo "   Sample users added"
echo "   Sample reviews added"
echo "------------------------------------------------"
echo " Debug:"
echo "   pm2 status"
echo "   pm2 logs book-review-backend"
echo "   curl http://localhost:3001/api/books"
echo "   tail -f /var/log/book-review-setup.log"
echo "================================================"
