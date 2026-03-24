sudo apt install
ssh-keygen -t ed25519 -C "project-v11@htg" -f ~/.ssh/id_project_v11
cat ~/.ssh/id_project_v11.pub
sudo apt install wireguard-tools -y
wg genkey | tee ec2_private.key
cat ec2_private.key | wg pubkey | tee ec2_public.key
wg genkey | tee proxmox_private.key
cat proxmox_private.key | wg pubkey | tee proxmox_public.key
cat ec2_private.key
sudo appt install tree
sudo apt install tree
tree
#!/bin/bash
# =====================================================
# AUTO GENERATE - Project V11 Infrastructure
# Tao tu dong toan bo folder + files Terraform
# Chay: chmod +x generate.sh && ./generate.sh
# =====================================================
set -euo pipefail
PROJECT="project-v11"
echo "=========================================="
echo "  Tao du an: $PROJECT"
echo "=========================================="
# === 1. Tao cau truc folder ===
mkdir -p $PROJECT/.github/workflows
mkdir -p $PROJECT/modules/aws-infra
mkdir -p $PROJECT/modules/proxmox-vm
cd $PROJECT
echo "[1/13] Tao folder structure... DONE"
# === 2. backend.tf ===
cat > backend.tf <<'EOF'
# ============================================
# backend.tf - HCP Terraform (Terraform Cloud)
# Quan ly state file tap trung, bao mat bien so
# ============================================

terraform {
  cloud {
    organization = "htg-org-name"

    workspaces {
      name = "project-v11-production"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.38"
    }
  }

  required_version = ">= 1.6.0"
}
EOF

echo "[2/13] backend.tf... DONE"
# === 3. providers.tf ===
cat > providers.tf <<'EOF'
# ============================================
# providers.tf - Cau hinh Providers
# ============================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "project-v11"
      Environment = "production"
      ManagedBy   = "terraform"
      Team        = var.team_name
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true
}
EOF

echo "[3/13] providers.tf... DONE"
# === 4. variables.tf (Root) ===
cat > variables.tf <<'EOF'
# ============================================
# variables.tf - Bien so duoc quan ly tren HCP
# ============================================

# === AWS Variables ===
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "team_name" {
  description = "Ten nhom hien thi tren Web App"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key inject vao EC2 va Proxmox VM"
  type        = string
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.micro"
}

# === Proxmox Variables ===
variable "proxmox_api_url" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "vm_ip" {
  type    = string
  default = "192.168.1.100/24"
}

variable "vm_gateway" {
  type    = string
  default = "192.168.1.1"
}

# === Database ===
variable "db_password" {
  type      = string
  sensitive = true
}

# === WireGuard ===
variable "wg_private_key_ec2" {
  type      = string
  sensitive = true
}

variable "wg_public_key_ec2" {
  type = string
}

variable "wg_private_key_proxmox" {
  type      = string
  sensitive = true
}

variable "wg_public_key_proxmox" {
  type = string
}

variable "proxmox_public_ip" {
  type        = string
  description = "Public IP cua Proxmox server (WireGuard Endpoint)"
}
EOF

echo "[4/13] variables.tf... DONE"
# === 5. main.tf (Root) ===
cat > main.tf <<'EOF'
# ============================================
# main.tf - Root Module: Goi AWS + Proxmox
# ============================================

module "aws_infra" {
  source = "./modules/aws-infra"

  project_name          = "project-v11"
  instance_type         = var.ec2_instance_type
  ssh_public_key        = var.ssh_public_key
  team_name             = var.team_name
  db_password           = var.db_password
  wg_private_key_ec2    = var.wg_private_key_ec2
  wg_public_key_proxmox = var.wg_public_key_proxmox
  proxmox_public_ip     = var.proxmox_public_ip
}

module "proxmox_vm" {
  source = "./modules/proxmox-vm"

  proxmox_node           = var.proxmox_node
  vm_ip                  = var.vm_ip
  vm_gateway             = var.vm_gateway
  ssh_public_key         = var.ssh_public_key
  db_password            = var.db_password
  wg_private_key_proxmox = var.wg_private_key_proxmox
  wg_public_key_ec2      = var.wg_public_key_ec2
  ec2_public_ip          = module.aws_infra.ec2_public_ip
}
EOF

echo "[5/13] main.tf... DONE"
# === 6. outputs.tf (Root) ===
cat > outputs.tf <<'EOF'
output "web_app_url" {
  description = "URL truy cap Web App qua ALB"
  value       = "http://${module.aws_infra.alb_dns_name}"
}

