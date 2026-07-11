#!/bin/bash

# =====================================================================
# NTFS Read/Write Fixer & Mounter
# =====================================================================
# This script detects all NTFS partitions on the system, checks if they
# are mounted, unmounts them if necessary, runs ntfsfix to clear any 
# "dirty" states (which cause read-only locks), and remounts them with 
# full read/write permissions for the current user.
# =====================================================================

# 1. Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run this script as root (e.g., using sudo ./fix-ntfs-rw.sh)"
  exit 1
fi

# 2. Get the actual user ID and group ID of the person running sudo
# This is crucial so the mounted drive belongs to the user, not root.
USER_UID=${SUDO_UID:-$(id -u)}
USER_GID=${SUDO_GID:-$(id -g)}
USER_NAME=${SUDO_USER:-$(whoami)}

echo "============================================================"
echo " Starting NTFS Fix & Mount for user: $USER_NAME (UID: $USER_UID)"
echo "============================================================"

# 3. Detect all NTFS partitions
# lsblk will list block devices, and awk will filter only ntfs/ntfs3
PARTITIONS=$(lsblk -rno NAME,FSTYPE | awk '/ntfs|ntfs3/ {print "/dev/"$1}')

if [ -z "$PARTITIONS" ]; then
    echo "[*] No NTFS partitions detected on this system."
    exit 0
fi

for PART in $PARTITIONS; do
    echo ""
    echo ">>> Processing partition: $PART <<<"
    
    # 4. Mount/Unmount Awareness
    # Find out if the partition is currently mounted, and where
    MOUNT_INFO=$(findmnt -n -o TARGET -S "$PART")
    
    WAS_MOUNTED=0
    MOUNT_POINT=""
    
    if [ -n "$MOUNT_INFO" ]; then
        WAS_MOUNTED=1
        MOUNT_POINT="$MOUNT_INFO"
        echo "[*] Status: Currently MOUNTED at $MOUNT_POINT"
        echo "[*] Action: Unmounting $PART for repair..."
        
        # Safely unmount
        umount "$PART"
        if [ $? -ne 0 ]; then
            echo "[!] Error: Failed to unmount $PART. It might be in use by another program."
            echo "[!] Skipping to next partition..."
            continue
        fi
        echo "[+] Successfully unmounted $PART."
    else
        echo "[*] Status: NOT MOUNTED."
    fi
    
    # 5. Repair the filesystem state
    # ntfsfix -d clears the "dirty" flag (often set by Windows Fast Startup)
    echo "[*] Action: Running ntfsfix on $PART to clear read-only locks..."
    ntfsfix -d "$PART"
    
    # 6. Mount/Remount with Read/Write Permissions
    if [ $WAS_MOUNTED -eq 1 ]; then
        echo "[*] Action: Remounting $PART to its original location: $MOUNT_POINT"
        
        # Try mounting with the new, faster ntfs3 driver first. Fallback to ntfs-3g if it fails.
        mount -t ntfs3 -o rw,uid=$USER_UID,gid=$USER_GID,iocharset=utf8,relatime,force "$PART" "$MOUNT_POINT" 2>/dev/null || \
        mount -t ntfs-3g -o rw,uid=$USER_UID,gid=$USER_GID,utf8 "$PART" "$MOUNT_POINT"
        
        if [ $? -eq 0 ]; then
            echo "[+] Success: $PART is now mounted Read/Write at $MOUNT_POINT!"
        else
            echo "[!] Error: Failed to remount $PART."
        fi
    else
        # If it wasn't mounted originally, mount it dynamically to /run/media
        PART_BASENAME=$(basename "$PART")
        NEW_MOUNT="/run/media/$USER_NAME/NTFS_$PART_BASENAME"
        
        echo "[*] Action: Mounting $PART to $NEW_MOUNT"
        mkdir -p "$NEW_MOUNT"
        chown "$USER_UID:$USER_GID" "$NEW_MOUNT"
        
        mount -t ntfs3 -o rw,uid=$USER_UID,gid=$USER_GID,iocharset=utf8,relatime,force "$PART" "$NEW_MOUNT" 2>/dev/null || \
        mount -t ntfs-3g -o rw,uid=$USER_UID,gid=$USER_GID,utf8 "$PART" "$NEW_MOUNT"
        
        if [ $? -eq 0 ]; then
            echo "[+] Success: $PART is now mounted Read/Write at $NEW_MOUNT!"
        else
            echo "[!] Error: Failed to mount $PART."
        fi
    fi
done

echo ""
echo "============================================================"
echo " Finished processing all NTFS partitions."
echo "============================================================"
