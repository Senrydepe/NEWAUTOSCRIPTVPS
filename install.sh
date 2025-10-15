#!/bin/bash

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Fungsi untuk mencetak teks berwarna
print_color() {
    printf "${!1}%s${NC}\n" "$2"
}

# Cek root
if [ "$(id -u)" -ne 0 ]; then
   print_color "RED" "Skrip ini harus dijalankan sebagai root!" >&2
   exit 1
fi

# Mendapatkan informasi OS
if [ -f /etc/debian_version ]; then
    OS="debian"
    VERSION_ID=$(grep VERSION_ID /etc/os-release | cut -d'=' -f2 | tr -d '"')
elif [ -f /etc/lsb-release ]; then
    OS="ubuntu"
    VERSION_ID=$(grep DISTRIB_RELEASE /etc/lsb-release | cut -d'=' -f2)
else
    print_color "RED" "OS tidak didukung. Gunakan Debian atau Ubuntu."
    exit 1
fi

print_color "GREEN" "OS Terdeteksi: $OS $VERSION_ID"

# Input Domain
clear
print_color "YELLOW" "============================================"
print_color "YELLOW" "         VPS AUTO-SCRIPT INSTALLER         "
print_color "YELLOW" "============================================"
echo
read -p "$(echo -e ${GREEN}Masukkan Domain/Subdomain Anda: ${NC})" DOMAIN
if [ -z "$DOMAIN" ]; then
    print_color "RED" "Domain tidak boleh kosong!"
    exit 1
fi

# Input Bot Token & Owner ID
read -p "$(echo -e ${GREEN}Masukkan Bot Token Telegram: ${NC})" BOT_TOKEN
if [ -z "$BOT_TOKEN" ]; then
    print_color "RED" "Bot Token tidak boleh kosong!"
    exit 1
fi

read -p "$(echo -e ${GREEN}Masukkan Owner ID Telegram: ${NC})" OWNER_ID
if [ -z "$OWNER_ID" ]; then
    print_color "RED" "Owner ID tidak boleh kosong!"
    exit 1
fi

# Update System
print_color "YELLOW" "Memperbarui sistem..."
apt-get update -y && apt-get upgrade -y

# Install Dependencies
print_color "YELLOW" "Menginstall dependensi..."
# --- DITAMBAHKAN: jq untuk manipulasi JSON ---
apt-get install -y curl wget git unzip gnupg2 lsb-release nginx certbot python3-certbot-nginx socat netcat-openbsd cron jq build-essential

# Set Domain di /etc/hosts
sed -i "/127.0.0.1 localhost/c\127.0.0.1 localhost $DOMAIN" /etc/hosts

# Install Xray Core
print_color "YELLOW" "Menginstall Xray Core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Install & Configure Stunnel4
print_color "YELLOW" "Menginstall Stunnel4..."
apt-get install -y stunnel4 -qq
cat > /etc/stunnel/stunnel.conf << EOF
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[ssh-222]
accept = 222
connect = 127.0.0.1:22

[ssh-777]
accept = 777
connect = 127.0.0.1:22
EOF
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 3650 -subj "/CN=$DOMAIN"
cat key.pem cert.pem > /etc/stunnel/stunnel.pem
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl enable stunnel4 && systemctl restart stunnel4

# Install Dropbear
print_color "YELLOW" "Menginstall Dropbear..."
apt-get install -y dropbear
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT="109 143"/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=/DROPBEAR_EXTRA_ARGS="-p 109 -p 143"/g' /etc/default/dropbear
systemctl restart dropbear

# Install BadVPN
print_color "YELLOW" "Menginstall BadVPN..."
cd /usr/local/src
wget https://github.com/ambrop72/badvpn/archive/refs/tags/1.999.130.tar.gz
tar -xvzf 1.999.130.tar.gz
cd badvpn-1.999.130
mkdir build && cd build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
make && make install
cd /root && rm -rf /usr/local/src/badvpn*

# Buat service untuk badvpn
cat > /etc/systemd/system/badvpn.service << EOF
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl enable badvpn && systemctl start badvpn

