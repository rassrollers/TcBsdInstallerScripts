#!/bin/sh
# Purpose: Modify default Nginx config to custom configuration.
# This example configures Nginx to serve the PLC HMI Web on HTTP and redirect all other requests to HTTPS.

echo "[830-nginx-config] INFO: Updating Nginx configuration to HTTP for PLC HMI Web and HTTPS for TwinCAT 3.1"

# Check if backup exists, if not, create it
if [ ! -f "/usr/local/etc/nginx/IPCDiagnostics.conf.bak" ]; then
    cp "/usr/local/etc/nginx/IPCDiagnostics.conf" "/usr/local/etc/nginx/IPCDiagnostics.conf.bak"
    echo "[830-nginx-config] DEBUG: Backup of IPCDiagnostics.conf created at /usr/local/etc/nginx/IPCDiagnostics.conf.bak"
fi

# Detect the MDP web server socket path from Beckhoff's shipped config, as it differs between TwinCAT/BSD versions
# (older: /tmp/MDPWEB0, newer: /var/run/MDPWebServer/web0)
MDP_SOCKET=$(grep -o 'proxy_pass[[:space:]]*http://unix:[^;]*MDP[^;]*' "/usr/local/etc/nginx/IPCDiagnostics.conf.bak" | head -n 1 | sed 's|.*http://unix:||')
if [ -z "$MDP_SOCKET" ]; then
    MDP_SOCKET="/var/run/MDPWebServer/web0"
    echo "[820-nginx-config] WARN: Could not detect MDP web server socket in IPCDiagnostics.conf.bak, defaulting to $MDP_SOCKET"
else
    echo "[820-nginx-config] INFO: Detected MDP web server socket: $MDP_SOCKET"
fi

# Use a here-document to replace nginx.conf with modified config.
# The here-document is quoted so nginx variables stay literal; only the __MDP_SOCKET__ placeholder is substituted.
sed "s|__MDP_SOCKET__|$MDP_SOCKET|" > "/usr/local/etc/nginx/IPCDiagnostics.conf" <<'EOF'
#user  nobody;
worker_processes  1;

# This default error log path is compiled-in to make sure configuration parsing
# errors are logged somewhere, especially during unattended boot when stderr
# isn't normally logged anywhere. This path will be touched on every nginx
# start regardless of error log location configured here. See
# https://trac.nginx.org/nginx/ticket/147 for more info.
#
#error_log  /var/log/nginx/error.log;
#

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    # Hosting the PLC HMI Web on http and redirecting others to https
    server {
        listen 80;
        listen [::]:80;
        server_name localhost;

        location /Tc3PlcHmiWeb {
            include proxy.conf;
            proxy_pass http://0.0.0.0:42341;
        }

        location / {
            return 301 https://$host$request_uri;
        }
    }

    server {
        listen       443 ssl;
        server_name  localhost;
        ssl_certificate /usr/local/etc/TwinCAT/3.1/Target/Certificates/IPCDiagnostics.crt;
        ssl_certificate_key /usr/local/etc/TwinCAT/3.1/Target/PrivateKeys/IPCDiagnostics.key;
        ssl_protocols TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        include errorpages.conf;
        include authelia.conf;

        location / {
            add_header ServerHostname $hostname;
            root   /usr/local/www/default;
            index  index.html index.htm;
        }

        location /config/ {
            include errorpages.conf;
            include auth.conf;
            include proxy.conf;
            proxy_pass http://unix:__MDP_SOCKET__;
        }

        location /console/ {
            include errorpages.conf;
            include auth.conf;
            include proxy.conf;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_pass "http://127.0.0.1:7681/";
        }

        # Redirecting PLC HMI Web to http
        location /Tc3PlcHmiWeb {
            return 301 http://$host$request_uri;
        }

        location /TcAdsWebService {
            include errorpages.conf;
            include auth.conf;
            include proxy.conf;
            proxy_pass http://unix:/var/run/TcAdsWebService/tcadswebservice.sock;
        }
    }
}
EOF

echo "[830-nginx-config] INFO: Updating Nginx configuration done"
