# Swap Setup Guide for Ubuntu 22.04 VPS

> A practical guide to configuring swap space on your VPS server.

---

## 1. What is Swap and Why You Need It

**Swap is an overflow area for RAM.** When your server runs out of physical memory, the kernel moves inactive pages to a swap file on disk instead of killing processes.

### Why VPS Servers Especially Need It

Most budget VPS plans come with **1–2GB RAM** — that's tight. Here's what eats memory fast:

- **Node.js / Next.js builds** — `npm run build` can spike to 1.5GB+ RAM easily
- **Multiple services** — Nginx + Node + database + OS overhead adds up
- **Traffic spikes** — concurrent requests increase memory usage unpredictably

Without swap, the Linux OOM (Out of Memory) killer steps in and **terminates your processes** — usually the one using the most RAM (your app).

### A Common Scenario

```
FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed
    - JavaScript heap out of memory
```

This happens during `npm run build` on a 1GB VPS with no swap. Swap prevents this.

### Important

**Swap is NOT a replacement for RAM — it's a safety net.** Disk I/O is orders of magnitude slower than RAM. Swap keeps your server alive during memory spikes, but if your server is constantly swapping, you need more RAM.

---

## 2. Recommended Swap Sizes

| Server RAM | Recommended Swap | Notes                          |
|------------|-----------------|--------------------------------|
| 1 GB       | 2 GB            | Essential — builds will fail without it |
| 2 GB       | 2 GB            | Strongly recommended           |
| 4 GB       | 2–4 GB          | Recommended for safety         |
| 8 GB+      | 1–2 GB          | Optional — or skip entirely    |

> **Rule of thumb:** On a VPS with ≤2GB RAM, always create at least 2GB swap.

---

## 3. Check Current Swap Status

### Check if swap exists

```bash
sudo swapon --show
```

If there's no output, you have no swap configured.

### Check memory and swap usage

```bash
free -h
```

Example output:

```
              total        used        free      shared  buff/cache   available
Mem:          1.9Gi       1.2Gi       120Mi        12Mi       640Mi       560Mi
Swap:         2.0Gi        50Mi       1.9Gi
```

### Quick one-liner check

```bash
cat /proc/swaps
```

---

## 4. Create Swap File — Step by Step

### Step 1: Create the swap file

Using `fallocate` (preferred — faster):

```bash
sudo fallocate -l 2G /swapfile
```

If `fallocate` isn't available or fails (some filesystems don't support it), use `dd`:

```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
```

### Step 2: Set correct permissions

Only root should be able to read/write the swap file:

```bash
sudo chmod 600 /swapfile
```

### Step 3: Set up the swap area

```bash
sudo mkswap /swapfile
```

### Step 4: Enable swap

```bash
sudo swapon /swapfile
```

### Step 5: Verify it works

```bash
sudo swapon --show
free -h
```

You should see your new swap file listed.

### Step 6: Make it permanent (survive reboots)

Add the swap file to `/etc/fstab`:

```bash
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Verify the entry:

```bash
cat /etc/fstab | grep swap
```

---

## 5. Tune Swap Settings

### Swappiness

**Swappiness** controls how aggressively the kernel moves pages to swap.

| Value | Behavior                                       |
|-------|-------------------------------------------------|
| 0     | Only swap to avoid OOM                          |
| 10    | Swap reluctantly — **recommended for VPS/web servers** |
| 60    | Default — too aggressive for most servers        |
| 100   | Swap aggressively                               |

Check current value:

```bash
cat /proc/sys/vm/swappiness
```

Set to 10 (takes effect immediately):

```bash
sudo sysctl vm.swappiness=10
```

### VFS Cache Pressure

Controls how aggressively the kernel reclaims memory used for caching directory and inode objects. Default is 100. Lowering it makes the kernel prefer to keep these caches.

```bash
sudo sysctl vm.vfs_cache_pressure=50
```

### Make Settings Permanent

Add to `/etc/sysctl.conf` so they persist across reboots:

```bash
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
```

### Why Low Swappiness for Web Servers?

Web servers need fast response times. High swappiness means the kernel may swap out your app's memory to disk, causing latency spikes when those pages are needed again. A value of **10** keeps your app in RAM and only uses swap as a last resort.

---

## 6. Resize or Remove Swap

### Turn off existing swap

```bash
sudo swapoff /swapfile
```

### Remove the swap file

```bash
sudo rm /swapfile
```

### Remove the fstab entry

```bash
sudo sed -i '/\/swapfile/d' /etc/fstab
```

### Create a larger swap (example: 4GB)

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

Don't forget to update `/etc/fstab` if you removed the entry.

---

## 7. Quick Setup Script

Copy and paste this entire block to create and configure 2GB swap in one go:

```bash
#!/usr/bin/env bash
set -euo pipefail