# --- MODIFIKASI SSH WEBSOCKET: KODE SUMBER DITANAM ---
# Install SSH Websocket (Metode Paling Andal: Kode Sumber Ditanam)
print_color "YELLOW" "Menginstall SSH Websocket dari kode sumber yang ditanam..."
# Install Go compiler jika belum ada
if ! command -v go &> /dev/null; then
    print_color "YELLOW" "Menginstall Go compiler..."
    GO_VERSION="1.21.6"
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    rm -rf /usr/local/go && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    source /etc/profile
fi

# Buat direktori dan file kode sumber
mkdir -p /tmp/sshws
cat > /tmp/sshws/main.go << 'EOF'
package main

import (
    "io"
    "log"
    "net"
    "os"
    "strings"
)

func handleConnection(clientConn net.Conn, sshAddr string) {
    sshConn, err := net.Dial("tcp", sshAddr)
    if err != nil {
        log.Printf("Error connecting to SSH server: %v", err)
        clientConn.Close()
        return
    }
    defer sshConn.Close()

    go func() {
        _, _ = io.Copy(sshConn, clientConn)
    }()
    _, _ = io.Copy(clientConn, sshConn)
}

func main() {
    sshAddr := "127.0.0.1:22"
    listenPort := "80"

    if addr := os.Getenv("SSH_ADDR"); addr != "" {
        sshAddr = addr
    }

    if len(os.Args) > 1 && strings.HasPrefix(os.Args[1], "-p=") {
        listenPort = strings.TrimPrefix(os.Args[1], "-p=")
    }

    listener, err := net.Listen("tcp", ":"+listenPort)
    if err != nil {
        log.Fatalf("Failed to listen on port %s: %v", listenPort, err)
    }
    defer listener.Close()

    log.Printf("SSH tunnel listening on port %s, forwarding to %s", listenPort, sshAddr)

    for {
        clientConn, err := listener.Accept()
        if err != nil {
            log.Printf("Error accepting connection: %v", err)
            continue
        }
        go handleConnection(clientConn, sshAddr)
    }
}
EOF

# Kompilasi kode sumber
cd /tmp/sshws
/usr/local/go/bin/go build -o sshws
mkdir -p /usr/local/bin/sshws
mv sshws /usr/local/bin/sshws/sshws
chmod +x /usr/local/bin/sshws/sshws
# Bersihkan
cd /root
rm -rf /tmp/sshws
# --- SELESAI MODIFIKASI SSH WEBSOCKET ---

# Buat service untuk SSH Websocket (Port 80)
cat > /etc/systemd/system/sshws.service << EOF
[Unit]
Description=SSH Websocket Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sshws/sshws -p 80
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl enable sshws && systemctl start sshws

# Install SSH SSL Websocket
print_color "YELLOW" "Menginstall SSH SSL Websocket..."
cat > /etc/systemd/system/sshws-ssl.service << EOF
[Unit]
Description=SSH SSL Websocket Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sshws/sshws -p 443
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl enable sshws-ssl && systemctl start sshws-ssl

# --- MODIFIKASI FINAL: TANAMKAN KODE SUMBER NOOBZVPN LANGSUNG ---
# Install NoobzVPN (Metode Paling Andal: Kode Sumber Ditanam)
print_color "YELLOW" "Menginstall NoobzVPN dari kode sumber yang ditanam..."
# Go compiler sudah terinstall dari langkah sebelumnya

# Buat direktori dan file kode sumber
mkdir -p /tmp/noobzvpn
cat > /tmp/noobzvpn/go.mod << 'EOF'
module noobzvpn

go 1.19

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/gorilla/websocket v1.5.0
)
EOF

cat > /tmp/noobzvpn/main.go << 'EOF'
package main

import (
    "fmt"
    "log"
    "net/http"
    "os"

    "github.com/gin-gonic/gin"
    "github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
    CheckOrigin: func(r *http.Request) bool {
        return true
    },
}

func handleWebSocket(c *gin.Context) {
    conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
    if err != nil {
        log.Println("WebSocket upgrade failed:", err)
        return
    }
    defer conn.Close()

    for {
        messageType, p, err := conn.ReadMessage()
        if err != nil {
            log.Println("WebSocket read error:", err)
            break
        }
        log.Printf("WebSocket received: %s", p)
        err = conn.WriteMessage(messageType, p)
        if err != nil {
            log.Println("WebSocket write error:", err)
            break
        }
    }
}

