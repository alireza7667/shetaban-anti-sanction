#!/bin/bash

# به روز رسانی و نصب sniproxy
echo "Updating system and installing sniproxy..."
sudo apt update -y
sudo apt install sniproxy -y

# ویرایش فایل پیکربندی sniproxy
echo "Configuring sniproxy..."
sudo bash -c 'cat > /etc/sniproxy.conf <<EOF
# sniproxy example configuration file
# lines that start with # are comments
# lines with only white space are ignored

user daemon

# PID file
pidfile /var/run/sniproxy.pid

error_log {
    syslog daemon
    priority notice
}

table http_hosts {
    api.openai.com api.openai.com:80
    embargo.splunk.com embargo.splunk.com:80
    golang.org golang.org:80
    computerworld.com computerworld.com:80
    mirrors.fedoraproject.org mirrors.fedoraproject.org:80
    nvidia.com nvidia.com:80
    repo.imunify360.cloudlinux.com repo.imunify360.cloudlinux.com:80
    dl.fedoraproject.org dl.fedoraproject.org:80
    mirrors.fedoraproject.org mirrors.fedoraproject.org:80
    mirrormanager.fedoraproject.org mirrormanager.fedoraproject.org:80
}

table https_hosts {
    api.openai.com api.openai.com:443
    embargo.splunk.com embargo.splunk.com:443
    golang.org golang.org:443
    computerworld.com computerworld.com:443
    mirrors.fedoraproject.org mirrors.fedoraproject.org:443
    nvidia.com nvidia.com:443
    repo.imunify360.cloudlinux.com repo.imunify360.cloudlinux.com:443
    dl.fedoraproject.org dl.fedoraproject.org:443
    mirrors.fedoraproject.org mirrors.fedoraproject.org:443
    mirrormanager.fedoraproject.org mirrormanager.fedoraproject.org:443
}

listen 80 {
    proto http
    table http_hosts
    fallback localhost:8080
    access_log {
        filename /var/log/sniproxy/http_access.log
        priority notice
    }
}

listen 443 {
    proto tls
    table https_hosts
    access_log {
        filename /var/log/sniproxy/https_access.log
        priority notice
    }
}

table {
    example.com 192.0.2.10
    example.net 192.0.2.20
}
EOF'

# راه‌اندازی sniproxy
echo "Starting and enabling sniproxy..."
sudo systemctl start sniproxy
sudo systemctl enable sniproxy

# ویرایش فایل پیکربندی systemd برای sniproxy
echo "Configuring sniproxy service..."
sudo bash -c 'cat > /lib/systemd/system/sniproxy.service <<EOF
[Unit]
Description=HTTPS SNI Proxy
Documentation=man:sniproxy(8) file:///usr/share/doc/sniproxy/

[Service]
Type=forking
EnvironmentFile=-/etc/default/sniproxy
ExecStart=/usr/sbin/sniproxy
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process

[Install]
WantedBy=multi-user.target
EOF'

# ری‌لود کردن systemd و ری‌استارت sniproxy
echo "Reloading systemd and restarting sniproxy..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart sniproxy

# بررسی وضعیت sniproxy
echo "Checking sniproxy status..."
sudo systemctl status sniproxy

# نصب HAProxy
echo "Installing HAProxy..."
sudo apt install haproxy -y

# تولید گواهی SSL با OpenSSL
echo "Generating SSL certificate..."
sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/private/my_domain.key -out /etc/ssl/certs/my_domain.crt -days 365 -nodes

# ویرایش پیکربندی HAProxy
echo "Configuring HAProxy..."
sudo bash -c 'cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend https_in
    bind *:8443
    mode tcp
    default_backend sniproxy_https

frontend http_in
    bind *:8080
    mode tcp
    default_backend sniproxy_http

backend sniproxy_https
    mode tcp
    server sniproxy 127.0.0.1:443

backend sniproxy_http
    mode tcp
    server sniproxy 127.0.0.1:80
EOF'

# ری‌استارت HAProxy و sniproxy
echo "Restarting HAProxy and sniproxy..."
sudo systemctl restart haproxy
sudo systemctl restart sniproxy

# بررسی وضعیت HAProxy و sniproxy
echo "Checking HAProxy and sniproxy status..."
sudo systemctl status haproxy
sudo systemctl status sniproxy
