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

# --- DETEKSI OS YANG LEBIH BAIK DAN UNIVERSAL ---
# Gunakan /etc/os-release, standar untuk distro modern
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    print_color "RED" "Tidak dapat mendeteksi OS. File /etc/os-release tidak ditemukan."
    exit 1
fi

OS=$(echo "$OS" | tr '[:upper:]' '[:lower:]')

if [[ "$OS" != "debian" && "$OS" != "ubuntu" ]]; then
    print_color "RED" "OS tidak didukung: $OS. Script ini hanya untuk Debian dan Ubuntu."
    exit 1
fi

print_color "GREEN" "OS Terdeteksi: $OS $VERSION_ID"

# Input Domain
clear
print_color "YELLOW" "============================================"
print_color "YELLOW" "      VPS AUTO-SCRIPT INSTALLER V3         "
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
# --- DIUBAH: HILANGKAN CERTBOT ---
apt-get install -y curl wget git unzip gnupg2 lsb-release nginx socat netcat-openbsd cron jq build-essential

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

# Install SSH Websocket (Kode Sumber Ditanam)
print_color "YELLOW" "Menginstall SSH Websocket dari kode sumber yang ditanam..."
if ! command -v go &> /dev/null; then
    print_color "YELLOW" "Menginstall Go compiler..."
    GO_VERSION="1.21.6"
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    rm -rf /usr/local/go && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    source /etc/profile
fi
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
cd /tmp/sshws
/usr/local/go/bin/go build -o sshws
mkdir -p /usr/local/bin/sshws
mv sshws /usr/local/bin/sshws/sshws
chmod +x /usr/local/bin/sshws/sshws
cd /root
rm -rf /tmp/sshws
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

# Install NoobzVPN (Kode Sumber Ditanam)
print_color "YELLOW" "Menginstall NoobzVPN dari kode sumber yang ditanam..."
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
cd /tmp/noobzvpn
/usr/local/go/bin/go mod tidy
/usr/local/go/bin/go build -o noobzvpn
mkdir -p /usr/local/bin
mv noobzvpn /usr/local/bin/noobzvpn
chmod +x /usr/local/bin/noobzvpn
cd /root
rm -rf /tmp/noobzvpn
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

# --- DIUBAH: INSTALLASI SSL MENGGUNAKAN ACME.SH ---
# Install acme.sh
print_color "YELLOW" "Menginstall acme.sh untuk SSL..."
curl https://get.acme.sh | sh -s email=admin@$DOMAIN

# Source .bashrc untuk membuat perintah 'acme.sh' tersedia
source ~/.bashrc

# Hentikan layanan yang menggunakan port 80 sementara
print_color "YELLOW" "Menghentikan layanan port 80 untuk verifikasi SSL..."
systemctl stop nginx sshws noobzvpn-80

# Dapatkan sertifikat SSL dengan acme.sh dalam mode standalone
print_color "YELLOW" "Mendapatkan sertifikat SSL untuk $DOMAIN..."
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256

# Install sertifikat ke folder yang lebih mudah diakses
print_color "YELLOW" "Menginstall sertifikat SSL..."
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
    --fullchain-file /etc/xray/xray.crt \
    --key-file /etc/xray/xray.key \
    --reloadcmd "systemctl restart xray"

# Jalankan kembali layanan yang dihentikan
print_color "YELLOW" "Menjalankan kembali layanan port 80..."
systemctl start nginx sshws noobzvpn-80
# --- SELESAI MODIFIKASI SSL ---

