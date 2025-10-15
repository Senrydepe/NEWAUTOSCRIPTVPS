import subprocess
import logging
import os
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Updater, CommandHandler, CallbackQueryHandler, CallbackContext
import configparser

# Enable logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO
)
logger = logging.getLogger(__name__)

# Load config
config = configparser.ConfigParser()
config.read('/etc/vpbot/config.ini')
BOT_TOKEN = config['bot']['token']
OWNER_ID = int(config['bot']['owner_id'])

# Fungsi untuk menjalankan perintah shell
def run_command(command):
    try:
        result = subprocess.run(command, shell=True, check=True, text=True, capture_output=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr.strip()}"

# Fungsi untuk start bot
def start(update: Update, context: CallbackContext) -> None:
    if update.effective_user.id != OWNER_ID:
        update.message.reply_text("Maaf, Anda tidak memiliki izin untuk menggunakan bot ini.")
        return

    keyboard = [
        [InlineKeyboardButton("➕ Buat Akun", callback_data='create_account_menu')],
        [InlineKeyboardButton("🗑️ Hapus Akun", callback_data='delete_account')],
        [InlineKeyboardButton("📋 Daftar Akun", callback_data='list_accounts')],
        [InlineKeyboardButton("🔧 Cek Status Layanan", callback_data='status')],
        [InlineKeyboardButton("🔄 Restart Semua Layanan", callback_data='restart_all')],
        [InlineKeyboardButton("💻 Info VPS", callback_data='info_vps')],
        [InlineKeyboardButton("🎨 Ubah Banner SSH", callback_data='change_banner')],
        [InlineKeyboardButton("🔌 Restart NoobzVPN", callback_data='restart_noobzvpn')],
    ]

    reply_markup = InlineKeyboardMarkup(keyboard)
    update.message.reply_text('Halo, Boss! Pilih menu di bawah:', reply_markup=reply_markup)

