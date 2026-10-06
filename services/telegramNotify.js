// Notifikasi Telegram untuk kejadian penting streaming.
// Konfigurasi via .env:
//   TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
//   TELEGRAM_CHAT_ID=123456789
// Kalau tidak dikonfigurasi, semua fungsi jadi no-op (tidak error).
// Cara dapat bot token: chat ke @BotFather di Telegram -> /newbot
// Cara dapat chat ID: chat ke @userinfobot di Telegram.

function isConfigured() {
  return Boolean(process.env.TELEGRAM_BOT_TOKEN && process.env.TELEGRAM_CHAT_ID);
}

async function sendTelegramMessage(text) {
  if (!isConfigured()) return false;
  try {
    const token = process.env.TELEGRAM_BOT_TOKEN;
    const chatId = process.env.TELEGRAM_CHAT_ID;
    const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, text, parse_mode: 'HTML', disable_web_page_preview: true })
    });
    return res.ok;
  } catch (e) {
    console.error('[telegram] gagal kirim notifikasi:', e.message);
    return false;
  }
}

function esc(s) {
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function timestamp() {
  return new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });
}

async function notifyStreamDown(streamTitle, reason) {
  const msg =
    `🔴 <b>Stream MATI: ${esc(streamTitle)}</b>\n` +
    `⏰ ${timestamp()} WIB\n` +
    (reason ? `📝 ${esc(reason)}\n` : '') +
    `\nCek dashboard untuk detail / restart manual.`;
  return sendTelegramMessage(msg);
}

async function notifyStreamStartFailed(streamTitle, reason) {
  const msg =
    `⚠️ <b>Stream GAGAL START: ${esc(streamTitle)}</b>\n` +
    `⏰ ${timestamp()} WIB\n` +
    (reason ? `📝 ${esc(reason)}\n` : '') +
    `\nCek RTMP URL & stream key, lalu coba start ulang.`;
  return sendTelegramMessage(msg);
}

async function notifyStreamRecovered(streamTitle) {
  const msg =
    `🟢 <b>Stream PULIH: ${esc(streamTitle)}</b>\n` +
    `⏰ ${timestamp()} WIB\n` +
    `\nStream berjalan kembali normal.`;
  return sendTelegramMessage(msg);
}

module.exports = {
  isConfigured,
  sendTelegramMessage,
  notifyStreamDown,
  notifyStreamStartFailed,
  notifyStreamRecovered
};