output "ec2_public_ip" {
  description = "Public IP cua EC2"
  value       = module.aws_infra.ec2_public_ip
}

output "proxmox_vm_ip" {
  description = "IP cua VM Proxmox"
  value       = module.proxmox_vm.vm_ip_address
}

output "wireguard_tunnel" {
  description = "WireGuard VPN Tunnel"
  value       = "EC2 (10.0.0.1) <---VPN---> Proxmox (10.0.0.2)"
}
EOF

echo "[6/13] outputs.tf... DONE"
# === 7. terraform.tfvars.example ===
cat > terraform.tfvars.example <<'EOF'
# =============================================
# terraform.tfvars.example
# KHONG commit file terraform.tfvars that!
# Cac gia tri nay khai bao tren HCP Variables
# =============================================

aws_region        = "ap-southeast-1"
ec2_instance_type = "t3.micro"
team_name         = "HTG-Team"

# Proxmox
proxmox_api_url   = "https://192.168.1.10:8006/api2/json"
proxmox_api_token = "terraform@pam!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_node      = "pve"
vm_ip             = "192.168.1.100/24"
vm_gateway        = "192.168.1.1"

# Database
db_password = "StrongP@ssw0rd!"

# WireGuard (tao bang: wg genkey | tee private.key | wg pubkey > public.key)
wg_private_key_ec2     = "EC2_PRIVATE_KEY_HERE"
wg_public_key_ec2      = "EC2_PUBLIC_KEY_HERE"
wg_private_key_proxmox = "PROXMOX_PRIVATE_KEY_HERE"
wg_public_key_proxmox  = "PROXMOX_PUBLIC_KEY_HERE"

# SSH
ssh_public_key    = "ssh-ed25519 AAAAC3Nza... your-email@example.com"
proxmox_public_ip = "YOUR_PROXMOX_PUBLIC_IP"
EOF

echo "[7/13] terraform.tfvars.example... DONE"
# === 8. modules/aws-infra/variables.tf ===
cat > modules/aws-infra/variables.tf <<'EOF'
variable "project_name" {
  type    = string
  default = "project-v11"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ssh_public_key" {
  type = string
}

variable "team_name" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "wg_private_key_ec2" {
  type      = string
  sensitive = true
}

variable "wg_public_key_proxmox" {
  type = string
}

variable "proxmox_public_ip" {
  type = string
}
EOF

echo "[8/13] modules/aws-infra/variables.tf... DONE"
# === 9. modules/aws-infra/main.tf ===
cat > modules/aws-infra/main.tf <<'EOF'
# ============================================
# modules/aws-infra/main.tf
# VPC + ALB + EC2 Web Server + WireGuard
# ============================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ========== VPC ==========
resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-${count.index + 1}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ========== SECURITY GROUPS ==========
resource "aws_security_group" "alb" {
  name   = "${var.project_name}-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2" {
  name   = "${var.project_name}-ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ========== EC2 INSTANCE ==========
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = templatefile("${path.module}/user-data.sh", {
    team_name          = var.team_name
    db_host            = "10.0.0.2"
    db_password        = var.db_password
    wg_private_key     = var.wg_private_key_ec2
    wg_peer_public_key = var.wg_public_key_proxmox
    wg_peer_endpoint   = "${var.proxmox_public_ip}:51820"
  })

  tags = { Name = "${var.project_name}-web-server" }
}

# ========== APPLICATION LOAD BALANCER ==========
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web.id
  port             = 5000
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
EOF

echo "[9/13] modules/aws-infra/main.tf... DONE"
# === 10. modules/aws-infra/outputs.tf ===
cat > modules/aws-infra/outputs.tf <<'EOF'
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "ec2_public_ip" {
  value = aws_instance.web.public_ip
}

output "ec2_instance_id" {
  value = aws_instance.web.id
}
EOF

echo "[10/13] modules/aws-infra/outputs.tf... DONE"
# === 11. modules/aws-infra/user-data.sh ===
cat > modules/aws-infra/user-data.sh <<'USERDATA'
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
Endpoint            = ${wg_peer_endpoint}
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
USERDATA

echo "[11/13] modules/aws-infra/user-data.sh... DONE"
# === 12. modules/proxmox-vm/variables.tf ===
cat > modules/proxmox-vm/variables.tf <<'EOF'
variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "vm_hostname" {
  type    = string
  default = "db-server-v11"
}

variable "vm_id" {
  type    = number
  default = 200
}

variable "template_vm_id" {
  type    = number
  default = 9000
  description = "VM ID cua Ubuntu Cloud-Init template"
}

variable "vm_ip" {
  type    = string
  default = "192.168.1.100/24"
}

variable "vm_gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "ssh_public_key" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "wg_private_key_proxmox" {
  type      = string
  sensitive = true
}

