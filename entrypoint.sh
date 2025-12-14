#!/bin/bash
set -euo pipefail

log(){ echo "[$(date +'%F %T')] $*"; }

# 1) 必要目录存在
mkdir -p /var/lib/cobbler /var/www/cobbler /var/lib/dhcpd /var/lib/tftpboot /var/cobbler/iso

# 2) 只做基础 settings.yaml 参数化（你也可以不做，纯手改也行）
SETTINGS=/etc/cobbler/settings.yaml
SERVER="${SERVER:-${SERVER_IP_V4:-}}"

if [ -n "$SERVER" ] && [ -f "$SETTINGS" ]; then
  sed -i "s/^server: .*/server: ${SERVER}/g" "$SETTINGS" || true
fi
if [ -n "${SERVER_IP_V4:-}" ] && [ -f "$SETTINGS" ]; then
  sed -i "s/^next_server_v4: .*/next_server_v4: ${SERVER_IP_V4}/g" "$SETTINGS" || true
fi
if [ -n "${SERVER_IP_V6:-}" ] && [ -f "$SETTINGS" ]; then
  sed -i "s/^next_server_v6: .*/next_server_v6: ${SERVER_IP_V6}/g" "$SETTINGS" || true
fi

# 3) 一次性把菜单“默认本地+30秒”写到可写模板覆盖目录（持久化）
#    覆盖目录在 /var/lib/cobbler/templates，随 /var/lib/cobbler volume 持久化
PKG_TPL="/usr/lib/python3.9/site-packages/cobbler/data/templates/cheetah"
OVR_BASE="/var/lib/cobbler/templates"
OVR_TPL="${OVR_BASE}/cheetah"

if [ ! -d "${OVR_TPL}/boot_loader_conf" ]; then
  log "init template override dir: ${OVR_TPL}"
  mkdir -p "${OVR_BASE}"
  cp -a "${PKG_TPL}" "${OVR_BASE}/"
fi

PXE_MENU="${OVR_TPL}/boot_loader_conf/pxe_menu.template"
GRUB_MENU="${OVR_TPL}/boot_loader_conf/grub_menu.template"

if [ -f "$PXE_MENU" ]; then
  sed -i 's/^TIMEOUT .*/TIMEOUT 300/g' "$PXE_MENU"
  sed -i 's/^ONTIMEOUT .*/ONTIMEOUT local/g' "$PXE_MENU"
  sed -i 's/^DEFAULT .*/DEFAULT local/g' "$PXE_MENU"
fi

if [ -f "$GRUB_MENU" ]; then
  grep -q '^set timeout=' "$GRUB_MENU" || sed -i '1iset timeout=30' "$GRUB_MENU"
  grep -q '^set default=' "$GRUB_MENU" || sed -i '1iset default="local"' "$GRUB_MENU"
fi

log "templates ready: default local boot, timeout 30s (UEFI+BIOS)"

# 4) 起服务（无 systemd）
log "starting httpd..."
httpd -DFOREGROUND &
HTTPD_PID=$!

log "starting tftp..."
/usr/sbin/in.tftpd -L -s /var/lib/tftpboot &
TFTP_PID=$!

log "starting rsyncd..."
rsync --daemon --no-detach &
RSYNC_PID=$!

# dhcpd：如果你要它跑，就跑；如果你想外部 DHCP，就可以注释掉这一段
touch /var/lib/dhcpd/dhcpd.leases || true
log "starting dhcpd..."
/usr/sbin/dhcpd -4 -f -cf /etc/dhcp/dhcpd.conf -lf /var/lib/dhcpd/dhcpd.leases ${DHCP_IFACE:-} &
DHCPD_PID=$!

log "starting cobblerd..."
/usr/bin/cobblerd -F &
COBBLERD_PID=$!

trap 'log "stopping..."; kill $COBBLERD_PID $HTTPD_PID $TFTP_PID $RSYNC_PID $DHCPD_PID 2>/dev/null || true; exit 0' SIGINT SIGTERM

# 保活：你也可以改成 tail cobbler.log
wait -n
