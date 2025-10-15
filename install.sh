#!/bin/bash

# Input domain, bot token, admin ID sebelum install
read -p "Masukkan domain Anda (contoh: jakarta.parael.me): " DOMAIN
read -p "Masukkan Telegram Bot Token: " BOT_TOKEN
read -p "Masukkan Telegram Admin ID: " ADMIN_ID

CONFIG_FILE="/etc/auto-xray-config.conf"
echo "DOMAIN=$DOMAIN" > $CONFIG_FILE
echo "BOT_TOKEN=$BOT_TOKEN" >> $CONFIG_FILE
echo "ADMIN_ID=$ADMIN_ID" >> $CONFIG_FILE

source $CONFIG_FILE

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
XRAY_CONF="/usr/local/etc/xray/config.json"
ACME_SH="$HOME/.acme.sh/acme.sh"
XRAY_SERVICE="xray"

if [[ $EUID -ne 0 ]]; then
   echo "Jalankan script sebagai root!"
   exit 1
fi

install_dependencies() {
  apt update && apt upgrade -y
  apt install -y nginx curl unzip vnstat speedtest-cli
}

install_acme() {
  if ! command -v acme.sh &> /dev/null; then
    curl https://get.acme.sh | sh
    source ~/.bashrc
  fi
}

issue_cert() {
  $ACME_SH --issue -d "$DOMAIN" --standalone --force
  $ACME_SH --install-cert -d "$DOMAIN" \
    --key-file /etc/letsencrypt/live/$DOMAIN/privkey.pem \
    --fullchain-file /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
    --reloadcmd "systemctl reload nginx"
}

install_xray() {
  bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install
}