variable "wg_public_key_ec2" {
  type = string
}

variable "ec2_public_ip" {
  type = string
}
EOF

echo "[12/13] modules/proxmox-vm/variables.tf... DONE"
# === 13. modules/proxmox-vm/main.tf ===
cat > modules/proxmox-vm/main.tf <<'EOF'
# ============================================
# modules/proxmox-vm/main.tf
# Provider: bpg/proxmox
# ============================================

resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "cloud-init-v11.yml"
    data = templatefile("${path.module}/cloud-init.cfg", {
      hostname           = var.vm_hostname
      ssh_public_key     = var.ssh_public_key
      db_password        = var.db_password
      wg_private_key     = var.wg_private_key_proxmox
      wg_peer_public_key = var.wg_public_key_ec2
      ec2_public_ip      = var.ec2_public_ip
    })
  }
}

resource "proxmox_virtual_environment_vm" "db_server" {
  name      = var.vm_hostname
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  clone {
    vm_id = var.template_vm_id
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = var.vm_ip
        gateway = var.vm_gateway
      }
    }
    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }
    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }

  operating_system {
    type = "l26"
  }

  started = true
}
EOF

echo "[13/13] modules/proxmox-vm/main.tf... DONE"
# === 14. modules/proxmox-vm/outputs.tf ===
cat > modules/proxmox-vm/outputs.tf <<'EOF'
output "vm_ip_address" {
  value = var.vm_ip
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.db_server.vm_id
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.db_server.name
}
EOF

# === 15. modules/proxmox-vm/cloud-init.cfg ===
cat > modules/proxmox-vm/cloud-init.cfg <<'EOF'
#cloud-config
hostname: ${hostname}
manage_etc_hosts: true
timezone: Asia/Ho_Chi_Minh

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}

package_update: true
packages:
  - postgresql
  - postgresql-contrib
  - wireguard
  - net-tools

runcmd:
  - |
    echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
    echo "host all all 10.0.0.0/24 md5" >> /etc/postgresql/14/main/pg_hba.conf
    systemctl restart postgresql

  - |
    sudo -u postgres psql -c "CREATE USER appuser WITH PASSWORD '${db_password}';"
    sudo -u postgres psql -c "CREATE DATABASE project_v11 OWNER appuser;"
    sudo -u postgres psql -d project_v11 -c "
      CREATE TABLE entries (
        id SERIAL PRIMARY KEY,
        team_name VARCHAR(100) NOT NULL,
        entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
        note TEXT,
        created_at TIMESTAMP DEFAULT NOW()
      );
      GRANT ALL PRIVILEGES ON TABLE entries TO appuser;
      GRANT USAGE, SELECT ON SEQUENCE entries_id_seq TO appuser;
    "

  - |
    cat > /etc/wireguard/wg0.conf <<WGEOF
    [Interface]
    PrivateKey = ${wg_private_key}
    Address    = 10.0.0.2/24
    ListenPort = 51820
    PostUp     = sysctl -w net.ipv4.ip_forward=1

    [Peer]
    PublicKey           = ${wg_peer_public_key}
    AllowedIPs          = 10.0.0.1/32
    PersistentKeepalive = 25
    WGEOF
    chmod 600 /etc/wireguard/wg0.conf
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0

  - |
    cat > /usr/local/bin/wg-watchdog.sh <<'SCRIPT'
    #!/bin/bash
    if ! ping -c 2 -W 3 10.0.0.1 > /dev/null 2>&1; then
        echo "[$(date)] WireGuard down - Restarting..."
        systemctl restart wg-quick@wg0
        sleep 5
        ping -c 2 -W 3 10.0.0.1 > /dev/null 2>&1 && \
          echo "[$(date)] Reconnected OK" || echo "[$(date)] FAILED"
    else
        echo "[$(date)] WireGuard OK"
    fi
    SCRIPT
    chmod +x /usr/local/bin/wg-watchdog.sh
    echo "*/5 * * * * root /usr/local/bin/wg-watchdog.sh >> /var/log/wg-watchdog.log 2>&1" \
      > /etc/cron.d/wg-watchdog

final_message: "Cloud-Init completed. PostgreSQL + WireGuard ready!"
EOF

# === 16. .github/workflows/terraform-deploy.yml ===
cat > .github/workflows/terraform-deploy.yml <<'EOF'
name: 'Terraform Deploy Pipeline'

