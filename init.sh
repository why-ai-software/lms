#!/bin/bash
set -e

cd /home/frappe

echo "Waiting for MariaDB..."
until python -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('mariadb', 3306)); s.close()" 2>/dev/null; do
  sleep 2
done

echo "Waiting for Redis..."
until python -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('redis', 6379)); s.close()" 2>/dev/null; do
  sleep 2
done

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, skipping init"
    cd /home/frappe/frappe-bench
    exec bench start
fi

echo "Creating new bench..."

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

bench init --skip-redis-config-generation frappe-bench

cd /home/frappe/frappe-bench

bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

bench get-app payments
bench get-app lms

bench new-site lms.localhost \
  --force \
  --mariadb-root-password 123 \
  --admin-password admin \
  --no-mariadb-socket

bench --site lms.localhost install-app payments
bench --site lms.localhost install-app lms
bench --site lms.localhost set-config developer_mode 1
bench --site lms.localhost clear-cache
bench use lms.localhost

exec bench start