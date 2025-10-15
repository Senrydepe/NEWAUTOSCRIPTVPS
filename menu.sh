#!/bin/bash

# Fungsi untuk menampilkan menu
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
    echo "0. Keluar"
    echo "--------------------------------------------"
    read -p "Pilih menu: " choice
}

# Fungsi untuk membuat akun (logika disederhanakan)
create_account() {
    echo "Fungsi membuat akun akan diimplementasikan di sini."
    echo "Ini akan menambahkan user ke /etc/xray/config.json dan merestart xray."
}

# Fungsi untuk menghapus akun
delete_account() {
    echo "Fungsi menghapus akun akan diimplementasikan di sini."
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
    echo "Telegram Bot: $(systemctl is-active vpbot)"
}

# Fungsi untuk restart layanan
restart_services() {
    echo "Merestart semua layanan..."
    systemctl restart xray sshws sshws-ssl stunnel4 dropbear nginx badvpn vpbot
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

# Logika utama
if [ "$1" == "create_trial" ]; then
    # Logika untuk membuat akun trial, dipanggil oleh bot
    echo "Membuat akun trial..."
    # ... implementasi ...
    echo "Akun trial berhasil dibuat."
elif [ "$1" == "status" ]; then
    # Logika untuk cek status, dipanggil oleh bot
    check_status
else
    # Tampilkan menu interaktif jika dipanggil tanpa argumen
    while true; do
        show_menu
        case $choice in
            1) create_account ;;
            2) create_account ;;
            3) delete_account ;;
            4) echo "Daftar akun..." ;;
            5) echo "Lock akun..." ;;
            6) echo "Unlock akun..." ;;
            7) check_status ;;
            8) restart_services ;;
            9) info_vps ;;
            0) exit ;;
            *) echo "Pilihan tidak valid." ;;
        esac
        read -p "Tekan Enter untuk melanjutkan..."
    done
fi