# Fungsi untuk menangani callback dari tombol
def button(update: Update, context: CallbackContext) -> None:
    query = update.callback_query
    if query.from_user.id != OWNER_ID:
        query.answer("Maaf, Anda tidak memiliki izin.")
        return
        
    query.answer()

    if query.data == 'create_account_menu':
        keyboard = [
            [InlineKeyboardButton("🧪 Buat Akun Trial", callback_data='create_trial')],
            [InlineKeyboardButton("💳 Buat Akun Premium", callback_data='create_premium')],
            [InlineKeyboardButton("⬅️ Kembali", callback_data='back_to_main')],
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text(text='Pilih jenis akun:', reply_markup=reply_markup)

    elif query.data in ['create_trial', 'create_premium']:
        account_type = "trial" if query.data == 'create_trial' else "premium"
        keyboard = [
            [InlineKeyboardButton("SSH / Dropbear", callback_data=f'create_{account_type}_ssh')],
            [InlineKeyboardButton("VMess WS", callback_data=f'create_{account_type}_vmess')],
            [InlineKeyboardButton("Vless WS", callback_data=f'create_{account_type}_vless')],
            [InlineKeyboardButton("Trojan WS", callback_data=f'create_{account_type}_trojan')],
            [InlineKeyboardButton("Shadowsocks WS", callback_data=f'create_{account_type}_ss')],
            [InlineKeyboardButton("NoobzVPN", callback_data=f'create_{account_type}_noobz')],
            [InlineKeyboardButton("⬅️ Kembali", callback_data='create_account_menu')],
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text(text=f'Pilih layanan untuk akun {account_type}:', reply_markup=reply_markup)

    elif query.data.startswith('create_'):
        parts = query.data.split('_')
        account_type = parts[1]
        service_map = {'ssh': '1', 'vmess': '2', 'vless': '3', 'trojan': '4', 'ss': '5', 'noobz': '6'}
        service_name = parts[2]
        service_choice = service_map.get(service_name, '0')

        # Simpan pilihan layanan ke file sementara
        with open('/tmp/service_choice', 'w') as f:
            f.write(service_choice)
        
        command = f'/usr/local/bin/menu create_{account_type}'
        result = run_command(command)
        
        # Hapus file sementara
        if os.path.exists('/tmp/service_choice'):
            os.remove('/tmp/service_choice)
            
        # PECAH OUTPUT MENJADI BEBERAPA PESAN
        messages = result.split('━━━━━━━━━━━━━━━━━━━━━━━')
        
        # Kirim pesan pertama (konfirmasi)
        query.edit_message_text(text=f"✅ Membuat akun {account_type} untuk layanan {service_name}...")
        
        # Kirim setiap bagian sebagai pesan terpisah
        for msg_part in messages:
            stripped_part = msg_part.strip()
            if stripped_part:
                formatted_message = f"━━━━━━━━━━━━━━━━━━━━━━━\n{stripped_part}"
                try:
                    context.bot.send_message(
                        chat_id=update.effective_chat.id,
                        text=f"```{formatted_message}```",
                        parse_mode='MarkdownV2'
                    )
                except Exception:
                    context.bot.send_message(
                        chat_id=update.effective_chat.id,
                        text=formatted_message
                    )

    elif query.data == 'delete_account':
        query.edit_message_text(text="Untuk menghapus akun, silakan gunakan menu 'menu' di terminal VPS dan pilih opsi 3.")

    elif query.data == 'list_accounts':
        result = run_command('/usr/local/bin/menu list_accounts')
        query.edit_message_text(text=f"📋 <b>Daftar Akun:</b>\n\n<pre>{result}</pre>", parse_mode='HTML')

    elif query.data == 'status':
        result = run_command('/usr/local/bin/menu status')
        query.edit_message_text(text=f"🔧 <b>Status Layanan:</b>\n\n<pre>{result}</pre>", parse_mode='HTML')

    elif query.data == 'restart_all':
        query.edit_message_text(text="🔄 Sedang merestart semua layanan...")
        run_command('systemctl restart xray sshws sshws-ssl stunnel4 dropbear nginx badvpn noobzvpn-80 noobzvpn-443 vpbot')
        query.edit_message_text(text="✅ Semua layanan telah di-restart.")

    elif query.data == 'info_vps':
        info = run_command("hostname && cat /etc/os-release | grep PRETTY_NAME | cut -d '\"' -f 2 && curl -s ipinfo.io/ip && uptime -p")
        query.edit_message_text(text=f"💻 <b>Info VPS:</b>\n\n<pre>{info}</pre>", parse_mode='HTML')

    elif query.data == 'change_banner':
        banner_content = """<h3 style="text-align:center"><span style="color:white"><span style="color:white">================================</span></span></h3>

<h3 style="text-align:center"><span style="color:white"><span style="color:lime">AWS SERVER</span></span></h3> 

<h3 style="text-align:center"><span style="color:#ffff00">@Parael1101</span></h3>

<h3 style="text-align:center"><span style="color:red">SCRIPT BY vinstechmy</span></h3>

<h3 style="text-align:center"><span style="color:white">Parael</span></h3>

<h3 style="text-align:center"><span style="color:white"><span style="color:white">================================</span></span></h3>"""
        with open('/etc/motd', 'w') as f:
            f.write(banner_content)
        
        query.edit_message_text(text="✅ Banner SSH berhasil diperbarui dengan template default!")

    elif query.data == 'restart_noobzvpn':
        query.edit_message_text(text="🔌 Sedang merestart NoobzVPN...")
        result = run_command('/usr/local/bin/menu restart_noobzvpn')
        query.edit_message_text(text=f"🔌 <b>Restart NoobzVPN:</b>\n\n<pre>{result}</pre>", parse_mode='HTML')

    elif query.data == 'back_to_main':
        start(update, context) # Kembali ke menu utama

def main() -> None:
    updater = Updater(BOT_TOKEN)
    dispatcher = updater.dispatcher

    dispatcher.add_handler(CommandHandler("start", start))
    dispatcher.add_handler(CallbackQueryHandler(button))

    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