# Membuat Konfigurasi Xray
print_color "YELLOW" "Membuat konfigurasi Xray..."
UUID=$(cat /proc/sys/kernel/random/uuid)
mkdir -p /etc/xray
cat > /etc/xray/config.json << EOF
{
    "log": { "loglevel": "warning" },
    "inbounds": [
        { "listen": "0.0.0.0", "port": 443, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] }, "wsSettings": { "path": "/vless" } }, "tag": "Vless-WSS-TLS" },
        { "listen": "0.0.0.0", "port": 443, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] }, "wsSettings": { "path": "/vmess" } }, "tag": "Vmess-WSS-TLS" },
        { "listen": "0.0.0.0", "port": 443, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] }, "wsSettings": { "path": "/trojan" } }, "tag": "Trojan-WSS-TLS" },
        { "listen": "0.0.0.0", "port": 443, "protocol": "shadowsocks", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] }, "wsSettings": { "path": "/ss" } }, "tag": "SS-WSS-TLS" },
        { "listen": "0.0.0.0", "port": 80, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/vless" } }, "tag": "Vless-WS-NoneTLS" },
        { "listen": "0.0.0.0", "port": 80, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/vmess" } }, "tag": "Vmess-WS-NoneTLS" },
        { "listen": "0.0.0.0", "port": 80, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/trojan" } }, "tag": "Trojan-WS-NoneTLS" },
        { "listen": "0.0.0.0", "port": 80, "protocol": "shadowsocks", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/ss" } }, "tag": "SS-WS-NoneTLS" },
        { "listen": "0.0.0.0", "port": 443, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "grpc", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] }, "grpcSettings": { "serviceName": "vless-grpc" } }, "tag": "Vless-gRPC-TLS" },
        { "listen": "0.0.0.0", "port": 443, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] }, "grpcSettings": { "serviceName": "vmess-grpc" } }, "tag": "Vmess-gRPC-TLS" },
        { "listen": "0.0.0.0", "port": 443, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] }, "grpcSettings": { "serviceName": "trojan-grpc" } }, "tag": "Trojan-gRPC-TLS" },
        { "listen": "0.0.0.0", "port": 443, "protocol": "shadowsocks", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] }, "grpcSettings": { "serviceName": "ss-grpc" } }, "tag": "SS-gRPC-TLS" }
    ],
    "outbounds": [{ "protocol": "freedom" }]
}
EOF
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

