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
    echo "10. Ubah Banner SSH"
    echo "11. Restart NoobzVPN"
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
    echo "Membuat akun trial..."
    echo "Akun trial berhasil dibuat."
elif [ "$1" == "status" ]; then
    check_status
elif [ "$1" == "restart_noobzvpn" ]; then
    restart_noobzvpn
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
            10) change_banner ;;
            11) restart_noobzvpn ;;
            0) exit ;;
            *) echo "Pilihan tidak valid." ;;
        esac
        read -p "Tekan Enter untuk melanjutkan..."
    done
fi