SWAP_SIZE="2G"
SWAPFILE="/swapfile"

# Check if swap already exists
if [ -f "$SWAPFILE" ]; then
    echo "⚠️  $SWAPFILE already exists. Remove it first if you want to recreate."
    echo "   sudo swapoff $SWAPFILE && sudo rm $SWAPFILE"
    exit 1
fi

echo "==> Creating ${SWAP_SIZE} swap file..."
sudo fallocate -l "$SWAP_SIZE" "$SWAPFILE"

echo "==> Setting permissions..."
sudo chmod 600 "$SWAPFILE"

echo "==> Setting up swap area..."
sudo mkswap "$SWAPFILE"

echo "==> Enabling swap..."
sudo swapon "$SWAPFILE"

echo "==> Making swap permanent..."
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
fi

echo "==> Tuning swap settings..."
sudo sysctl vm.swappiness=10
sudo sysctl vm.vfs_cache_pressure=50

if ! grep -q 'vm.swappiness' /etc/sysctl.conf; then
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
fi
if ! grep -q 'vm.vfs_cache_pressure' /etc/sysctl.conf; then
    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
fi

echo ""
echo "✅ Swap configured successfully!"
echo ""
free -h
```

Save and run:

```bash
# Save the script
nano setup-swap.sh

# Make executable and run
chmod +x setup-swap.sh
sudo ./setup-swap.sh
```

---

## 8. Troubleshooting

### "swapon: /swapfile: Operation not permitted"

**Cause:** Some VPS providers (notably OpenVZ-based) disable swap at the kernel level.

**Check your virtualization type:**

```bash
systemctl detect-virt
```

- `kvm`, `vmware`, `xen` — swap should work
- `openvz`, `lxc` — swap may be disabled by the host

**Fix:** Contact your VPS provider or upgrade to a KVM-based plan.

### Swap showing 0 after reboot

**Cause:** Missing or incorrect `/etc/fstab` entry.

**Fix:** Verify the entry exists:

```bash
cat /etc/fstab | grep swap
```

It should show:

```
/swapfile none swap sw 0 0
```

If missing, add it:

```bash
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### High swap usage (constantly swapping)

**Check what's using swap:**

```bash
free -h
```

If swap usage is consistently above 50%, your server needs more RAM. Swap keeps things alive, but heavy swapping kills performance.

**Options:**

1. Upgrade your VPS plan (more RAM)
2. Optimize your app's memory usage (e.g., `NODE_OPTIONS=--max-old-space-size=512`)
3. Reduce the number of running services

### Swap file permissions warning

If you see `insecure permissions` during `swapon`:

```bash
sudo chmod 600 /swapfile
```

---

## Quick Reference

| Task                     | Command                                    |
|--------------------------|--------------------------------------------|
| Check swap status        | `sudo swapon --show`                       |
| Check memory             | `free -h`                                  |
| Create 2GB swap          | `sudo fallocate -l 2G /swapfile`           |
| Enable swap              | `sudo swapon /swapfile`                    |
| Disable swap             | `sudo swapoff /swapfile`                   |
| Check swappiness         | `cat /proc/sys/vm/swappiness`              |
| Set swappiness           | `sudo sysctl vm.swappiness=10`             |
| Check virtualization     | `systemctl detect-virt`                    |