# --- FUNGSI UNTUK MENANAMKAN SCRIPT ---
install_menu_script() {
    print_color "YELLOW" "Membuat Menu VPS..."
    cat > /usr/local/bin/menu << 'MENU_EOF'
#!/bin/bash

# Baca konfigurasi VPS
source /etc/vps.conf

# Fungsi untuk menampilkan menu utama
show_menu() {
    clear
    echo "============================================"
    echo "           MENU VPS MANAGEMENT              "
    echo "============================================"
    echo "1. Buat Akun Trial"
    echo "2. Buat Akun Premium"
    echo "3. Hapus Akun"
    echo "4. Daftar Akun"
    echo "5. Lock Akun"
    echo "6. Unlock Akun"
    echo "7. Cek Status Layanan"
    echo "8. Restart Semua Layanan"
    echo "9. Info VPS"
    echo "10. Ubah Banner SSH"
    echo "11. Restart NoobzVPN"
    echo "12. Perpanjang Akun"
    echo "0. Keluar"
    echo "--------------------------------------------"
    read -p "Pilih menu: " choice
}

# Fungsi untuk menampilkan menu pembuatan akun
show_create_menu() {
    clear
    echo "============================================"
    echo "           PILIH LAYANAN AKUN            "
    echo "============================================"
    echo "1. SSH / Dropbear"
    echo "2. VMess WS"
    echo "3. Vless WS"
    echo "4. Trojan WS"
    echo "5. Shadowsocks WS"
    echo "6. NoobzVPN"
    echo "0. Kembali"
    echo "--------------------------------------------"
    read -p "Pilih layanan: " service_choice
}

# Fungsi untuk mencetak tampilan kotak
print_box() {
    local str="$1"
    local len=${#str}
    local total_width=50
    local pad_len=$(( (total_width - len) / 2 ))
    local padding=$(printf "%*s" "$pad_len" | tr ' ' " ")
    echo "━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%s%s\n" "$padding" "$str"
    echo "━━━━━━━━━━━━━━━━━━━━━━━"
}

# Fungsi untuk membuat link VMess
create_vmess_link() {
    local remarks="$1"
    local id="$2"
    local host="$3"
    local port="$4"
    local path="$5"
    local net="$6"
    local tls="$7"
    local host_header="$8"
    local sni="$9"

    local json="{ \"v\": \"2\", \"ps\": \"$remarks\", \"add\": \"$host\", \"port\": \"$port\", \"id\": \"$id\", \"aid\": \"0\", \"net\": \"$net\", \"path\": \"$path\", \"type\": \"none\", \"host\": \"$host_header\", \"tls\": \"$tls\" }"
    echo "vmess://$(echo -n "$json" | base64 -w 0)"
}

# Fungsi untuk membuat link VLESS/Trojan/Shadowsocks (URL Scheme)
create_url_scheme_link() {
    local scheme="$1"
    local user_part="$2"
    local server_part="$3"
    local params="$4"
    local fragment="$5"
    echo "${scheme}://${user_part}@${server_part}${params}#${fragment}"
}

# --- Fungsi Pembuat Detail Akun ---
create_ssh_account_details() {
    local username="$1"
    local password="$2"
    local expired_display="$3"
    cat > "/var/www/html/ssh-$username.txt" <<EOF
[SSH]
Host = $DOMAIN
Port SSH = 22, 444
Port Dropbear = 109, 143, 443
Port SSH WS = 80
Port SSH SSL WS = 443
Username = $username
Password = $password
Payload WS = GET / [protocol][crlf]Host: [host][crlf]Connection: Keep-Alive[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]
Payload SSL WS = GET wss://bug.com/ [protocol][crlf]Host: $DOMAIN[crlf]Connection: Keep-Alive[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]
EOF
    local details="
Username : $username
Password : $password
━━━━━━━━━━━━━━━━━━━━━━━
Host : $DOMAIN
OpenSSH : 22
Dropbear : 109, 143
SSH-WS : 80
SSH-SSL-WS : 443
SSL/TLS : 447, 777
UDPGW : 7100-7300
━━━━━━━━━━━━━━━━━━━━━━━
Link SSH Config : http://$DOMAIN:81/ssh-$username.txt
━━━━━━━━━━━━━━━━━━━━━━━
Payload WS
GET / [protocol][crlf]Host: [host][crlf]Connection: Keep-Alive[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]
━━━━━━━━━━━━━━━━━━━━━━━
GET wss://bug.com/ [protocol][crlf]Host: $DOMAIN[crlf]Connection: Keep-Alive[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]
━━━━━━━━━━━━━━━━━━━━━━━
Expired On : $expired_display
"
    print_box "SSH ACCOUNT"
    echo -e "$details"
}

create_vmess_account_details() {
    local remarks="$1"
    local uuid="$2"
    local expired_display="$3"
    local config_link="http://$DOMAIN:81/vmess-$remarks.txt"
    local vmess_tls=$(create_vmess_link "VMESS_TLS_$remarks" "$uuid" "$DOMAIN" "443" "/vmess" "ws" "tls" "$DOMAIN" "$DOMAIN")
    local vmess_ntls=$(create_vmess_link "VMESS_NTLS_$remarks" "$uuid" "$DOMAIN" "80" "/vmess" "ws" "none" "$DOMAIN" "$DOMAIN")
    local vmess_grpc=$(create_vmess_link "VMESS_GRPC_$remarks" "$uuid" "$DOMAIN" "443" "vmess-grpc" "grpc" "tls" "$DOMAIN" "$DOMAIN")
    cat > "/var/www/html/vmess-$remarks.txt" <<EOF
 $vmess_tls
 $vmess_ntls
 $vmess_grpc
EOF
    local details="
Remarks : $remarks
Domain : $DOMAIN
Port TLS : 443
Port none TLS : 80
Port GRPC : 443
id : $uuid
alterId : 0
Security : auto
Network : ws/grpc
Path : /vmess
ServiceName : vmess-grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link TLS : $vmess_tls
━━━━━━━━━━━━━━━━━━━━━━━
Link none TLS : $vmess_ntls
━━━━━━━━━━━━━━━━━━━━━━━
Link GRPC : $vmess_grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link Vmess Config : $config_link
━━━━━━━━━━━━━━━━━━━━━━━
Expired On : $expired_display
"
    print_box "VMESS ACCOUNT"
    echo -e "$details"
}

create_vless_account_details() {
    local remarks="$1"
    local uuid="$2"
    local expired_display="$3"
    local config_link="http://$DOMAIN:81/vless-$remarks.txt"
    local vless_tls=$(create_url_scheme_link "vless" "$uuid" "$DOMAIN:443" "?type=ws&encryption=none&security=tls&host=$DOMAIN&path=/vless&allowInsecure=1&sni=$DOMAIN" "XRAY_VLESS_TLS_$remarks")
    local vless_ntls=$(create_url_scheme_link "vless" "$uuid" "$DOMAIN:80" "?type=ws&encryption=none&security=none&host=$DOMAIN&path=/vless" "XRAY_VLESS_NTLS_$remarks")
    local vless_grpc=$(create_url_scheme_link "vless" "$uuid" "$DOMAIN:443" "?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=$DOMAIN" "VLESS_GRPC_$remarks")
    cat > "/var/www/html/vless-$remarks.txt" <<EOF
 $vless_tls
 $vless_ntls
 $vless_grpc
EOF
    local details="
Remarks : $remarks
Domain : $DOMAIN
port TLS : 443
port none TLS : 80
id : $uuid
Network : ws/grpc
Encryption : none
Path : /vless
Path : vless-grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link TLS : $vless_tls
━━━━━━━━━━━━━━━━━━━━━━━
Link none TLS : $vless_ntls
━━━━━━━━━━━━━━━━━━━━━━━
Link GRPC : $vless_grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link Vless Config : $config_link
━━━━━━━━━━━━━━━━━━━━━━━
Expired On : $expired_display
"
    print_box "VLESS ACCOUNT"
    echo -e "$details"
}

create_trojan_account_details() {
    local remarks="$1"
    local uuid="$2"
    local expired_display="$3"
    local config_link="http://$DOMAIN:81/trojan-$remarks.txt"
    local trojan_ws=$(create_url_scheme_link "trojan" "$uuid" "$DOMAIN:443" "?path=%2Ftrojan-ws&security=tls&host=$DOMAIN&type=ws&sni=$DOMAIN" "TROJAN_WS_$remarks")
    local trojan_go=$(create_url_scheme_link "trojan-go" "$uuid" "$DOMAIN:443" "?path=%2Ftrojan-ws&security=tls&host=$DOMAIN&type=ws&sni=$DOMAIN" "TROJANGO_$remarks")
    local trojan_grpc=$(create_url_scheme_link "trojan" "$uuid" "$DOMAIN:443" "?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=$DOMAIN" "TROJAN_GRPC_$remarks")
    cat > "/var/www/html/trojan-$remarks.txt" <<EOF
 $trojan_ws
 $trojan_go
 $trojan_grpc
EOF
    local details="
Remarks : $remarks
Host/IP : $DOMAIN
port : 443
Key : $uuid
Network : ws/grpc
Path : /trojan-ws
ServiceName : trojan-grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link WS : $trojan_ws
━━━━━━━━━━━━━━━━━━━━━━━
Link GO : $trojan_go
━━━━━━━━━━━━━━━━━━━━━━━
Link GRPC : $trojan_grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link Trojan Config : $config_link
━━━━━━━━━━━━━━━━━━━━━━━
Expired On : $expired_display
"
    print_box "TROJAN ACCOUNT"
    echo -e "$details"
}

create_shadowsocks_account_details() {
    local remarks="$1"
    local uuid="$2"
    local expired_display="$3"
    local ss_method="aes-128-gcm"
    local ss_payload_base64=$(echo -n "${ss_method}:${uuid}" | base64 -w 0)
    local config_link_ws="http://$DOMAIN:81/sodosokws-$remarks.txt"
    local config_link_grpc="http://$DOMAIN:81/sodosokgrpc-$remarks.txt"
    local ss_ws_tls=$(create_url_scheme_link "ss" "$ss_payload_base64" "$DOMAIN:443" "?path=/ss-ws&security=tls&encryption=none&type=ws" "$remarks")
    local ss_ws_ntls=$(create_url_scheme_link "ss" "$ss_payload_base64" "$DOMAIN:80" "?path=/ss-ws&security=none&encryption=none&type=ws" "$remarks")
    local ss_grpc_tls=$(create_url_scheme_link "ss" "$ss_payload_base64" "$DOMAIN:443" "?mode=gun&security=tls&encryption=none&type=grpc&serviceName=ss-grpc&sni=bug.com" "$remarks")
    local ss_grpc_ntls=$(create_url_scheme_link "ss" "$ss_payload_base64" "$DOMAIN:80" "?mode=gun&security=none&encryption=none&type=grpc&serviceName=ss-grpc&sni=bug.com" "$remarks")
    cat > "/var/www/html/sodosokws-$remarks.txt" <<EOF
 $ss_ws_tls
 $ss_ws_ntls
EOF
    cat > "/var/www/html/sodosokgrpc-$remarks.txt" <<EOF
 $ss_grpc_tls
 $ss_grpc_ntls
EOF
    local details="
Remarks : $remarks
Domain : $DOMAIN
Port WS : 443/80
Port GRPC : 443
Password : $uuid
Cipers : $ss_method
Network : ws/grpc
Path : /ss-ws
ServiceName : ss-grpc
━━━━━━━━━━━━━━━━━━━━━━━
Link WS TLS : $ss_ws_tls
━━━━━━━━━━━━━━━━━━━━━━━
Link WS None TLS : $ss_ws_ntls
━━━━━━━━━━━━━━━━━━━━━━━
Link GRPC TLS : $ss_grpc_tls
━━━━━━━━━━━━━━━━━━━━━━━
Link GRPC None TLS : $ss_grpc_ntls
━━━━━━━━━━━━━━━━━━━━━━━
Link JSON WS : $config_link_ws
━━━━━━━━━━━━━━━━━━━━━━━
Link JSON gRPC : $config_link_grpc
━━━━━━━━━━━━━━━━━━━━━━━
Expired On : $expired_display
"
    print_box "SHADOWSOCKS ACCOUNT"
    echo -e "$details"
}

create_noobzvpn_account_details() {
    local username="$1"
    local password="$2"
    local expired_display="$3"
    cat > "/var/www/html/noobzvpn-$username.txt" <<EOF
[NoobzVPN]
server = $DOMAIN
port_http = 80
port_https = 443
username = $username
password = $password
EOF
    local details="
Username : $username
Password : $password
━━━━━━━━━━━━━━━━━━━━━━━
Server : $DOMAIN
Port HTTP : 80
Port HTTPS : 443
━━━━━━━━━━━━━━━━━━━━━━━
Link Config : http://$DOMAIN:81/noobzvpn-$username.txt
━━━━━━━━━━━━━━━━━━━━━━━
Expired On : $expired_display
"
    print_box "NOOBZVPN ACCOUNT"
    echo -e "$details"
}

# --- Fungsi Utama Pembuatan Akun ---
create_account() {
    local account_type=$1
    local duration_days=$2
    
    if [ -f /tmp/service_choice ]; then
        service_choice=$(cat /tmp/service_choice)
        rm -f /tmp/service_choice
    else
        show_create_menu
    fi

    local username="TR$(shuf -i 100-999 -n 1)"
    if [ "$account_type" == "premium" ]; then
        username="PR$(shuf -i 100-999 -n 1)"
    fi
    local password=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 10)
    local expiry_date=$(date -d "$duration_days days" +"%Y-%m-%d")
    local expired_display=$(date -d "$duration_days days" +"%b %d, %Y")
    local uuid=$(cat /proc/sys/kernel/random/uuid)

    echo "$username:$password:$expiry_date:$service_choice" >> /etc/xray/akun.txt

    case $service_choice in
        1)
            useradd -M -s /bin/false -e "$expiry_date" "$username"
            echo "$username:$password" | chpasswd
            create_ssh_account_details "$username" "$password" "$expired_display"
            ;;
        2)
            config_payload="{\"id\": \"$uuid\", \"email\": \"$username@$DOMAIN\"}"
            jq --argjson new_client "$config_payload" '.inbounds[] | select(.tag=="Vmess-WSS-TLS").settings.clients += [$new_client]' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
            systemctl restart xray
            create_vmess_account_details "$username" "$uuid" "$expired_display"
            ;;
        3)
            config_payload="{\"id\": \"$uuid\", \"email\": \"$username@$DOMAIN\"}"
            jq --argjson new_client "$config_payload" '.inbounds[] | select(.tag=="Vless-WSS-TLS").settings.clients += [$new_client]' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
            systemctl restart xray
            create_vless_account_details "$username" "$uuid" "$expired_display"
            ;;
        4)
            config_payload="{\"password\": \"$uuid\", \"email\": \"$username@$DOMAIN\"}"
            jq --argjson new_client "$config_payload" '.inbounds[] | select(.tag=="Trojan-WSS-TLS").settings.clients += [$new_client]' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
            systemctl restart xray
            create_trojan_account_details "$username" "$uuid" "$expired_display"
            ;;
        5)
            config_payload="{\"method\": \"chacha20-ietf-poly1305\", \"password\": \"$uuid\", \"email\": \"$username@$DOMAIN\"}"
            jq --argjson new_client "$config_payload" '.inbounds[] | select(.tag=="SS-WSS-TLS").settings.clients += [$new_client]' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
            systemctl restart xray
            create_shadowsocks_account_details "$username" "$uuid" "$expired_display"
            ;;
        6)
            create_noobzvpn_account_details "$username" "$password" "$expired_display"
            ;;
        0) return ;;
        *) echo "Pilihan tidak valid." ;;
    esac
}

