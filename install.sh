#!/usr/bin/env bash
set -Eeuo pipefail

# Hydra Live V9 installer
# - Uses Node.js 22.x + npm, matching the documented manual installation.
# - Does NOT install pnpm.
# - Safe to re-run: preserves .env and existing Hydra Live V9 data.
# - Fails loudly on required steps instead of hiding errors with `|| true`.

APP_NAME="hydra-live-v9"
APP_DIR="${HOME}/hydra-live-v9"
REPO_URL="https://github.com/ilyasahmadalmaki/streamflow.git"
NODE_MAJOR="22"
DEFAULT_PORT="7575"
TIMEZONE="${TIMEZONE:-Asia/Jakarta}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
die()  { echo -e "${RED}✗ ERROR:${NC} $*" >&2; exit 1; }

trap 'die "Installer berhenti pada baris ${LINENO}: ${BASH_COMMAND}"' ERR

[[ "${EUID}" -ne 0 ]] || die "Jalankan sebagai user biasa yang memiliki sudo, bukan sebagai root."
command -v sudo >/dev/null 2>&1 || die "sudo tidak ditemukan."
sudo -v || die "User ini tidak memiliki akses sudo."

if [[ ! -r /etc/os-release ]]; then
    die "Tidak dapat mendeteksi OS."
fi
. /etc/os-release

if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *ubuntu* ]]; then
    warn "Installer ini ditujukan untuk Ubuntu. OS terdeteksi: ${PRETTY_NAME:-unknown}"
    read -r -p "Lanjutkan? (y/N): " answer
    [[ "${answer}" =~ ^[Yy]$ ]] || exit 1
fi

ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
[[ "${ARCH}" == "amd64" || "${ARCH}" == "arm64" ]] || \
    die "Arsitektur ${ARCH:-unknown} belum didukung oleh installer ini."

echo "=============================================="
echo "        Hydra Live V9 Stable Installer"
echo "        Node.js ${NODE_MAJOR} + npm"
echo "        pnpm: DISABLED"
echo "=============================================="
echo
read -r -p "Mulai instalasi? (y/N): " answer
[[ "${answer}" =~ ^[Yy]$ ]] || { echo "Instalasi dibatalkan."; exit 0; }

# ------------------------------------------------------------
# 1. System packages
# ------------------------------------------------------------
log "Memperbarui package index..."
sudo apt-get update

log "Memasang dependency sistem..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    git \
    ffmpeg \
    python3 \
    make \
    g++ \
    build-essential \
    ufw \
    lsof

command -v ffmpeg >/dev/null 2>&1 || die "FFmpeg gagal dipasang."
command -v git >/dev/null 2>&1 || die "Git gagal dipasang."
ok "Dependency sistem siap."

# ------------------------------------------------------------
# 2. Node.js 22 + npm
# ------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
    CURRENT_NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
else
    CURRENT_NODE_MAJOR=""
fi

if [[ "${CURRENT_NODE_MAJOR}" != "${NODE_MAJOR}" ]]; then
    log "Memasang/menyetarakan Node.js ${NODE_MAJOR}.x..."
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
else
    ok "Node.js ${NODE_MAJOR}.x sudah tersedia."
fi

command -v node >/dev/null 2>&1 || die "Node.js tidak ditemukan setelah instalasi."
command -v npm >/dev/null 2>&1 || die "npm tidak ditemukan setelah instalasi."

NODE_VERSION="$(node -v)"
NPM_VERSION="$(npm -v)"
[[ "${NODE_VERSION#v}" == "${NODE_MAJOR}."* ]] || die "Versi Node tidak sesuai: ${NODE_VERSION}"

ok "Node.js ${NODE_VERSION}"
ok "npm ${NPM_VERSION}"

if command -v pnpm >/dev/null 2>&1; then
    warn "pnpm terdeteksi di server, tetapi installer Hydra Live V9 tidak menggunakannya."
fi

# ------------------------------------------------------------
# 3. Repository
# ------------------------------------------------------------
if [[ -d "${APP_DIR}/.git" ]]; then
    log "Repository Hydra Live V9 sudah ada."

    cd "${APP_DIR}"

    if [[ -n "$(git status --porcelain)" ]]; then
        die "Repository memiliki perubahan lokal. Backup/commit perubahan tersebut sebelum menjalankan installer upgrade."
    fi

    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    if [[ "${CURRENT_BRANCH}" != "main" ]]; then
        warn "Branch saat ini: ${CURRENT_BRANCH}"
        read -r -p "Tetap update branch ini? (y/N): " answer
        [[ "${answer}" =~ ^[Yy]$ ]] || exit 1
    fi

    log "Mengambil update repository..."
    git fetch --prune origin
    git pull --ff-only
else
    if [[ -e "${APP_DIR}" ]]; then
        die "${APP_DIR} sudah ada tetapi bukan repository Git Hydra Live V9."
    fi

    log "Clone repository Hydra Live V9..."
    git clone "${REPO_URL}" "${APP_DIR}"
    cd "${APP_DIR}"
