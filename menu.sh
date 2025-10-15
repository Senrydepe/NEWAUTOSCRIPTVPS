#!/bin/bash

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
    echo "0. Kembali"
    echo "--------------------------------------------"
    read -p "Pilih layanan: " service_choice
}

# Fungsi untuk membuat akun (logika utama)
create_account() {
    local account_type=$1
    local duration_days=$2
    
    show_create_menu
    local service_choice=$service_choice

    local username
    local password
    local expiry_date
    local uuid
    local config_payload

    # Baca pilihan dari file sementara jika ada (dari bot)
    if [ -f /tmp/service_choice ]; then
        service_choice=$(cat /tmp/service_choice)
        rm -f /tmp/service_choice
    fi

    # Generate username, password, expiry
    username=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8)
    password=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    expiry_date=$(date -d "$duration_days days" +"%Y-%m-%d")
    uuid=$(cat /proc/sys/kernel/random/uuid)

    case $service_choice in
        1) # SSH / Dropbear
            useradd -M -s /bin/false $username
            echo "$username:$password" | chpasswd
            echo "$username:$password:$expiry_date:ssh" >> /etc/xray/akun.txt
            echo "Akun SSH/Dropbear berhasil dibuat!"
            echo "Username: $username"
            echo "Password: $password"
            echo "Expired: $expiry_date"
            ;;
        2) # VMess
            config_payload="{\"id\": \"$uuid\", \"email\": \"$username@$DOMAIN\"}"
            jq --arg new_client "$config_payload" '.inbounds[] | select(.tag=="Vmess-WSS-TLS").settings.clients += [$new_client]' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
            echo "$username:$uuid:$expiry_date:vmess" >> /etc/xray/akun.txt
            systemctl restart xray
            echo "Akun VMess berhasil dibuat!"
            echo "Username: $username"
            echo "UUID: $uuid"
            echo "Expired: $expiry_date"
            ;;
        3) # Vless
            config_payload="{\"id\": \"$uuid\", \"email\": \"$username@$DOMAIN\"}"
            jq --arg new_client "$config_payload" '.inbounds[] | select(.tag=="Vless-WSS-TLS").settings.clients += [$new_client]' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
            echo "$username:$uuid:$expiry_date:vless" >> /etc/xray/akun.txt
            systemctl restart xray
            echo "Akun Vless berhasil dibuat!"
            echo "Username: $username"
            echo "UUID: $uuid"
            echo "Expired: $expiry_date"
            ;;
        4) # Trojan
            config_payload="{\"password\": \"$uuid\", \"email\": \"$username@$DOMAIN\"}"
            jq --arg new_client "$config_payload" '.inbounds[] | select(.tag=="Trojan-WSS-TLS").settings.clients += [$new_client]' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
            echo "$username:$uuid:$expiry_date:trojan" >> /etc/xray/akun.txt
            systemctl restart xray
            echo "Akun Trojan berhasil dibuat!"
            echo "Username: $username"
            echo "Password: $uuid"
            echo "Expired: $expiry_date"
            ;;
        5) # Shadowsocks
            config_payload="{\"method\": \"chacha20-ietf-poly1305\", \"password\": \"$uuid\", \"email\": \"$username@$DOMAIN\"}"
            jq --arg new_client "$config_payload" '.inbounds[] | select(.tag=="SS-WSS-TLS").settings.clients += [$new_client]' /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
            echo "$username:$uuid:$expiry_date:shadowsocks" >> /etc/xray/akun.txt
            systemctl restart xray
            echo "Akun Shadowsocks berhasil dibuat!"
            echo "Username: $username"
            echo "Password: $uuid"
            echo "Expired: $expiry_date"
            ;;
        0) return ;;
        *) echo "Pilihan tidak valid." ;;
    esac
}

# Fungsi untuk menghapus akun
delete_account() {
    read -p "Masukkan username yang akan dihapus: " username
    if grep -q "^$username:" /etc/xray/akun.txt; then
        service=$(grep "^$username:" /etc/xray/akun.txt | cut -d: -f4)
        case $service in
            ssh) userdel -f $username ;;
            vmess|vless|trojan|shadowsocks)
                uuid=$(grep "^$username:" /etc/xray/akun.txt | cut -d: -f2)
                # Hapus dari config.json berdasarkan UUID
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

# Fungsi untuk melihat daftar akun
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

# Fungsi untuk mengunci akun
lock_account() {
    read -p "Masukkan username yang akan dikunci: " username
    if grep -q "^$username:" /etc/xray/akun.txt; then
        # Ganti password/UUID dengan string acak untuk menonaktifkan
        new_pass=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
        sed -i "s/^$username:[^:]*/$username:$new_pass/" /etc/xray/akun.txt
        # Update config.json jika perlu
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

# Fungsi untuk membuka kunci akun
unlock_account() {
    read -p "Masukkan username yang akan dibuka kuncinya: " username
    if grep -q "^$username:" /etc/xray/akun.txt; then
        # Kembalikan password/UUID asli (ini perlu disimpan di tempat lain atau generate ulang)
        # Untuk kesederhanaan, kita akan buat user mengubah passwordnya sendiri
        usermod -U $username
        echo "Akun $username telah dibuka. Silakan ubah password SSH jika diperlukan."
        echo "Untuk akun Xray, silakan buat akun baru jika lupa password/UUID."
    else
        echo "Akun $username tidak ditemukan."
    fi
}

# Fungsi untuk memperpanjang akun
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

# Fungsi untuk cek status
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

# Fungsi untuk restart layanan
restart_services() {
    echo "Merestart semua layanan..."
    systemctl restart xray sshws sshws-ssl stunnel4 dropbear nginx badvpn noobzvpn-80 noobzvpn-443 vpbot
    echo "Semua layanan telah di-restart."
}

# Fungsi untuk info VPS
info_vps() {
    echo "=== Info VPS ==="
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)"
    echo "IP Public: $(curl -s ipinfo.io/ip)"
    echo "Uptime: $(uptime -p)"
}

# Fungsi untuk mengubah banner
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

# Fungsi untuk restart NoobzVPN
restart_noobzvpn() {
    echo "Merestart layanan NoobzVPN..."
    systemctl restart noobzvpn-80 noobzvpn-443
    echo "NoobzVPN telah di-restart."
}

# Logika utama
if [ "$1" == "create_trial" ]; then
    create_account "trial" 3
elif [ "$1" == "create_premium" ]; then
    create_account "premium" 30
elif [ "$1" == "status" ]; then
    check_status
elif [ "$1" == "restart_noobzvpn" ]; then
    restart_noobzvpn
else
    # Tampilkan menu interaktif jika dipanggil tanpa argumen
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
