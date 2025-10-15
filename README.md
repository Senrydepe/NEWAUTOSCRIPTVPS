# VPS Auto-Script with Telegram Bot

Skrip otomatis untuk instalasi dan manajemen VPS (VPN Server) dengan berbagai layanan, yang dapat dikontrol penuh melalui bot Telegram.

## ✨ Fitur

-   **Multi-OS:** Support untuk Debian 9/10/11 dan Ubuntu 18.04/20.04/22.04.
-   **Input Domain:** Meminta domain di awal instalasi untuk konfigurasi otomatis.
-   **Auto Install SSL:** Menggunakan Certbot untuk mendapatkan SSL Lets Encrypt secara gratis.
-   **Layanan Lengkap:**
    -   OpenSSH, Dropbear, Stunnel4
    -   SSH Websocket (HTTP & HTTPS)
    -   Xray Core (Vmess, Vless, Trojan, Shadowsocks) dengan WS dan gRPC (TLS & None-TLS)
    -   BadVPN (UDPGW)
    -   Nginx
-   **Manajemen via Telegram:** Kontrol VPS (cek status, restart, buat akun, dll) melalui bot Telegram.
-   **Keamanan:** Hanya `OWNER_ID` yang bisa mengakses menu bot.

## 📋 Prasyarat

1.  **VPS:** Dengan OS Debian atau Ubuntu (versi yang disebutkan di atas).
2.  **Domain:** Domain atau subdomain yang sudah di-pointing ke IP VPS di Cloudflare (status **Proxied** / icon awan oranye).
3.  **Telegram Bot:**
    -   **Bot Token:** Dapatkan dari [@BotFather](https://t.me/BotFather).
    -   **Owner ID:** Dapatkan dari [@userinfobot](https://t.me/userinfobot).

## 🚀 Cara Instalasi

1.  **Login ke VPS** sebagai user `root`.
2.  **Jalankan perintah instalasi:**
    ```bash
    wget -O install.sh https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main/install.sh && chmod +x install.sh && ./install.sh
    ```
    > **Penting:** Ganti `YOUR_GITHUB_USERNAME` dan `YOUR_REPO_NAME` dengan username dan nama repositori GitHub Anda.

3.  **Ikuti instruksi:** Skrip akan meminta Anda untuk memasukkan:
    -   Domain/Subdomain
    -   Bot Token Telegram
    -   Owner ID Telegram

4.  **Tunggu proses instalasi selesai.** Jika berhasil, Anda akan melihat informasi akun dan detail instalasi.

## 🤖 Cara Menggunakan Bot Telegram

1.  Setelah instalasi, buka Telegram dan cari bot yang Anda buat.
2.  Kirim perintah `/start`.
3.  Bot akan membalas dengan tombol-tombol menu. Klik tombol untuk menjalankan perintah yang diinginkan.

## 📝 Menu VPS (Terminal)

Anda juga bisa mengakses menu manajemen langsung dari terminal VPS dengan mengetik:
```bash
menu