fi

ok "Source Hydra Live V9 siap di ${APP_DIR}"

# ------------------------------------------------------------
# 4. Environment / SESSION_SECRET
# ------------------------------------------------------------
cd "${APP_DIR}"

if [[ ! -f .env ]]; then
    log "Membuat .env..."
    touch .env
fi

chmod 600 .env

if ! grep -qE '^PORT=' .env; then
    printf 'PORT=%s\n' "${DEFAULT_PORT}" >> .env
fi

if ! grep -qE '^SESSION_SECRET=.+$' .env; then
    log "Membuat SESSION_SECRET baru..."
    SECRET="$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")"
    printf 'SESSION_SECRET=%s\n' "${SECRET}" >> .env
else
    ok "SESSION_SECRET existing dipertahankan."
fi

# Jangan menjalankan generate-secret.js pada setiap reinstall karena script
# tersebut selalu mengganti SESSION_SECRET dan dapat menginvalidasi session.
ok ".env siap."

# ------------------------------------------------------------
# 5. npm dependencies
# ------------------------------------------------------------
log "Membersihkan dependency manager lama jika ada..."
rm -f .pnpmfile.cjs

log "Menginstal dependency Node.js dengan npm..."
npm install

# Native modules are dependencies of the application.
log "Memverifikasi native modules..."
node - <<'NODE'
const checks = [
  ["sqlite3", () => require("sqlite3")],
  ["bcrypt", () => require("bcrypt")],
  ["express", () => require("express")],
  ["@ffmpeg-installer/ffmpeg", () => require("@ffmpeg-installer/ffmpeg")],
  ["@ffprobe-installer/ffprobe", () => require("@ffprobe-installer/ffprobe")]
];

let failed = false;

for (const [name, fn] of checks) {
  try {
    const mod = fn();
    if (name === "@ffmpeg-installer/ffmpeg" && !mod.path) throw new Error("FFmpeg binary path missing");
    if (name === "@ffprobe-installer/ffprobe" && !mod.path) throw new Error("FFprobe binary path missing");
    console.log(`OK ${name}`);
  } catch (err) {
    failed = true;
    console.error(`FAIL ${name}: ${err.message}`);
  }
}

if (failed) process.exit(1);
NODE

ok "Dependency dan native modules tervalidasi."

# ------------------------------------------------------------
# 6. Generate / verify application directories and database
# ------------------------------------------------------------
mkdir -p db logs public/uploads

# Do not change ownership of the whole home directory.
# Ensure only application-owned paths are writable by the current user.
chmod 755 db logs public/uploads

# Quick application load test without starting a permanent server.
log "Memeriksa apakah app.js dapat dimuat..."
node --check app.js
ok "Syntax app.js valid."

# ------------------------------------------------------------
# 7. Timezone
# ------------------------------------------------------------
if command -v timedatectl >/dev/null 2>&1; then
    CURRENT_TZ="$(timedatectl show --property=Timezone --value 2>/dev/null || true)"
    if [[ "${CURRENT_TZ}" != "${TIMEZONE}" ]]; then
        log "Mengatur timezone ke ${TIMEZONE}..."
        sudo timedatectl set-timezone "${TIMEZONE}"
    fi
    ok "Timezone: ${TIMEZONE}"
else
    warn "timedatectl tidak tersedia; timezone tidak diubah."
fi

# ------------------------------------------------------------
# 8. Read application port from .env
# ------------------------------------------------------------
APP_PORT="$(awk -F= '$1=="PORT" {print $2; exit}' .env | tr -d '[:space:]')"
APP_PORT="${APP_PORT:-${DEFAULT_PORT}}"

[[ "${APP_PORT}" =~ ^[0-9]+$ ]] || die "PORT di .env tidak valid: ${APP_PORT}"
(( APP_PORT >= 1 && APP_PORT <= 65535 )) || die "PORT di luar range: ${APP_PORT}"

# ------------------------------------------------------------
# 9. Firewall - protect SSH before enabling UFW
# ------------------------------------------------------------
log "Menyiapkan firewall..."

SSH_PORT=""
if command -v sshd >/dev/null 2>&1; then
    SSH_PORT="$(sudo sshd -T 2>/dev/null | awk '$1=="port" {print $2; exit}' || true)"
fi

if [[ -z "${SSH_PORT}" ]]; then
    SSH_PORT="$(sudo ss -ltnp 2>/dev/null | awk '/sshd/ {split($4,a,":"); print a[length(a)]; exit}' || true)"
fi

if [[ -z "${SSH_PORT}" ]]; then
    warn "Port SSH tidak dapat dideteksi otomatis."
    read -r -p "Masukkan port SSH yang sedang digunakan (default 22): " SSH_PORT
    SSH_PORT="${SSH_PORT:-22}"
fi

