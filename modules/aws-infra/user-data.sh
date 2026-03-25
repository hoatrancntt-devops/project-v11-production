#!/bin/bash
set -euo pipefail

# === 1. Cai dat packages ===
apt-get update -y
apt-get install -y wireguard python3 python3-pip python3-venv postgresql-client

# === 2. Cau hinh WireGuard VPN ===
cat > /etc/wireguard/wg0.conf <<WGEOF
[Interface]
PrivateKey = ${wg_private_key}
Address    = 10.0.0.1/24
ListenPort = 51820
PostUp     = sysctl -w net.ipv4.ip_forward=1
PostDown   = sysctl -w net.ipv4.ip_forward=0

[Peer]
PublicKey           = ${wg_peer_public_key}
# EC2 la server - KHONG can Endpoint (Proxmox se ket noi den EC2)
AllowedIPs          = 10.0.0.2/32
PersistentKeepalive = 25
WGEOF

chmod 600 /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# === 3. Auto-Reconnect VPN moi 5 phut ===
cat > /usr/local/bin/wg-watchdog.sh <<'WATCHDOG'
#!/bin/bash
if ! ping -c 2 -W 3 10.0.0.2 > /dev/null 2>&1; then
    echo "[$(date)] WireGuard down - Restarting..."
    systemctl restart wg-quick@wg0
    sleep 5
    if ping -c 2 -W 3 10.0.0.2 > /dev/null 2>&1; then
        echo "[$(date)] Reconnected OK"
    else
        echo "[$(date)] Reconnect FAILED"
    fi
else
    echo "[$(date)] WireGuard OK"
fi
WATCHDOG

chmod +x /usr/local/bin/wg-watchdog.sh
echo "*/5 * * * * root /usr/local/bin/wg-watchdog.sh >> /var/log/wg-watchdog.log 2>&1" \
  > /etc/cron.d/wg-watchdog

# === 4. Cai Flask Web App ===
mkdir -p /opt/webapp && cd /opt/webapp
python3 -m venv venv && source venv/bin/activate
pip install flask psycopg2-binary gunicorn

cat > /opt/webapp/app.py <<'APPEOF'
from flask import Flask, request, jsonify, render_template_string
import psycopg2, os
from datetime import datetime

app = Flask(__name__)

DB = {
    'host': os.getenv('DB_HOST', '10.0.0.2'),
    'port': 5432, 'database': 'project_v11',
    'user': 'appuser', 'password': os.getenv('DB_PASSWORD')
}

HTML = """<!DOCTYPE html><html><head>
<title>Project V11 - {{ team }}</title>
<style>
body{font-family:Arial;max-width:600px;margin:50px auto;background:#f5f5f5}
.card{background:white;padding:30px;border-radius:10px;box-shadow:0 2px 10px rgba(0,0,0,.1)}
h1{color:#333;text-align:center}
input,button{width:100%;padding:12px;margin:8px 0;border:1px solid #ddd;
  border-radius:5px;box-sizing:border-box}
button{background:#4CAF50;color:white;border:none;cursor:pointer;font-size:16px}
.entry{background:#e8f5e9;padding:10px;margin:5px 0;border-radius:5px}
.ok{background:#c8e6c9;color:#2e7d32;text-align:center;padding:5px;border-radius:3px;font-size:12px}
.err{background:#ffcdd2;color:#c62828;text-align:center;padding:5px;border-radius:3px;font-size:12px}
</style></head><body><div class="card">
<h1>{{ team }}</h1>
<p style="text-align:center;color:#666">Nhap lieu -> PostgreSQL (Proxmox)</p>
<div id="st"></div>
<form id="f">
  <input id="t" value="{{ team }}" readonly>
  <input type="date" id="d" value="{{ today }}">
  <input id="n" placeholder="Ghi chu (tuy chon)">
  <button type="submit">Gui Du Lieu</button>
</form>
<div id="entries"></div>
</div><script>
document.getElementById('f').onsubmit=async e=>{e.preventDefault();
const r=await fetch('/api/submit',{method:'POST',
headers:{'Content-Type':'application/json'},
body:JSON.stringify({team:document.getElementById('t').value,
date:document.getElementById('d').value,
note:document.getElementById('n').value})});
const d=await r.json();const s=document.getElementById('st');
s.textContent=d.message;s.className=d.success?'ok':'err';
if(d.success)loadE()};
async function loadE(){const r=await fetch('/api/entries');
const d=await r.json();document.getElementById('entries').innerHTML=
d.map(e=>'<div class="entry">'+e.team_name+' | '+e.entry_date+
' | '+(e.note||'')+'</div>').join('')}loadE();
</script></body></html>"""

@app.route('/')
def index():
    return render_template_string(HTML,
        team='${team_name}', today=datetime.now().strftime('%Y-%m-%d'))

@app.route('/api/submit', methods=['POST'])
def submit():
    data = request.json
    try:
        conn = psycopg2.connect(**DB)
        cur = conn.cursor()
        cur.execute("INSERT INTO entries (team_name, entry_date, note) VALUES (%s,%s,%s)",
                    (data['team'], data['date'], data.get('note', '')))
        conn.commit(); cur.close(); conn.close()
        return jsonify(success=True, message='Da luu thanh cong!')
    except Exception as e:
        return jsonify(success=False, message=f'Loi: {str(e)}')

@app.route('/api/entries')
def entries():
    try:
        conn = psycopg2.connect(**DB)
        cur = conn.cursor()
        cur.execute("SELECT team_name, entry_date::text, note FROM entries ORDER BY id DESC LIMIT 20")
        rows = [{'team_name':r[0],'entry_date':r[1],'note':r[2]} for r in cur.fetchall()]
        cur.close(); conn.close()
        return jsonify(rows)
    except: return jsonify([])

if __name__ == '__main__': app.run(host='0.0.0.0', port=5000)
APPEOF

# === 5. Systemd service ===
cat > /etc/systemd/system/webapp.service <<SVCEOF
[Unit]
Description=Project V11 Flask Web App
After=network.target wg-quick@wg0.service
[Service]
Type=simple
WorkingDirectory=/opt/webapp
Environment=DB_HOST=10.0.0.2
Environment=DB_PASSWORD=${db_password}
ExecStart=/opt/webapp/venv/bin/gunicorn -w 2 -b 0.0.0.0:5000 app:app
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload && systemctl enable webapp && systemctl start webapp
echo "=== EC2 Bootstrap DONE ==="
