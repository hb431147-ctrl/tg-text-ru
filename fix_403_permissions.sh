#!/bin/bash
# Run once on server as root to fix 403: ssh root@45.153.70.209 'bash -s' < fix_403_permissions.sh
# Or copy to server and run: chmod +x fix_403_permissions.sh; sudo ./fix_403_permissions.sh

set -e
WWW_ROOT="/var/www/tg-text.ru"
DEPLOY_DIR="${WWW_ROOT}/public_html"
NGINX_USER="www-data"

echo "Fix 403: setting permissions for nginx (${NGINX_USER})..."

# Parent dirs: nginx must be able to traverse
chmod o+rx /var/www
chmod o+rx "${WWW_ROOT}"
mkdir -p "${DEPLOY_DIR}"
mkdir -p "${WWW_ROOT}/logs"
chmod 755 "${WWW_ROOT}/logs"

# If public_html is empty, create minimal index so site at least loads
if [ ! -f "${DEPLOY_DIR}/index.html" ]; then
  echo "WARNING: index.html missing, creating placeholder. Run deploy again to build React."
  echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>tg-text.ru</title></head><body><p>Deploy in progress. Run deploy.ps1 again.</p></body></html>' > "${DEPLOY_DIR}/index.html"
fi

# Ownership and permissions
chown -R ${NGINX_USER}:${NGINX_USER} "${DEPLOY_DIR}"
find "${DEPLOY_DIR}" -type d -exec chmod 755 {} \;
find "${DEPLOY_DIR}" -type f -exec chmod 644 {} \;

# Test: can nginx user read?
if sudo -u ${NGINX_USER} test -r "${DEPLOY_DIR}/index.html"; then
  echo "OK: ${NGINX_USER} can read index.html"
else
  echo "FAIL: ${NGINX_USER} cannot read index.html"
  exit 1
fi

echo "Reloading nginx..."
nginx -t && systemctl reload nginx
echo "Done. Open https://tg-text.ru"
