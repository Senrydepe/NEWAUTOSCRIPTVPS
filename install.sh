#!/bin/bash

# =============================================================================
#               Menu Otomatis untuk NoobzVPN Script
#      Berdasarkan repository: https://github.com/noobz-id/noobzvpns
#      Dibuat untuk memudahkan instalasi dan penggunaan harian
# =============================================================================

# Warna untuk tampilan
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fungsi untuk membersihkan layar dan menampilkan header
tampilkan_header() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${GREEN}         NOOBZVPN SCRIPT MANAGER           ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo -e "   VPS: ${YELLOW}$(hostname)${NC} | IP: ${YELLOW}$(curl -s ipinfo.io/ip)${NC}"
    echo -e "${CYAN}--------------------------------------------${NC}"
}

# Fungsi untuk mengecek apakah NoobzVPN sudah terinstall
# Script asli menginstall file di /usr/local/sbin/noobzvpns
cek_instalasi() {
    if [ -f "/usr/local/sbin/noobzvpns" ]; then
        return 0 # True, sudah terinstall
    else
        return 1 # False, belum terinstall
    fi
}

# Loop utama menu
while true
do
    tampilkan_header
    
    # Menampilkan status instalasi
    if cek_instalasi; then
        echo -e "Status NoobzVPN: ${GREEN}Terinstall${NC}"
    else
        echo -e "Status NoobzVPN: ${RED}Belum Terinstall${NC}"
    fi
    
    echo -e "${CYAN}--------------------------------------------${NC}"
    echo "Pilih menu di bawah ini:"
    echo "  ${GREEN}1${NC}) Install NoobzVPN Script"
    echo "  ${GREEN}2${NC}) Buka Menu NoobzVPN"
    echo "  ${GREEN}3${NC}) Update & Upgrade Sistem VPS"
    echo "  ${GREEN}4${NC}) Cek Informasi VPS (RAM, OS, CPU)"
    echo "  ${GREEN}5${NC}) Cek Kecepatan VPS (Speedtest)"
    echo "  ${GREEN}6${NC}) Reboot VPS"
    echo -e "${RED}0${NC}) Keluar"
    echo -e "${CYAN}--------------------------------------------${NC}"
    read -p "Masukkan pilihan Anda [1-6 atau 0]: " pilihan

    case $pilihan in
        1)
            echo -e "${YELLOW}Memulai instalasi NoobzVPN Script...${NC}"
            sleep 1
            # Perintah instalasi resmi dari README noobz-id
            curl -sL https://git.io/noobzvpns | bash
            echo -e "${GREEN}Instalasi selesai. Tekan Enter untuk kembali ke menu utama...${NC}"
            read
            ;;
        2)
            if cek_instalasi; then
                echo -e "${YELLOW}Membuka menu NoobzVPN...${NC}"
                sleep 1
                # Perintah untuk menjalankan menu noobzvpn yang sudah terinstall
                noobzvpns
            else
                echo -e "${RED}NoobzVPN belum terinstall!${NC}"
                echo -e "Silakan pilih opsi ${YELLOW}1${NC} untuk menginstall terlebih dahulu."
                echo -e "Tekan Enter untuk melanjutkan..."
                read
            fi
            ;;
        3)
            echo -e "${YELLOW}Memperbarui dan meng-upgrade sistem...${NC}"
            sleep 1
            apt update && apt upgrade -y
            echo -e "${GREEN}Sistem telah diperbarui. Tekan Enter untuk melanjutkan...${NC}"
            read
            ;;
        4)
            tampilkan_header
            echo -e "${BLUE}--- INFORMASI VPS ---${NC}"
            echo -e "Nama Hostname: ${YELLOW}$(hostname)${NC}"
            echo -e "IP VPS: ${YELLOW}$(curl -s ipinfo.io/ip)${NC}"
            echo -e "Sistem Operasi: ${YELLOW}$(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)${NC}"
            echo -e "Kernel: ${YELLOW}$(uname -r)${NC}"
            echo -e "CPU Model: ${YELLOW}$(cat /proc/cpuinfo | grep 'model name' | uniq | cut -d ':' -f 2 | sed -e 's/^[ \t]*//')${NC}"
            echo -e "Total RAM: ${YELLOW}$(free -h | grep Mem | awk '{print $2}')${NC}"
            echo -e "Penggunaan RAM: ${YELLOW}$(free -h | grep Mem | awk '{print $3}')${NC}"
            echo -e "Uptime: ${YELLOW}$(uptime -p)${NC}"
            echo -e "${CYAN}--------------------------------------------${NC}"
            echo -e "Tekan Enter untuk kembali ke menu..."
            read
            ;;
        5)
            echo -e "${YELLOW}Menginstall speedtest-cli (jika belum ada) dan menjalankan tes...${NC}"
            # Install speedtest-cli jika belum ada
            if ! command -v speedtest-cli &> /dev/null; then
                apt install -y speedtest-cli
            fi
            speedtest-cli
            echo -e "${GREEN}Tes selesai. Tekan Enter untuk melanjutkan...${NC}"
            read
            ;;
        6)
            echo -e "${RED}VPS akan reboot dalam 5 detik. Tekan Ctrl+C untuk membatalkan.${NC}"
            sleep 5
            reboot
            ;;
        0)
            echo -e "${GREEN}Terima kasih! Sampai jumpa.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid! Silakan coba lagi.${NC}"
            sleep 2
            ;;
    esac
done
