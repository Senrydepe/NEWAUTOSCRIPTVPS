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

# --- Fungsi Utama Pembuatan Akun (DIUBAH TOTAL) ---
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

# --- Fungsi Lainnya (tidak berubah) ---
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
