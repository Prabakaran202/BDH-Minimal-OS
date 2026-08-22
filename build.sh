#!/bin/bash

TARGET=$1
ROOTFS="bdh_root"

# கமாண்ட் சரியாக கொடுக்கப்பட்டுள்ளதா என சரிபார்க்க
if [ -z "$TARGET" ]; then
    echo "Usage: ./build.sh [phone | laptop]"
    exit 1
fi

echo "==============================================="
echo "  Building BDH Minimal OS for: $TARGET"
echo "==============================================="

# 1. பழைய ஃபைல்களை அழித்துவிட்டு புதிதாக போல்டர்களை உருவாக்குதல்
echo "[1/4] Preparing Root Filesystem..."
rm -rf $ROOTFS initramfs.cpio.gz bdh-os.iso iso/
mkdir -p $ROOTFS/{bin,dev,etc,proc,sys,root}

# 2. C கோடை கம்பைல் செய்தல் (Termux Auto-detect)
echo "[2/4] Compiling bdh_init.c..."
if command -v proot-distro &> /dev/null; then
    echo "   -> Termux detected! Compiling via Alpine automatically..."
    proot-distro login alpine -- sh -c "cd $PWD && gcc -static bdh_init.c -o $ROOTFS/init"
else
    gcc -static bdh_init.c -o $ROOTFS/init
fi

if [ $? -ne 0 ]; then
    echo "Error: Compilation failed!"
    exit 1
fi

# 3. ஹார்டுவேருக்கு ஏற்ற கர்னல் மற்றும் BusyBox டவுன்லோட் செய்தல்
echo "[3/4] Downloading Kernel and BusyBox..."
if [ "$TARGET" == "laptop" ]; then
    wget -q -O bzImage-x86 https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/netboot/vmlinuz-lts
    wget -q -O $ROOTFS/bin/busybox https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
elif [ "$TARGET" == "phone" ]; then
    wget -q -O bzImage-arm https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/aarch64/netboot/vmlinuz-lts
    wget -q -O $ROOTFS/bin/busybox https://busybox.net/downloads/binaries/1.35.0-aarch64-linux-musl/busybox
else
    echo "Error: Invalid target! Use 'phone' or 'laptop'."
    exit 1
fi
chmod +x $ROOTFS/bin/busybox

# 4. OS-ஐ பேக் செய்தல் (initramfs)
echo "[4/4] Packing initramfs..."
cd $ROOTFS
find . | cpio -ov -H newc | gzip -9 > ../initramfs.cpio.gz 2>/dev/null
cd ..

# 5. லேப்டாப் என்றால் ISO ஆக மாற்றுதல்
if [ "$TARGET" == "laptop" ]; then
    echo "Creating Bootable ISO for Laptop..."
    mkdir -p iso/boot/grub
    cp bzImage-x86 iso/boot/
    cp initramfs.cpio.gz iso/boot/
    cat <<EOF > iso/boot/grub/grub.cfg
set timeout=5
set default=0
menuentry "BDH Minimal OS (x86_64)" {
    linux /boot/bzImage-x86 console=tty0 init=/init
    initrd /boot/initramfs.cpio.gz
}
EOF
    grub-mkrescue -o bdh-os.iso iso/ 2>/dev/null
    echo -e "\n✅ Success! 'bdh-os.iso' is ready for Ventoy!"
else
    echo -e "\n✅ Success! ARM OS is ready."
    echo "Run: qemu-system-aarch64 -M virt -cpu cortex-a53 -nographic -kernel bzImage-arm -initrd initramfs.cpio.gz -append \"console=ttyAMA0 init=/init\" -m 256M"
fi