# --- Fungsi Lainnya ---
delete_account() {
    read -p "Masukkan username yang akan dihapus: " username
    if grep -q "^$username:" /etc/xray/akun.txt; then
        service=$(grep "^$username:" /etc/xray/akun.txt | cut -d: -f4)
        case $service in
            ssh) userdel -f $username ;;
            vmess|vless|trojan|shadowsocks)
                uuid=$(grep "^$username:" /etc/xray/akun.txt | cut -d: -f2)
                jq --arg uuid "$uuid" '(.inbounds[].settings.clients) |= map(select(.id != $uuid))' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
                systemctl restart xray
                ;;
        esac
        sed -i "/^$username:/d" /etc/xray/akun.txt
        echo "Akun $username berhasil dihapus."
    else
        echo "Akun $username tidak ditemukan."
    fi
}

list_accounts() {
    echo "------------------------------------"
    echo "           DAFTAR AKUN PENGGUNA         "
    echo "------------------------------------"
    if [ ! -s /etc/xray/akun.txt ]; then
        echo "Belum ada akun yang dibuat."
        return
    fi
    printf "%-15s | %-15s | %-10s | %-12s\n" "Username" "Password/UUID" "Expiry" "Service"
    echo "------------------------------------------------------------"
    while IFS=':' read -r username pass expiry service; do
        printf "%-15s | %-15s | %-10s | %-12s\n" "$username" "$pass" "$expiry" "$service"
    done < /etc/xray/akun.txt
}