config_xray_nginx() {
  for i in {1..4}; do
    UUIDS[i]=$(uuidgen)
  done

  cat > $XRAY_CONF <<EOF
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    {
      "port": 80,
      "protocol": "http",
      "settings": {},
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/ssh" }
      },
      "tag": "ssh-nontls"
    },
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "${UUIDS[1]}", "alterId": 0 }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": { "allowInsecure": false, "serverName": "$DOMAIN" },
        "wsSettings": { "path": "/vmess" }
      },
      "tag": "vmess-tls"
    },
    {
      "port": 80,
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "${UUIDS[2]}", "alterId": 0 }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vmess" }
      },
      "tag": "vmess-nontls"
    },
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${UUIDS[3]}" }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": { "allowInsecure": false, "serverName": "$DOMAIN" },
        "wsSettings": { "path": "/vless" }
      },
      "tag": "vless-tls"
    },
    {
      "port": 80,
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${UUIDS[4]}" }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vless" }
      },
      "tag": "vless-nontls"
    },
    {
      "port": 443,
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "trojanpass" }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": { "allowInsecure": false, "serverName": "$DOMAIN" },
        "wsSettings": { "path": "/trojan" }
      },
      "tag": "trojan-tls"
    },
    {
      "port": 80,
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "trojanpass" }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/trojan" }
      },
      "tag": "trojan-nontls"
    },
    {
      "port": 80,
      "protocol": "http",
      "settings": {},
      "tag": "noobzvpn-nontls"
    },
    {
      "port": 443,
      "protocol": "http",
      "settings": {},
      "streamSettings": {
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": false,
          "alpn": ["http/1.1"],
          "serverName": "$DOMAIN"
        }
      },
      "tag": "noobzvpn-tls"
    }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": {} } ]
}
EOF

  cat > $NGINX_CONF <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /ssh {
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    location /vmess {
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    location /vless {
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    location /trojan {
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    location /noobzvpn {
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location /ssh {
        proxy_pass http://127.0.0.1:443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    location /vmess {
        proxy_pass http://127.0.0.1:443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    location /vless {
        proxy_pass http://127.0.0.1:443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    location /trojan {
        proxy_pass http://127.0.0.1:443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    location /noobzvpn {
        proxy_pass http://127.0.0.1:443;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

  ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
  nginx -t && systemctl reload nginx
  systemctl restart $XRAY_SERVICE
}

read_expiry_date() {
  while true; do
    read -p "Masukkan masa aktif (hari): " EXP_DAY
    if [[ "$EXP_DAY" =~ ^[0-9]+$ ]]; then
      EXP_DATE=$(date -d "+$EXP_DAY day" +"%b %d, %Y")
      break
    else
      echo "Input angka valid!"
    fi
  done
}

create_sshws_user() {
  read -p "Masukkan username SSH WS: " USER
  read -sp "Masukkan password: " PASS
  echo
  read_expiry_date
  useradd -M -s /bin/false $USER 2>/dev/null
  echo "$USER:$PASS" | chpasswd

  cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━
            SSH ACCOUNT
━━━━━━━━━━━━━━━━━━━━━━━
Username : $USER
Password : $PASS
━━━━━━━━━━━━━━━━━━━━━━━
Host : $DOMAIN
OpenSSH : 22
Dropbear : 109, 143
SSH-WS : 80
SSH-SSL-WS : 443
SSL/TLS : 447, 777
UDPGW : 7100-7300
━━━━━━━━━━━━━━━━━━━━━━━
Link SSH Config : http://$DOMAIN:81/ssh-$USER.txt
━━━━━━━━━━━━━━━━━━━━━━━
Payload WS
GET / [crlf]Host: $DOMAIN[crlf]Connection: Keep-Alive[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]
━━━━━━━━━━━━━━━━━━━━━━━
GET wss://bug.com/ [crlf]Host: $DOMAIN[crlf]Connection: Keep-Alive[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]
━━━━━━━━━━━━━━━━━━━━━━━
Expired On : $EXP_DATE
━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

create_vmess_user() {
  read -p "Masukkan remarks VMess: " REMARKS
  read_expiry_date
  UUID=$(uuidgen)

  LINK_TLS="vmess://$(echo -n "{"v":"2","ps":"$REMARKS-TLS","add":"$DOMAIN","port":"443","id":"$UUID","aid":"0","net":"ws","type":"none","host":"$DOMAIN","path":"/vmess","tls":"tls"}" | base64 -w 0)"
  LINK_NONE_TLS="vmess://$(echo -n "{"v":"2","ps":"$REMARKS-NonTLS","add":"$DOMAIN","port":"80","id":"$UUID","aid":"0","net":"ws","type":"none","host":"$DOMAIN","path":"/vmess","tls":""}" | base64 -w 0)"
  LINK_GRPC="vmess://$(echo -n "{"v":"2","ps":"$REMARKS-GRPC","add":"$DOMAIN","port":"443","id":"$UUID","aid":"0","net":"grpc","type":"none","host":"$DOMAIN","path":"vmess-grpc","tls":"tls","serviceName":"vmess-grpc"}" | base64 -w 0)"

  cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━
             VMESS ACCOUNT
━━━━━━━━━━━━━━━━━━━━━━━
Remarks   : $REMARKS
Domain    : $DOMAIN
Port TLS  : 443
Port NonTLS : 80
Port GRPC : 443
ID        : $UUID
AlterId   : 0
Security  : auto
Network   : ws/grpc
Path      : /vmess
ServiceName: vmess-grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link TLS      : $LINK_TLS
Link Non TLS  : $LINK_NONE_TLS
Link GRPC     : $LINK_GRPC
━━━━━━━━━━━━━━━━━━━━━━━
Expired On   : $EXP_DATE
━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

create_vless_user() {
  read -p "Masukkan remarks VLESS: " REMARKS
  read_expiry_date
  UUID=$(uuidgen)

  LINK_TLS="vless://${UUID}@${DOMAIN}:443?type=ws&security=tls&host=${DOMAIN}&path=/vless&sni=${DOMAIN}#$REMARKS-TLS"
  LINK_NONE_TLS="vless://${UUID}@${DOMAIN}:80?type=ws&security=none&host=${DOMAIN}&path=/vless#$REMARKS-NonTLS"
  LINK_GRPC="vless://${UUID}@${DOMAIN}:443?mode=gun&security=tls&type=grpc&serviceName=vless-grpc&sni=${DOMAIN}#$REMARKS-GRPC"

  cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━
             VLESS ACCOUNT
━━━━━━━━━━━━━━━━━━━━━━━
Remarks         : $REMARKS
Domain          : $DOMAIN
Port TLS        : 443
Port Non TLS    : 80
Port GRPC       : 443
ID              : $UUID
Encryption      : none
Network         : ws/grpc
Path            : /vless
ServiceName     : vless-grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link TLS        : $LINK_TLS
Link Non TLS    : $LINK_NONE_TLS
Link GRPC       : $LINK_GRPC
━━━━━━━━━━━━━━━━━━━━━━━
Expired On     : $EXP_DATE
━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

create_trojan_user() {
  read -p "Masukkan remarks Trojan: " REMARKS
  read_expiry_date
  PASSWORD=$(uuidgen)

  LINK_WS="trojan://${PASSWORD}@${DOMAIN}:443?path=%2Ftrojan&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#$REMARKS-WS"
  LINK_GRPC="trojan://${PASSWORD}@${DOMAIN}:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${DOMAIN}#$REMARKS-GRPC"

  cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━
            TROJAN ACCOUNT
━━━━━━━━━━━━━━━━━━━━━━━
Remarks     : $REMARKS
Host/IP     : $DOMAIN
Port        : 443
Password    : $PASSWORD
Network     : ws/grpc
Path        : /trojan
ServiceName : trojan-grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link WS     : $LINK_WS
Link GRPC   : $LINK_GRPC
━━━━━━━━━━━━━━━━━━━━━━━
Expired On : $EXP_DATE
━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

create_noobzvpn_user() {
  read -p "Masukkan username NoobzVPN: " USER
  read -sp "Masukkan password NoobzVPN: " PASS
  echo
  read_expiry_date

  cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━
           NOOBZVPN ACCOUNT
━━━━━━━━━━━━━━━━━━━━━━━
Username    : $USER
Password    : $PASS
Domain      : $DOMAIN
Port TLS    : 443
Port NonTLS : 80
Port GRPC   : 443
Network     : ws/grpc
Path       : /noobzvpn
ServiceName : noobzvpn-grpc
━━━━━━━━━━━━━━━━━━━━━━━
Autentikasi menggunakan username dan password seperti SSH
Gunakan aplikasi NoobzVPN dengan konfigurasi ini.
━━━━━━━━━━━━━━━━━━━━━━━
Link Config (contoh): http://$DOMAIN:81/noobzvpn-$USER.txt
━━━━━━━━━━━━━━━━━━━━━━━
Expired On  : $EXP_DATE
━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

show_menu() {
  clear
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "    AUTO SCRIPT LIFETIME BY PARAEL"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Domain: $DOMAIN"
  echo "Bot Token: $BOT_TOKEN"
  echo "Admin ID: $ADMIN_ID"
  echo ""
  echo "1) Create SSH WS User"
  echo "2) Create VMess User"
  echo "3) Create VLESS User"
  echo "4) Create Trojan User"
  echo "5) Create NoobzVPN User"
  echo "6) Exit"
  read -p "Pilih menu: " opt
  case $opt in
    1) create_sshws_user; read -p "ENTER to back" _; show_menu ;;
    2) create_vmess_user; read -p "ENTER to back" _; show_menu ;;
    3) create_vless_user; read -p "ENTER to back" _; show_menu ;;
    4) create_trojan_user; read -p "ENTER to back" _; show_menu ;;
    5) create_noobzvpn_user; read -p "ENTER to back" _; show_menu ;;
    6) exit 0 ;;
    *) show_menu ;;
  esac
}

# Main Run
install_dependencies
install_acme
issue_cert
install_xray
config_xray_nginx
show_menu