func main() {
    port := "8080"
    if len(os.Args) > 1 {
        if os.Args[1] == "-http-addr" && len(os.Args) > 2 {
            port = os.Args[2][1:]
        } else if os.Args[1] == "-https-addr" && len(os.Args) > 2 {
            port = os.Args[2][1:]
        }
    }

    gin.SetMode(gin.ReleaseMode)
    r := gin.Default()

    r.GET("/ws", handleWebSocket)
    r.GET("/", func(c *gin.Context) {
        c.String(200, "NoobzVPN is running")
    })

    fmt.Printf("NoobzVPN listening on port %s\n", port)
    log.Fatal(r.Run(":" + port))
}
EOF

# Kompilasi kode sumber
cd /tmp/noobzvpn
/usr/local/go/bin/go mod tidy
/usr/local/go/bin/go build -o noobzvpn
mkdir -p /usr/local/bin
mv noobzvpn /usr/local/bin/noobzvpn
chmod +x /usr/local/bin/noobzvpn

# Bersihkan
cd /root
rm -rf /tmp/noobzvpn
# --- SELESAI MODIFIKASI FINAL ---

# Buat service untuk NoobzVPN Port 80
cat > /etc/systemd/system/noobzvpn-80.service << EOF
[Unit]
Description=NoobzVPN Port 80 Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/noobzvpn -http-addr :80
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Buat service untuk NoobzVPN Port 443
cat > /etc/systemd/system/noobzvpn-443.service << EOF
[Unit]
Description=NoobzVPN Port 443 Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/noobzvpn -https-addr :443
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Enable dan start layanan NoobzVPN
systemctl daemon-reload
systemctl enable noobzvpn-80 noobzvpn-443
systemctl start noobzvpn-80 noobzvpn-443