lock_account() {
    read -p "Masukkan username yang akan dikunci: " username
    if grep -q "^$username:" /etc/xray/akun.txt; then
        new_pass=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
        sed -i "s/^$username:[^:]*/$username:$new_pass/" /etc/xray/akun.txt
        service=$(grep "^$username:" /etc/xray/akun.txt | cut -d: -f4)
        if [[ "$service" != "ssh" ]]; then
            uuid=$(grep "^$username:" /etc/xray/akun.txt | cut -d: -f2)
            jq --arg uuid "$uuid" --arg new_pass "$new_pass" '(.inbounds[].settings.clients) |= map(if .id == $uuid then .password = $new_pass else . end)' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
            systemctl restart xray
        else
            usermod -L $username
        fi
        echo "Akun $username berhasil dikunci."
    else
        echo "Akun $username tidak ditemukan."
    fi
}

unlock_account() {
    read -p "Masukkan username yang akan dibuka kuncinya: " username
    if grep -q "^$username:" /etc/xray/akun.txt; then
        usermod -U $username
        echo "Akun $username telah dibuka. Silakan ubah password SSH jika diperlukan."
        echo "Untuk akun Xray, silakan buat akun baru jika lupa password/UUID."
    else
        echo "Akun $username tidak ditemukan."
    fi
}

