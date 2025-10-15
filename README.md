# VPS Auto-Script with Telegram Bot

Skrip otomatis untuk instalasi dan manajemen VPS (VPN Server) dengan berbagai layanan tunneling, yang dapat dikontrol penuh melalui bot Telegram. Dibuat untuk menjadi solusi all-in-one yang andal, modern, dan mudah digunakan.

## ✨ Fitur

-   **Multi-OS:** Support untuk Debian 9/10/11/12 dan Ubuntu 18.04/20.04/22.04/24.04.
-   **Input Domain:** Meminta domain di awal instalasi untuk konfigurasi otomatis.
-   **SSL dengan `acme.sh`:** Menggunakan `acme.sh` yang lebih ringan dan andal untuk mendapatkan SSL Lets Encrypt secara gratis, menggantikan `certbot`.
-   **Layanan Lengkap:**
    -   OpenSSH, Dropbear, Stunnel4
    -   SSH Websocket (HTTP & HTTPS)
    -   Xray Core (Vmess, Vless, Trojan, Shadowsocks) dengan WS dan gRPC (TLS & None-TLS)
    -   BadVPN (UDPGW)
    -   Nginx
    -   **NoobzVPN** (Port 80 & 443)
-   **Manajemen Akun:**
    -   Buat akun **Trial** (3 hari) dan **Premium** (30 hari).
    -   Pilih layanan untuk setiap akun (SSH, Vmess, Vless, dll).
    -   Hapus, kunci, buka kunci, dan perpanjang akun.
-   **Output Akun Detail:** Menampilkan informasi akun yang sangat rapi dan profesional, lengkap dengan link konfigurasi, payload, dan link download file `.txt`.
-   **Manajemen via Telegram:** Kontrol VPS (cek status, restart, buat akun, dll) melalui bot Telegram dengan antarmuka yang interaktif.
-   **Keamanan:** Hanya `OWNER_ID` yang bisa mengakses menu bot.
-   **Installer Mandiri:** Tidak bergantung pada link download eksternal untuk file inti, menghindari error 404 dan masalah format file (`bad interpreter`).

## 📋 Prasyarat

1.  **VPS:** Dengan OS Debian atau Ubuntu (versi yang disebutkan di atas).
2.  **Domain:** Domain atau subdomain yang sudah di-pointing ke IP VPS.
3.  **Telegram Bot:**
    -   **Bot Token:** Dapatkan dari [@BotFather](https://t.me/BotFather) dengan perintah `/newbot`.
    -   **Owner ID:** Dapatkan dari [@userinfobot](https://t.me/userinfobot).

## 🚀 Cara Instalasi

1.  **Login ke VPS** sebagai user `root`.
2.  **Jalankan perintah instalasi:**
    ```bash
    wget -O install.sh https://raw.githubusercontent.com/Senrydepe/NEWAUTOSCRIPTVPS/main/install.sh && chmod +x install.sh && ./install.sh
    ```

3.  **Ikuti instruksi:** Skrip akan meminta Anda untuk memasukkan:
    -   Domain/Subdomain
    -   Bot Token Telegram
    -   Owner ID Telegram

4.  **Tunggu proses instalasi selesai.** Jika berhasil, Anda akan melihat informasi akun dan detail instalasi.

## 🤖 Cara Menggunakan Bot Telegram

1.  Setelah instalasi, buka Telegram dan cari bot yang Anda buat.
2.  Kirim perintah `/start`.
3.  Bot akan membalas dengan tombol-tombol menu. Klik tombol untuk menjalankan perintah yang diinginkan.
4.  Saat membuat akun, bot akan mengirim detail akun dalam beberapa pesan terpisah agar lebih rapi dan mudah dibaca.

## 💻 Cara Menggunakan Menu VPS (Terminal)

Anda juga bisa mengakses menu manajemen langsung dari terminal VPS dengan mengetik:
```bash
menu
