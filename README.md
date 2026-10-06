<div align="center">

# Hydra Live V9: Web-Based Multi-Platform Streaming

> ⚠️ **Status: Beta** — Project ini masih dalam tahap pengembangan aktif. Silakan pakai, analisa, dan laporkan bug yang kamu temukan.

**HYDRA LIVE V9** adalah platform live streaming berbasis web yang powerful dan mudah digunakan. Streaming ke YouTube, Facebook, dan platform RTMP lainnya secara bersamaan dari satu aplikasi. Dilengkapi dengan video management, scheduled streaming, dan real-time monitoring untuk pengalaman streaming yang profesional.

[🚀 Installation](#-quick-installation) • [📖 Documentation](#-manual-installation) • [🔒 HTTPS](#-instalasi-https-domain--ssl) • [🐳 Docker](#-docker-deployment) • [🪛 Troubleshooting](#-troubleshooting) • [💬 Community](https://github.com/ilyasahmadalmaki/streamflow/issues)

![screenshot](https://github.com/user-attachments/assets/fef1c0a5-04f6-41ae-8ea1-5eb1fff13a22)

</div>

---

## ✨ Fitur Utama

- **Multi-Platform Streaming** - Streaming ke berbagai platform populer secara bersamaan
- **Video Gallery** - Kelola koleksi video dengan antarmuka yang intuitif
- **Upload Video** - Upload dari local storage atau import langsung dari Google Drive
- **Scheduled Streaming** - Jadwalkan streaming dengan pengaturan waktu yang fleksibel
- **Advanced Settings** - Kontrol penuh untuk bitrate, resolusi, FPS, dan orientasi video
- **Real-time Monitoring** - Monitor status streaming dengan dashboard real-time
- **Video Analytics** - Pantau statistik dan performa video langsung dari aplikasi
- **Responsive UI** - Antarmuka modern yang responsif di semua perangkat

## 💻 System Requirements

- **Node.js v22** (wajib — modul native tidak kompatibel dengan Node 24)
- **FFmpeg** untuk video processing
- **SQLite3** (sudah termasuk dalam package)
- **VPS/Server** dengan minimal 1 Core CPU & 1GB RAM
- **Port** 7575 (dapat disesuaikan di file [.env](.env))

## ⚡ Quick Installation

Untuk instalasi otomatis, jalankan perintah berikut:

```bash
curl -o install.sh https://raw.githubusercontent.com/ilyasahmadalmaki/streamflow/main/install.sh && chmod +x install.sh && ./install.sh
```

## 🔧 Manual Installation

### 1. Persiapan Server

Update sistem operasi:
```bash
sudo apt update && sudo apt upgrade -y
```

Install Node.js 22:
```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

Verifikasi instalasi Node.js:
```bash
node --version
npm --version
```

Install FFmpeg:
```bash
sudo apt install ffmpeg -y
```

Verifikasi instalasi FFmpeg:
```bash
ffmpeg -version
```

Install Git:
```bash
sudo apt install git -y
```

### 2. Setup Project Hydra Live V9

Clone repository:
```bash
git clone https://github.com/ilyasahmadalmaki/streamflow
```

Masuk ke direktori project:
```bash
cd streamflow
```

Install paket Node.js:
```bash
npm install
```

Generate secret key:
```bash
node generate-secret.js
```

Konfigurasi port (opsional):
```bash
nano .env
```

Jalankan aplikasi:
```bash
npm run dev
```

### 3. Konfigurasi Firewall

**PENTING: buka port SSH terlebih dahulu untuk menghindari terkuncinya koneksi!**

Buka port SSH (biasanya port 22):
```bash
sudo ufw allow ssh
# atau jika menggunakan port SSH custom:
# sudo ufw allow [PORT_SSH_ANDA]
```

Buka port aplikasi (default: 7575):
```bash
sudo ufw allow 7575
```

Verifikasi aturan firewall sebelum mengaktifkan:
```bash
sudo ufw status verbose
```

Aktifkan firewall:
```bash
sudo ufw enable
```

Verifikasi status firewall:
```bash
sudo ufw status
```

### 4. Install Process Manager

Install PM2 untuk mengelola aplikasi:
```bash
sudo npm install -g pm2
```

### 5. Menjalankan Aplikasi

Jalankan aplikasi dengan PM2:
```bash
pm2 start app.js --name hydra-live-v9
```

**Setup auto-restart saat server reboot:**
```bash
# Simpan konfigurasi PM2 saat ini
pm2 save

# Setup PM2 untuk auto-start saat server restart
pm2 startup

# Ikuti instruksi yang muncul, biasanya berupa command yang harus dijalankan dengan sudo
# Contoh: sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u username --hp /home/username

# Setelah menjalankan command startup, simpan kembali
pm2 save
```

**Perintah PM2 yang berguna:**
```bash
pm2 status              # Lihat status aplikasi
pm2 restart hydra-live-v9
pm2 stop hydra-live-v9
pm2 logs hydra-live-v9  # Lihat logs aplikasi
pm2 monit               # Monitor resource usage
```

Akses aplikasi melalui browser:
```
http://IP_SERVER:7575
```

Contoh: `http://88.12.34.56:7575`

## 🔒 Instalasi HTTPS (Domain + SSL)

**Kenapa perlu HTTPS?** Untuk fitur *YouTube API (OAuth)*, Google mewajibkan redirect URI berupa **HTTPS** dengan **nama domain** — IP mentah tidak diterima, dan harus didaftarkan persis di Google Cloud Console. Tanpa ini, proses "Connect YouTube Account" tidak akan jalan. Kalau kamu hanya pakai *stream key manual*, bagian ini opsional.

Pilih salah satu dari 3 opsi di bawah. Setelah HTTPS aktif, daftarkan redirect URI berikut di Google Cloud Console (Credentials → OAuth Client ID):

```
https://DOMAIN_KAMU/auth/youtube/callback
```

---

### Opsi A — Caddy + DuckDNS ⭐ (Rekomendasi)

Paling simpel: Caddy mengurus sertifikat SSL otomatis (Let's Encrypt) tanpa config manual.

**1. Daftar domain gratis di DuckDNS:**
- Buka [duckdns.org](https://www.duckdns.org), login, buat subdomain (misal `hydraku`), arahkan ke IP VPS kamu.

**2. Buka port 80 & 443** (dibutuhkan untuk verifikasi Let's Encrypt):
```bash
sudo ufw allow 80
sudo ufw allow 443
```

**3. Install Caddy:**
```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy
```

**4. Buat Caddyfile** (`sudo nano /etc/caddy/Caddyfile`):
```
hydraku.duckdns.org {
    reverse_proxy localhost:7575
}
```

**5. Reload Caddy** — sertifikat SSL terbit otomatis:
```bash
sudo systemctl reload caddy
```

Selesai. Akses via `https://hydraku.duckdns.org`.

---

### Opsi B — Cloudflare Tunnel

Tanpa buka port sama sekali di VPS, tanpa urus sertifikat. Cocok kalau port 80/443 diblokir.

**1. Install `cloudflared`:**
```bash
curl -L -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

**2. Login & buat tunnel:**
```bash
cloudflared tunnel login
cloudflared tunnel create hydra-tunnel
```

**3. Route-kan domain ke tunnel** (bisa pakai domain sendiri atau subdomain Cloudflare):
```bash
cloudflared tunnel route dns hydra-tunnel hydraku.duckdns.org
```

**4. Buat config** (`~/.cloudflared/config.yml`):
```yaml
tunnel: hydra-tunnel
credentials-file: /home/USERNAME/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: hydraku.duckdns.org
    service: http://localhost:7575
  - service: http_status:404
```

**5. Jalankan sebagai service:**
```bash
sudo cloudflared service install
sudo systemctl start cloudflared
```

Selesai. Akses via `https://hydraku.duckdns.org` (HTTPS otomatis dari Cloudflare).

---

### Opsi C — Nginx + Certbot

Cara klasik, kontrol penuh, tapi semua langkah manual.

**1. Siapkan domain** (misal via DuckDNS, arahkan ke IP VPS) dan buka port 80/443:
```bash
sudo ufw allow 80
sudo ufw allow 443
```

**2. Install Nginx & Certbot:**
```bash
sudo apt install -y nginx certbot python3-certbot-nginx
```

**3. Buat virtual host** (`sudo nano /etc/nginx/sites-available/hydra`):
```nginx
server {
    listen 80;
    server_name hydraku.duckdns.org;

    location / {
        proxy_pass http://localhost:7575;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**4. Aktifkan & terbitkan sertifikat:**
```bash
sudo ln -s /etc/nginx/sites-available/hydra /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d hydraku.duckdns.org
```

Certbot otomatis renew via systemd timer. Cek dengan `sudo certbot renew --dry-run`.

---

### Ringkasan Perbandingan

|  | Caddy | Cloudflare Tunnel | Nginx + Certbot |
|---|---|---|---|
| Tingkat kesulitan | ⭐ Mudah | ⭐⭐ Sedang | ⭐⭐⭐ Manual |
| Sertifikat SSL | Otomatis | Otomatis (Cloudflare) | Manual via Certbot |
| Port 80/443 dibuka | Ya | **Tidak perlu** | Ya |
| Ketergantungan pihak ke-3 | Let's Encrypt | Cloudflare | Let's Encrypt |

## 🔐 Reset Password

Jika lupa password atau perlu reset akun:

```bash
cd streamflow && node reset-password.js
```

## ⏰ Pengaturan Timezone Server

Untuk memastikan scheduled streaming berjalan dengan waktu yang akurat:

Cek timezone saat ini:
```bash
timedatectl status
```

Lihat daftar timezone yang tersedia:
```bash
timedatectl list-timezones | grep Asia
```

Set timezone ke WIB (Jakarta):
```bash
sudo timedatectl set-timezone Asia/Jakarta
```

Restart aplikasi setelah mengubah timezone:
```bash
pm2 restart hydra-live-v9
```

## 🐳 Docker Deployment

### 1. Persiapan Environment

Buat file `.env` di root project:
```env
PORT=7575
SESSION_SECRET=your_random_secret_here
NODE_ENV=development
```

### 2. Build dan Jalankan

```bash
docker-compose up --build
```

Akses aplikasi: [http://localhost:7575](http://localhost:7575)

### 3. Data Persistence

Data tersimpan otomatis di:
- Database: `db/`
- Logs: `logs/`
- Upload files: `public/uploads/`

### 4. Reset Password (Docker)

```bash
docker-compose exec app node reset-password.js
```

## 🪛 Troubleshooting

### Permission Error
```bash
chmod -R 755 public/uploads/
```

### Port Already in Use
```bash
# Cek proses yang menggunakan port
sudo lsof -i :7575

# Kill proses jika diperlukan
sudo kill -9 <PID>
```

### Database Error
```bash
# Reset database (PERINGATAN: akan menghapus semua data)
rm db/*.db

# Restart aplikasi untuk membuat database baru
pm2 restart hydra-live-v9
```

### Docker Troubleshooting

**Tidak bisa login:**
- Pastikan `NODE_ENV=development` untuk akses HTTP
- Periksa permission folder:
  ```bash
  sudo chmod -R 777 db/ logs/ public/uploads/
  ```
- Pastikan `SESSION_SECRET` tidak berubah

**Production (HTTPS):**
- Set `NODE_ENV=production`
- Akses melalui HTTPS agar cookie session aman

## 💫 Contributors

[![Contributors](https://contrib.rocks/image?repo=ilyasahmadalmaki/streamflow)](https://github.com/ilyasahmadalmaki/streamflow/graphs/contributors)

## 📄 License

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/ilyasahmadalmaki/streamflow/blob/main/LICENSE.md)

---
© 2026 - [Bang Tutorial](https://youtube.com/bangtutorial)
