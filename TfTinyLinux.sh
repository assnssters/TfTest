#!/bin/bash
set -e

# Tạo thư mục làm việc
WORKDIR=/tmp/tinycore16
mkdir -p "$WORKDIR" && cd "$WORKDIR"

echo "[*] Tải Tiny Core Linux 16.1 (64-bit)..."
wget -q http://tinycorelinux.net/16.x/x86_64/release/distribution_files/vmlinuz64
wget -q http://tinycorelinux.net/16.x/x86_64/release/distribution_files/corepure64.gz

echo "[*] Giải nén corepure64.gz..."
mkdir rootfs && cd rootfs
zcat ../corepure64.gz | cpio -idmu

echo "[*] Cấu hình SSH + HTTP + auto dd /dev/sda..."
cat << 'EOF' > etc/init.d/bootlocal.sh
#!/bin/sh
echo "root:12143" | chpasswd

# Start dropbear SSH (nếu đã tích hợp)
[ -x /usr/local/etc/init.d/dropbear ] && /usr/local/etc/init.d/dropbear start

# Start HTTP server
httpd -p 80 -h /var/www &
mkdir -p /var/log && touch /var/log/httpd.log
tail -f /var/log/httpd.log &

# Ghi đè /dev/sda nếu có override.gz
if [ -f /var/www/override.gz ]; then
  echo "[*] Ghi đè /dev/sda từ override.gz"
  gzip -dc /var/www/override.gz | dd of=/dev/sda bs=4M status=progress
  echo "[*] Ghi đè xong, khởi động lại..."
  reboot -f
fi
EOF

chmod +x etc/init.d/bootlocal.sh
mkdir -p var/www
echo "<html><h1>Đã khởi động TinyCore 16.1!</h1></html>" > var/www/index.html

echo "[*] Đóng gói initramfs custom.gz..."
find . | cpio -o -H newc | gzip -9 > ../custom.gz
cd ..

echo "[*] Cài kexec (nếu chưa có)..."
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y kexec-tools >/dev/null 2>&1 || yum install -y kexec-tools

echo "[*] Boot Tiny Core Linux từ RAM bằng kexec..."
kexec -l vmlinuz64 --initrd=custom.gz --command-line="console=ttyS0 quiet init=/etc/init.d/bootlocal.sh"
sync
sleep 3
echo "[!] Sẽ boot sang Tiny Core ngay sau đây..."
kexec -e