renew_account() {
    read -p "Masukkan username yang akan diperpanjang: " username
    if grep -q "^$username:" /etc/xray/akun.txt; then
        read -p "Perpanjang berapa hari? " days
        new_expiry=$(date -d "$days days" +"%Y-%m-%d")
        sed -i "s/^$username:[^:]*:[^:]*/$username:&:$new_expiry/" /etc/xray/akun.txt
        echo "Akun $username berhasil diperpanjang hingga $new_expiry."
    else
        echo "Akun $username tidak ditemukan."
    fi
}

check_status() {
    echo "=== Status Layanan ==="
    echo "Xray Core: $(systemctl is-active xray)"
    echo "SSH Websocket (Port 80): $(systemctl is-active sshws)"
    echo "SSH SSL Websocket (Port 443): $(systemctl is-active sshws-ssl)"
    echo "Stunnel4: $(systemctl is-active stunnel4)"
    echo "Dropbear: $(systemctl is-active dropbear)"
    echo "Nginx: $(systemctl is-active nginx)"
    echo "BadVPN: $(systemctl is-active badvpn)"
    echo "NoobzVPN (Port 80): $(systemctl is-active noobzvpn-80)"
    echo "NoobzVPN (Port 443): $(systemctl is-active noobzvpn-443)"
    echo "Telegram Bot: $(systemctl is-active vpbot)"
}

restart_services() {
    echo "Merestart semua layanan..."
    systemctl restart xray sshws sshws-ssl stunnel4 dropbear nginx badvpn noobzvpn-80 noobzvpn-443 vpbot
    echo "Semua layanan telah di-restart."
}

info_vps() {
    echo "=== Info VPS ==="
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)"
    echo "IP Public: $(curl -s ipinfo.io/ip)"
    echo "Uptime: $(uptime -p)"
}

change_banner() {
    echo "Banner saat ini:"
    cat /etc/motd
    echo
    read -p "Apakah Anda ingin mengganti dengan template default? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        cat > /etc/motd << EOF
<h3 style="text-align:center"><span style="color:white"><span style="color:white">================================</span></span></h3>
<h3 style="text-align:center"><span style="color:white"><span style="color:lime">AWS SERVER</span></span></h3> 
<h3 style="text-align:center"><span style="color:#ffff00">@Parael1101</span></h3>
<h3 style="text-align:center"><span style="color:red">SCRIPT BY vinstechmy</span></h3>
<h3 style="text-align:center"><span style="color:white">Parael</span></h3>
<h3 style="text-align:center"><span style="color:white"><span style="color:white">================================</span></span></h3>
EOF
        echo "Banner berhasil diperbarui!"
    else
        echo "Batal mengubah banner."
    fi
}

restart_noobzvpn() {
    echo "Merestart layanan NoobzVPN..."
    systemctl restart noobzvpn-80 noobzvpn-443
    echo "NoobzVPN telah di-restart."
}

# --- Logika Utama ---
if [ "$1" == "create_trial" ]; then
    create_account "trial" 3
