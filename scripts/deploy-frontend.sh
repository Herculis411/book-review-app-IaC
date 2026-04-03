#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Book Review App — Frontend Bootstrap Script
# Next.js served via Nginx (Web Tier — PUBLIC EC2)
# Ubuntu 22.04 LTS — runs once on first EC2 boot via user_data
#
# Architecture flow:
#   Browser → Public ALB → THIS EC2 → Nginx:80
#     Nginx /api/*  → Internal ALB:3001 → App EC2 (Node.js)
#     Nginx /*      → Next.js:3000 (local)
#
# Terraform templatefile() injects at deploy time:
#   internal_alb_dns — Internal ALB hostname (backend proxy target)
#   public_alb_dns   — Public ALB DNS (NEXT_PUBLIC_API_URL base)
# ═══════════════════════════════════════════════════════════════════

exec > /var/log/book-review-setup.log 2>&1
echo "================================================"
echo " Book Review Frontend Bootstrap Started"
echo " $(date)"
echo "================================================"

# ── 1. System Update ──────────────────────────────────────────────
echo "[1/8] Updating system packages..."
apt update -y && apt upgrade -y
apt install -y curl git nginx unzip software-properties-common
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

# ── 5. Write .env.local ───────────────────────────────────────────
# IMPORTANT: NEXT_PUBLIC_API_URL must be the PUBLIC ALB DNS.
# The browser makes API calls to this URL.
# Nginx on this server intercepts /api/* and proxies to the
# Internal ALB — the browser never directly contacts the backend.
echo "[5/8] Writing .env.local..."

cat > /home/ubuntu/book-review-app/frontend/.env.local << ENVEOF
NEXT_PUBLIC_API_URL=http://${public_alb_dns}
ENVEOF

chown ubuntu:ubuntu /home/ubuntu/book-review-app/frontend/.env.local
chmod 600 /home/ubuntu/book-review-app/frontend/.env.local
echo "  NEXT_PUBLIC_API_URL=http://${public_alb_dns}"

# ── 6. Install Dependencies and Build ─────────────────────────────
echo "[6/8] Building Next.js app..."

sudo -u ubuntu bash << 'BUILDEOF'
  cd /home/ubuntu/book-review-app/frontend
  npm install
  npm run build
BUILDEOF

echo "  Build complete."

# ── 7. Configure Nginx ────────────────────────────────────────────
# KEY: This single Nginx config wires the entire architecture together.
# /api/* goes to the Internal ALB (private VPC — never public).
# /* goes to the Next.js server on port 3000.
echo "[7/8] Configuring Nginx..."

rm -f /etc/nginx/sites-enabled/default

# Write Nginx config — escape $ signs for Nginx variables with backslash
cat > /etc/nginx/sites-available/book-review << NGINXEOF
server {
    listen 80;
    server_name _;

    # Backend API — proxied to Internal ALB then to Node.js App EC2
    # The browser calls /api/books → Nginx forwards to backend
    location /api/ {
        proxy_pass         http://${internal_alb_dns}:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_read_timeout    30s;
        proxy_send_timeout    30s;
    }

    # Next.js frontend — all other traffic
    location / {
        proxy_pass         http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade           \$http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout 60s;
        proxy_read_timeout    60s;
    }

    # Health check for ALB target group
    location /health {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/book-review \
       /etc/nginx/sites-enabled/book-review

nginx -t
systemctl enable nginx
systemctl restart nginx
echo "  Nginx: /api/* → ${internal_alb_dns}:3001 | /* → localhost:3000"

# ── 8. Start Next.js with PM2 ─────────────────────────────────────
echo "[8/8] Starting Next.js with PM2..."

sudo -u ubuntu bash << 'PM2EOF'
  cd /home/ubuntu/book-review-app/frontend
  pm2 delete book-review-frontend 2>/dev/null || true
  pm2 start npm \
    --name "book-review-frontend" \
    --time \
    -- start
  pm2 save
PM2EOF

env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu
systemctl enable pm2-ubuntu
echo "  PM2 started."

# ── Final Health Check ────────────────────────────────────────────
echo "Waiting 25s for Next.js..."
sleep 25

NEXT_CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:3000 || echo "000")
echo "  Next.js (port 3000): HTTP $NEXT_CODE"

NGINX_CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:80 || echo "000")
echo "  Nginx  (port 80):    HTTP $NGINX_CODE"

echo ""
echo "================================================"
echo " Frontend Bootstrap Complete: $(date)"
echo "------------------------------------------------"
echo " App URL:      http://${public_alb_dns}"
echo " API via Nginx: http://${public_alb_dns}/api/books"
echo "------------------------------------------------"
echo " Debug:"
echo "   pm2 status"
echo "   pm2 logs book-review-frontend"
echo "   curl http://localhost/api/books"
echo "   sudo systemctl status nginx"
echo "   tail -f /var/log/book-review-setup.log"
echo "================================================"