[[ "${SSH_PORT}" =~ ^[0-9]+$ ]] || die "Port SSH tidak valid: ${SSH_PORT}"
(( SSH_PORT >= 1 && SSH_PORT <= 65535 )) || die "Port SSH di luar range: ${SSH_PORT}"

# Add rules before enabling UFW so an SSH session is not intentionally
# locked out by this installer.
sudo ufw allow "${SSH_PORT}/tcp"
sudo ufw allow "${APP_PORT}/tcp"

if sudo ufw status | grep -q "Status: active"; then
    ok "UFW sudah aktif; aturan SSH ${SSH_PORT}/tcp dan app ${APP_PORT}/tcp dipastikan tersedia."
else
    read -r -p "Aktifkan UFW sekarang? (Y/n): " answer
    if [[ -z "${answer}" || "${answer}" =~ ^[Yy]$ ]]; then
        sudo ufw --force enable
        ok "UFW aktif."
    else
        warn "UFW tidak diaktifkan."
    fi
fi

# ------------------------------------------------------------
# 10. PM2 via npm
# ------------------------------------------------------------
if command -v pm2 >/dev/null 2>&1; then
    ok "PM2 sudah tersedia: $(pm2 --version)"
else
    log "Memasang PM2 dengan npm..."
    sudo npm install -g pm2
fi

command -v pm2 >/dev/null 2>&1 || die "PM2 gagal ditemukan."
ok "PM2 $(pm2 --version)"

# ------------------------------------------------------------
# 11. Start / restart Hydra Live V9
# ------------------------------------------------------------
cd "${APP_DIR}"

if pm2 describe "${APP_NAME}" >/dev/null 2>&1; then
    log "Restart Hydra Live V9..."
    pm2 restart "${APP_NAME}" --update-env
else
    log "Menjalankan Hydra Live V9..."
    pm2 start app.js --name "${APP_NAME}" --time
fi

pm2 save

# ------------------------------------------------------------
# 12. PM2 startup
# ------------------------------------------------------------
log "Menyiapkan PM2 auto-start saat reboot..."

# PM2 prints the exact systemd command. Extract only the expected sudo
# command; do not pipe arbitrary output to `sudo bash`.
STARTUP_CMD="$(pm2 startup systemd -u "${USER}" --hp "${HOME}" 2>&1 | \
    sed -n 's/.*\(sudo env .*pm2 startup systemd.*\)/\1/p' | head -n 1 || true)"

if [[ -n "${STARTUP_CMD}" ]]; then
    log "Menerapkan PM2 systemd startup..."
    eval "${STARTUP_CMD}"
else
    warn "PM2 startup command tidak perlu diterapkan atau tidak ditemukan."
fi

pm2 save
ok "PM2 startup tersimpan."

# ------------------------------------------------------------
# 13. Runtime verification
# ------------------------------------------------------------
log "Menunggu Hydra Live V9 siap..."

READY=0
for _ in {1..30}; do
    if curl -fsS --max-time 3 "http://127.0.0.1:${APP_PORT}/" >/dev/null 2>&1; then
        READY=1
        break
    fi

    if ! pm2 pid "${APP_NAME}" >/dev/null 2>&1; then
        break
    fi

    sleep 2
done

if [[ "${READY}" -ne 1 ]]; then
    echo
    warn "Hydra Live V9 belum memberikan HTTP response."
    echo "----- PM2 STATUS -----"
    pm2 status || true
    echo "----- PM2 LOGS (50) -----"
    pm2 logs "${APP_NAME}" --lines 50 --nostream || true
    die "Health/readiness check gagal. Lihat log di atas."
fi

ok "Hydra Live V9 merespons HTTP pada port ${APP_PORT}."

# ------------------------------------------------------------
# 14. Final summary
# ------------------------------------------------------------
SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
SERVER_IP="${SERVER_IP:-$(curl -4 -fsS --max-time 5 ifconfig.me 2>/dev/null || echo 'SERVER_IP')}"

echo
echo "=============================================="
echo "        HYDRA LIVE V9 SIAP DIGUNAKAN"
echo "=============================================="
echo "URL       : http://${SERVER_IP}:${APP_PORT}"
echo "Directory : ${APP_DIR}"
echo "Node      : $(node -v)"
echo "npm       : $(npm -v)"
echo "FFmpeg    : $(ffmpeg -version 2>&1 | head -n 1)"
echo "PM2       : $(pm2 --version)"
echo "SSH port  : ${SSH_PORT}"
echo "App port  : ${APP_PORT}"
echo "Timezone  : ${TIMEZONE}"
echo "=============================================="
echo
echo "Status : pm2 status"
echo "Logs   : pm2 logs ${APP_NAME}"
echo "Restart: pm2 restart ${APP_NAME}"
echo
echo "Catatan: installer ini sengaja TIDAK menggunakan pnpm."
echo "Catatan: SESSION_SECRET existing tidak diubah saat reinstall."
echo "=============================================="