elif [ "$1" == "create_premium" ]; then
    create_account "premium" 30
elif [ "$1" == "status" ]; then
    check_status
elif [ "$1" == "restart_noobzvpn" ]; then
    restart_noobzvpn
else
    while true; do
        show_menu
        case $choice in
            1) create_account "trial" 3 ;;
            2) create_account "premium" 30 ;;
            3) delete_account ;;
            4) list_accounts ;;
            5) lock_account ;;
            6) unlock_account ;;
            7) check_status ;;
            8) restart_services ;;
            9) info_vps ;;
            10) change_banner ;;
            11) restart_noobzvpn ;;
            12) renew_account ;;
            0) exit ;;
            *) echo "Pilihan tidak valid." ;;
        esac
        read -p "Tekan Enter untuk melanjutkan..."
    done
fi
MENU_EOF
    chmod +x /usr/local/bin/menu
}

install_bot_script() {
    print_color "YELLOW" "Menginstall Bot Telegram..."
    apt-get install -y python3 python3-pip
    pip3 install python-telegram-bot --upgrade
    mkdir -p /etc/vpbot
    cat > /etc/vpbot/config.ini << EOF
[bot]
token = $BOT_TOKEN
owner_id = $OWNER_ID
EOF
    cat > /etc/vpbot/bot.py << 'BOT_EOF'
import subprocess
import logging
import os
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Updater, CommandHandler, CallbackQueryHandler, CallbackContext
import configparser

logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

config = configparser.ConfigParser()
config.read('/etc/vpbot/config.ini')
BOT_TOKEN = config['bot']['token']
OWNER_ID = int(config['bot']['owner_id'])

def run_command(command):
    try:
        result = subprocess.run(command, shell=True, check=True, text=True, capture_output=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr.strip()}"

def start(update: Update, context: CallbackContext) -> None:
    if update.effective_user.id != OWNER_ID:
        update.message.reply_text("Maaf, Anda tidak memiliki izin untuk menggunakan bot ini.")
        return
    keyboard = [
        [InlineKeyboardButton("➕ Buat Akun", callback_data='create_account_menu')],
        [InlineKeyboardButton("🗑️ Hapus Akun", callback_data='delete_account')],
        [InlineKeyboardButton("📋 Daftar Akun", callback_data='list_accounts')],
        [InlineKeyboardButton("🔧 Cek Status Layanan", callback_data='status')],
        [InlineKeyboardButton("🔄 Restart Semua Layanan", callback_data='restart_all')],
        [InlineKeyboardButton("💻 Info VPS", callback_data='info_vps')],
        [InlineKeyboardButton("🎨 Ubah Banner SSH", callback_data='change_banner')],
        [InlineKeyboardButton("🔌 Restart NoobzVPN", callback_data='restart_noobzvpn')],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    update.message.reply_text('Halo, Boss! Pilih menu di bawah:', reply_markup=reply_markup)

def button(update: Update, context: CallbackContext) -> None:
    query = update.callback_query
    if query.from_user.id != OWNER_ID:
        query.answer("Maaf, Anda tidak memiliki izin.")
        return
    query.answer()
    if query.data == 'create_account_menu':
        keyboard = [
            [InlineKeyboardButton("🧪 Buat Akun Trial", callback_data='create_trial')],
            [InlineKeyboardButton("💳 Buat Akun Premium", callback_data='create_premium')],
            [InlineKeyboardButton("⬅️ Kembali", callback_data='back_to_main')],
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text(text='Pilih jenis akun:', reply_markup=reply_markup)
    elif query.data in ['create_trial', 'create_premium']:
        account_type = "trial" if query.data == 'create_trial' else "premium"
        keyboard = [
            [InlineKeyboardButton("SSH / Dropbear", callback_data=f'create_{account_type}_ssh')],
            [InlineKeyboardButton("VMess WS", callback_data=f'create_{account_type}_vmess')],
            [InlineKeyboardButton("Vless WS", callback_data=f'create_{account_type}_vless')],
            [InlineKeyboardButton("Trojan WS", callback_data=f'create_{account_type}_trojan')],
            [InlineKeyboardButton("Shadowsocks WS", callback_data=f'create_{account_type}_ss')],
            [InlineKeyboardButton("NoobzVPN", callback_data=f'create_{account_type}_noobz')],
            [InlineKeyboardButton("⬅️ Kembali", callback_data='create_account_menu')],
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text(text=f'Pilih layanan untuk akun {account_type}:', reply_markup=reply_markup)
    elif query.data.startswith('create_'):
        parts = query.data.split('_')
        account_type = parts[1]
        service_map = {'ssh': '1', 'vmess': '2', 'vless': '3', 'trojan': '4', 'ss': '5', 'noobz': '6'}
        service_name = parts[2]
        service_choice = service_map.get(service_name, '0')
        with open('/tmp/service_choice', 'w') as f:
            f.write(service_choice)
        command = f'/usr/local/bin/menu create_{account_type}'
        result = run_command(command)
        if os.path.exists('/tmp/service_choice'):
            os.remove('/tmp/service_choice)
        messages = result.split('━━━━━━━━━━━━━━━━━━━━━━━')
        query.edit_message_text(text=f"✅ Membuat akun {account_type} untuk layanan {service_name}...")
        for msg_part in messages:
            stripped_part = msg_part.strip()
            if stripped_part:
                formatted_message = f"━━━━━━━━━━━━━━━━━━━━━━━\n{stripped_part}"
                try:
                    context.bot.send_message(chat_id=update.effective_chat.id, text=f"```{formatted_message}```", parse_mode='MarkdownV2')
                except Exception:
                    context.bot.send_message(chat_id=update.effective_chat.id, text=formatted_message)
    elif query.data == 'delete_account':
        query.edit_message_text(text="Untuk menghapus akun, silakan gunakan menu 'menu' di terminal VPS dan pilih opsi 3.")
    elif query.data == 'list_accounts':
        result = run_command('/usr/local/bin/menu list_accounts')
        query.edit_message_text(text=f"📋 <b>Daftar Akun:</b>\n\n<pre>{result}</pre>", parse_mode='HTML')
    elif query.data == 'status':
        result = run_command('/usr/local/bin/menu status')
        query.edit_message_text(text=f"🔧 <b>Status Layanan:</b>\n\n<pre>{result}</pre>", parse_mode='HTML')
    elif query.data == 'restart_all':
        query.edit_message_text(text="🔄 Sedang merestart semua layanan...")
        run_command('systemctl restart xray sshws sshws-ssl stunnel4 dropbear nginx badvpn noobzvpn-80 noobzvpn-443 vpbot')
        query.edit_message_text(text="✅ Semua layanan telah di-restart.")
    elif query.data == 'info_vps':
        info = run_command("hostname && cat /etc/os-release | grep PRETTY_NAME | cut -d '\"' -f 2 && curl -s ipinfo.io/ip && uptime -p")
        query.edit_message_text(text=f"💻 <b>Info VPS:</b>\n\n<pre>{info}</pre>", parse_mode='HTML')
    elif query.data == 'change_banner':
        banner_content = """<h3 style="text-align:center"><span style="color:white"><span style="color:white">================================</span></span></h3>
<h3 style="text-align:center"><span style="color:white"><span style="color:lime">AWS SERVER</span></span></h3> 
<h3 style="text-align:center"><span style="color:#ffff00">@Parael1101</span></h3>
<h3 style="text-align:center"><span style="color:red">SCRIPT BY vinstechmy</span></h3>
<h3 style="text-align:center"><span style="color:white">Parael</span></h3>
<h3 style="text-align:center"><span style="color:white"><span style="color:white">================================</span></span></h3>"""
        with open('/etc/motd', 'w') as f:
            f.write(banner_content)
        query.edit_message_text(text="✅ Banner SSH berhasil diperbarui dengan template default!")
    elif query.data == 'restart_noobzvpn':
        query.edit_message_text(text="🔌 Sedang merestart NoobzVPN...")
        result = run_command('/usr/local/bin/menu restart_noobzvpn')
        query.edit_message_text(text=f"🔌 <b>Restart NoobzVPN:</b>\n\n<pre>{result}</pre>", parse_mode='HTML')
    elif query.data == 'back_to_main':
        start(update, context)

def main() -> None:
    updater = Updater(BOT_TOKEN)
    dispatcher = updater.dispatcher
    dispatcher.add_handler(CommandHandler("start", start))
    dispatcher.add_handler(CallbackQueryHandler(button))
    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
BOT_EOF
    chmod +x /etc/vpbot/bot.py
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
}

# --- EKSEKUSI FUNGSI PEMASANGAN SCRIPT ---
install_menu_script
install_bot_script

# --- Buat file konfigurasi VPS ---
print_color "YELLOW" "Membuat file konfigurasi VPS..."
IP_VPS=$(curl -s ipinfo.io/ip)
cat > /etc/vps.conf << EOF
DOMAIN="$DOMAIN"
IP_VPS="$IP_VPS"
EOF

# Membuat file untuk menyimpan data akun
print_color "YELLOW" "Membuat database akun..."
touch /etc/xray/akun.txt

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