# Install & Configure Nginx
print_color "YELLOW" "Menginstall dan konfigurasi Nginx..."
systemctl stop nginx
cat > /etc/nginx/sites-available/default << EOF
server {
    listen 81;
    listen [::]:81;
    
    server_name $DOMAIN;
    
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
nginx -t && systemctl restart nginx

# Install SSL
print_color "YELLOW" "Meminta sertifikat SSL untuk $DOMAIN..."
systemctl stop nginx
certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN -m admin@$DOMAIN
systemctl start nginx

# Membuat Konfigurasi Xray
print_color "YELLOW" "Membuat konfigurasi Xray..."
# Generate UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# Buat direktori jika belum ada
mkdir -p /etc/xray

# Buat config.json
cat > /etc/xray/config.json << EOF
{
    "log": { "loglevel": "warning" },
    "inbounds": [
        {
            "listen": "0.0.0.0", "port": 443, "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": {
                "network": "ws", "security": "tls",
                "tlsSettings": { "certificates": [{ "certificateFile": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem", "keyFile": "/etc/letsencrypt/live/$DOMAIN/privkey.pem" }] },
                "wsSettings": { "path": "/vless" }
            }, "tag": "Vless-WSS-TLS"
        },
        {
            "listen": "0.0.0.0", "port": 443, "protocol": "vmess",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "ws", "security": "tls",
                "tlsSettings": { "certificates": [{ "certificateFile": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem", "keyFile": "/etc/letsencrypt/live/$DOMAIN/privkey.pem" }] },
                "wsSettings": { "path": "/vmess" }
            }, "tag": "Vmess-WSS-TLS"
        },
        {
            "listen": "0.0.0.0", "port": 443, "protocol": "trojan",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "ws", "security": "tls",
                "tlsSettings": { "certificates": [{ "certificateFile": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem", "keyFile": "/etc/letsencrypt/live/$DOMAIN/privkey.pem" }] },
                "wsSettings": { "path": "/trojan" }
            }, "tag": "Trojan-WSS-TLS"
        },
        {
            "listen": "0.0.0.0", "port": 443, "protocol": "shadowsocks",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "ws", "security": "tls",
                "tlsSettings": { "certificates": [{ "certificateFile": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem", "keyFile": "/etc/letsencrypt/live/$DOMAIN/privkey.pem" }] },
                "wsSettings": { "path": "/ss" }
            }, "tag": "SS-WSS-TLS"
        },
        {
            "listen": "0.0.0.0", "port": 80, "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/vless" } }, "tag": "Vless-WS-NoneTLS"
        },
        {
            "listen": "0.0.0.0", "port": 80, "protocol": "vmess",
            "settings": { "clients": [] },
            "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/vmess" } }, "tag": "Vmess-WS-NoneTLS"
        },
        {
            "listen": "0.0.0.0", "port": 80, "protocol": "trojan",
            "settings": { "clients": [] },
            "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/trojan" } }, "tag": "Trojan-WS-NoneTLS"
        },
        {
            "listen": "0.0.0.0", "port": 80, "protocol": "shadowsocks",
            "settings": { "clients": [] },
            "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/ss" } }, "tag": "SS-WS-NoneTLS"
        },
        {
            "listen": "0.0.0.0", "port": 443, "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": {
                "network": "grpc", "security": "tls",
                "tlsSettings": { "certificates": [{ "certificateFile": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem", "keyFile": "/etc/letsencrypt/live/$DOMAIN/privkey.pem" }] },
                "grpcSettings": { "serviceName": "vless-grpc" }
            }, "tag": "Vless-gRPC-TLS"
        },
        {
            "listen": "0.0.0.0", "port": 443, "protocol": "vmess",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "grpc", "security": "tls",
                "tlsSettings": { "certificates": [{ "certificateFile": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem", "keyFile": "/etc/letsencrypt/live/$DOMAIN/privkey.pem" }] },
                "grpcSettings": { "serviceName": "vmess-grpc" }
            }, "tag": "Vmess-gRPC-TLS"
        },
        {
            "listen": "0.0.0.0", "port": 443, "protocol": "trojan",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "grpc", "security": "tls",
                "tlsSettings": { "certificates": [{ "certificateFile": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem", "keyFile": "/etc/letsencrypt/live/$DOMAIN/privkey.pem" }] },
                "grpcSettings": { "serviceName": "trojan-grpc" }
            }, "tag": "Trojan-gRPC-TLS"
        },
        {
            "listen": "0.0.0.0", "port": 443, "protocol": "shadowsocks",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "grpc", "security": "tls",
                "tlsSettings": { "certificates": [{ "certificateFile": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem", "keyFile": "/etc/letsencrypt/live/$DOMAIN/privkey.pem" }] },
                "grpcSettings": { "serviceName": "ss-grpc" }
            }, "tag": "SS-gRPC-TLS"
        }
    ],
    "outbounds": [{ "protocol": "freedom" }]
}
EOF

# Restart Xray
systemctl restart xray

# Firewall
print_color "YELLOW" "Mengkonfigurasi Firewall (UFW)..."
ufw disable
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 81/tcp
ufw allow 109/tcp
ufw allow 143/tcp
ufw allow 222/tcp
ufw allow 777/tcp
ufw allow 7100:7900/udp
ufw --force enable

# Install Menu VPS
print_color "YELLOW" "Menginstall Menu VPS..."
wget -O /usr/local/bin/menu "https://raw.githubusercontent.com/Senrydepe/NEWAUTOSCRIPTVPS/main/menu.sh" && chmod +x /usr/local/bin/menu

# Install Bot Telegram
print_color "YELLOW" "Menginstall Bot Telegram..."
apt-get install -y python3 python3-pip
pip3 install python-telegram-bot --upgrade

mkdir -p /etc/vpbot
cat > /etc/vpbot/config.ini << EOF
[bot]
token = $BOT_TOKEN
owner_id = $OWNER_ID
EOF

wget -O /etc/vpbot/bot.py "https://raw.githubusercontent.com/Senrydepe/NEWAUTOSCRIPTVPS/main/bot.py" && chmod +x /etc/vpbot/bot.py

cat > /etc/systemd/system/vpbot.service << EOF
[Unit]
Description=VPS Telegram Bot
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/etc/vpbot
ExecStart=/usr/bin/python3 /etc/vpbot/bot.py
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpbot
systemctl start vpbot

# --- DITAMBAHKAN: BUAT FILE DATABASE AKUN ---
# Membuat file untuk menyimpan data akun
print_color "YELLOW" "Membuat database akun..."
touch /etc/xray/akun.txt
# --- SELESAI ---

# --- DITAMBAHKAN: PASANG BANNER AWAL ---
# Membuat Banner SSH
print_color "YELLOW" "Menginstall Banner SSH..."
cat > /etc/motd << EOF
<h3 style="text-align:center"><span style="color:white"><span style="color:white">================================</span></span></h3>

<h3 style="text-align:center"><span style="color:white"><span style="color:lime">AWS SERVER</span></span></h3> 

<h3 style="text-align:center"><span style="color:#ffff00">@Parael1101</span></h3>

<h3 style="text-align:center"><span style="color:red">SCRIPT BY vinstechmy</span></h3>

<h3 style="text-align:center"><span style="color:white">Parael</span></h3>

<h3 style="text-align:center"><span style="color:white"><span style="color:white">================================</span></span></h3>
EOF
# --- SELESAI MENAMBAHKAN BANNER ---

# Menyimpan informasi akun
cat > /root/akun.txt << EOF
============================================
         INFORMASI AKUN VPS ANDA
============================================
Domain: $DOMAIN
============================================
OpenSSH: 22
Dropbear: 109, 143
Stunnel4: 222, 777
SSH Websocket: 80
SSH SSL Websocket: 443
Nginx: 81
BadVPN: 7100-7900
NoobzVPN: 80, 443
============================================
AKUN XRAY (VLESS, VMESS, TROJAN, SS)
UUID: $UUID
============================================
VLESS WS TLS: vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=%2Fvless#VLESS-TLS-$DOMAIN
VLESS WS NoneTLS: vless://$UUID@$DOMAIN:80?encryption=none&security=none&type=ws&host=$DOMAIN&path=%2Fvless#VLESS-NoneTLS-$DOMAIN
VLESS gRPC TLS: vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=grpc&host=$DOMAIN&serviceName=vless-grpc&mode=gun#VLESS-gRPC-$DOMAIN
VMESS WS TLS: vmess://$(echo -n '{"v": "2", "ps": "VMESS-TLS-'$DOMAIN'", "add": "'$DOMAIN'", "port": "443", "id": "'$UUID'", "aid": "0", "scy": "auto", "net": "ws", "type": "none", "host": "'$DOMAIN'", "path": "/vmess", "tls": "tls"}' | base64 -w 0)
VMESS WS NoneTLS: vmess://$(echo -n '{"v": "2", "ps": "VMESS-NoneTLS-'$DOMAIN'", "add": "'$DOMAIN'", "port": "80", "id": "'$UUID'", "aid": "0", "scy": "auto", "net": "ws", "type": "none", "host": "'$DOMAIN'", "path": "/vmess", "tls": "none"}' | base64 -w 0)
TROJAN WS TLS: trojan://$UUID@$DOMAIN:443?security=tls&type=ws&host=$DOMAIN&path=%2Ftrojan#TROJAN-TLS-$DOMAIN
TROJAN WS NoneTLS: trojan://$UUID@$DOMAIN:80?security=none&type=ws&host=$DOMAIN&path=%2Ftrojan#TROJAN-NoneTLS-$DOMAIN
SHADOWSOCKS WS TLS: ss://$(echo -n "chacha20-ietf-poly1305:$UUID@$DOMAIN:443" | base64 -w 0)#SS-TLS-$DOMAIN
SHADOWSOCKS WS NoneTLS: ss://$(echo -n "chacha20-ietf-poly1305:$UUID@$DOMAIN:80" | base64 -w 0)#SS-NoneTLS-$DOMAIN
============================================
Ketik 'menu' di terminal untuk membuka menu.
Kontrol VPS melalui bot Telegram Anda.
============================================
EOF

clear
print_color "GREEN" "============================================"
print_color "GREEN" "        INSTALASI BERHASIL SELESAI!        "
print_color "GREEN" "============================================"
echo
print_color "YELLOW" "Informasi akun telah disimpan di /root/akun.txt"
echo
cat /root/akun.txt
echo
print_color "GREEN" "Ketik 'menu' di terminal untuk membuka menu VPS."
print_color "GREEN" "Kontrol VPS Anda melalui bot Telegram yang sudah Anda buat."
