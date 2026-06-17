#!/bin/bash
set -e

VM_DIR="/.qemu-vm"

# Allow the choice to be passed as an argument (needed when run via
# `curl | bash`, since stdin is occupied by the piped script and an
# interactive `read` can't get input from the terminal in that case).
arg="$1"
choice=""

case "$arg" in
  ubuntu|Ubuntu|1) choice="1" ;;
  debian|Debian|2) choice="2" ;;
esac

if [ -z "$choice" ]; then
  echo "=================================="
  echo "  QEMU VM Launcher"
  echo "=================================="
  echo "  1) Ubuntu 22.04 (Jammy)"
  echo "  2) Debian 12 (Bookworm)"
  echo "=================================="

  # When run as `curl | bash`, stdin (fd 0) is the piped script itself,
  # not the keyboard, so a normal `read` can't get input here. Reading
  # from /dev/tty instead talks to the actual terminal directly, which
  # is what lets a single curl|bash command still show an interactive
  # prompt. We actually try to open it (rather than just checking the
  # path exists) since some environments have no controlling terminal
  # at all, in which case opening /dev/tty fails outright.
  if { exec 3<>/dev/tty; } 2>/dev/null; then
    read -p "Select an option [1-2]: " choice <&3
    exec 3<&-
  else
    echo "No terminal available to read input from."
    echo "Re-run with an argument instead, e.g.:"
    echo "  bash vm-launcher.sh ubuntu"
    echo "  bash vm-launcher.sh debian"
    exit 1
  fi
fi

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
