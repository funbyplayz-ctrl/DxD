#!/bin/bash
set -e

VM_DIR="/.qemu-vm"

echo "=================================="
echo "  QEMU VM Launcher"
echo "=================================="
echo "  1) Ubuntu 22.04 (Jammy)"
echo "  2) Debian 12 (Bookworm)"
echo "=================================="
read -p "Select an option [1-2]: " choice

case "$choice" in
  1)
    echo "[*] Setting up Ubuntu 22.04..."
    apt-get update && apt-get install -y qemu-system-x86 qemu-utils wget genisoimage
    mkdir -p "$VM_DIR"

    if [ ! -f "$VM_DIR/ubuntu.qcow2" ]; then
      echo "[*] Downloading Ubuntu image..."
      wget -q --show-progress https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O "$VM_DIR/ubuntu.qcow2"
      qemu-img resize "$VM_DIR/ubuntu.qcow2" 15G
    else
      echo "[*] Existing Ubuntu image found, skipping download."
    fi

    printf "#cloud-config\npassword: ubuntu\nchpasswd: { expire: False }\nssh_pwauth: True\n" > "$VM_DIR/user-data"
    touch "$VM_DIR/meta-data"
    mkisofs -output "$VM_DIR/seed.iso" -volid cidata -joliet -rock "$VM_DIR/user-data" "$VM_DIR/meta-data"

    cat > /launch.sh << 'EOF'
#!/bin/bash
pkill -9 -f qemu-system-x86_64 2>/dev/null || true
clear
echo "Booting Ubuntu (512M RAM)... Type Ctrl+A then X to exit."
echo "Login: ubuntu / ubuntu"
qemu-system-x86_64 -m 512M -smp 1 \
  -drive file=/.qemu-vm/ubuntu.qcow2,format=qcow2,if=virtio \
  -drive file=/.qemu-vm/seed.iso,format=raw,media=cdrom \
  -nographic -net nic,model=virtio -net user
EOF
    chmod +x /launch.sh
    clear
    /launch.sh
    ;;

  2)
    echo "[*] Setting up Debian 12..."
    apt-get update && apt-get install -y qemu-system-x86 qemu-utils wget
    mkdir -p "$VM_DIR"

    if [ ! -f "$VM_DIR/debian.qcow2" ]; then
      echo "[*] Downloading Debian image..."
      wget -q --show-progress https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2 -O "$VM_DIR/debian.qcow2"
      qemu-img resize "$VM_DIR/debian.qcow2" 20G
    else
      echo "[*] Existing Debian image found, skipping download."
    fi

    cat > /launch.sh << 'EOF'
#!/bin/bash
pkill -9 -f qemu-system-x86_64 2>/dev/null || true
clear
echo "Booting Debian (7905M RAM)... Type Ctrl+A then X to exit."
echo "NOTE: this image has no preconfigured login (nocloud, no cloud-init seed)."
qemu-system-x86_64 -m 7905M -smp 2 \
  -drive file=/.qemu-vm/debian.qcow2,if=virtio \
  -nographic -net nic,model=virtio -net user
EOF
    chmod +x /launch.sh
    clear
    /launch.sh
    ;;

  *)
    echo "Invalid option. Please run again and choose 1 or 2."
    exit 1
    ;;
esac