on:
  pull_request:
    branches: [main]
    paths: ['**.tf', 'modules/**']
  push:
    branches: [main]

permissions:
  contents: read
  pull-requests: write

env:
  TF_CLOUD_ORGANIZATION: "htg-org-name"
  TF_WORKSPACE: "project-v11-production"
  TF_API_TOKEN: "${{ secrets.TF_API_TOKEN }}"

jobs:
  plan:
    name: 'Terraform Plan'
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
      - run: terraform init
      - run: terraform fmt -check -recursive
      - run: terraform validate
      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color
        continue-on-error: true

      - name: Comment Plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan
            \`\`\`\n${{ steps.plan.outputs.stdout }}\n\`\`\`
            *Pushed by: @${{ github.actor }}*
            **CTO: Vui long review va Approve PR nay!**`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo, body: output
            });

      - name: Notify CTO via Email
        uses: dawidd6/action-send-mail@v3
        with:
          server_address: smtp.gmail.com
          server_port: 465
          secure: true
          username: ${{ secrets.MAIL_USERNAME }}
          password: ${{ secrets.MAIL_PASSWORD }}
          subject: "[Project V11] PR #${{ github.event.number }} can phe duyet"
          to: cto@company.com
          from: terraform-bot@company.com
          body: |
            Co Pull Request moi can review:
            PR: ${{ github.event.pull_request.html_url }}
            Author: ${{ github.actor }}

  notify-deploy:
    name: 'Deploy Triggered'
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - run: |
          echo "Code merged! HCP Terraform se tu dong chay plan."
          echo "CTO vao app.terraform.io de Confirm & Apply."
EOF

echo "[16/16] .github/workflows/terraform-deploy.yml... DONE"
# === 17. .github/CODEOWNERS ===
cat > .github/CODEOWNERS <<'EOF'
# CTO phai review moi thay doi
* @cto-github-username
*.tf @cto-github-username
EOF

# === 18. .gitignore ===
cat > .gitignore <<'EOF'
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfvars
!terraform.tfvars.example
.terraform.lock.hcl

# Keys - KHONG DUOC COMMIT
*.key
*.pem
id_*

# OS
.DS_Store
Thumbs.db
EOF

echo ""
echo "=========================================="
echo "  HOAN THANH! Cau truc du an:"
echo "=========================================="
find . -type f | sort | head -30
echo ""
echo "=========================================="
echo "  Buoc tiep theo:"
echo "  1. cd $PROJECT"
echo "  2. git init && git add -A"
echo "  3. git commit -m 'Initial: Project V11 Infrastructure'"
echo "  4. git remote add origin https://github.com/YOUR_ORG/$PROJECT.git"
echo "  5. git push -u origin main"
echo "=========================================="
tree
git init && git add -A
git commit -m 'Initial: Project V11 Infrastructure'
ll
cd project-v11/
chmod +x generate.sh
cd ../
ll
cd project-v11/
ll
tree
cd ../
vim generate-project-v11.sh
chmod +x generate.sh
sudo chmod +x generate.sh
sudo chmod +x generate-project-v11.sh 
./generate-project-v11.sh 
cd project-v11
sudo git init && git add -A
git init
git commit -m 'Initial: Project V11 Infrastructure'
git config --global user.email "hoatrancntt@gmail.com"
git config --global user.name "hoatrancntt-devops"
git commit -m 'Initial: Project V11 Infrastructure
git commit -m 'Initial: Project V11 Infrastructure'
git push -u origin main
git remote add origin https://github.com/YOUR_ORG/project-v11.git
git push -u origin main
git remote add origin https://github.com/hoatrancntt-devops/project-v11.git
git push -u origin main
git remote add origin https://github.com/hoatrancntt-devops/project-v11.git
git branch
git status
git add .
git commit -m "Initial commit"
git branch -M main
git push -u origin main
git remote add origin https://github.com/hoatrancntt-devops/project-v11.git
git add .
git commit -m "Initial commit"
git branch -M main
git remote set-url origin https://github.com/hoatrancntt-devops/project-v11.git
git push -u origin main
git remote set-url origin https://github.com/hoatrancntt-devops/project-v11-production.git
git branch -M main
git push -u origin main
git pull
git branch --set-upstream-to=origin/main main
git push
git branch
git pull origin main
git config pull.rebase
git add .
git commit -m "Merge remote main"
git push
git push -f
tree
ll
cd modules/aws-infra/
ll
vim user-data.sh 
sudo chmod +x user-data.sh 
./user-data.sh 
sudo ./user-data.sh 
