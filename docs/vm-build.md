# NextSession Server VM — Build & Hardening Guide (LUKS)

End-to-end build of the VM that runs the self-hosted NextSession stack
(hbbs signal + hbbr relay + the API/console), with **LUKS full-disk encryption**
and headless remote unlock. Pairs with `server/deploy.sh`, `server/deploy-api.sh`,
`docs/entra-sso.md`, and `SECURITY.md`.

Target host: `nextsession.nxlink.com`, a single routed public IPv4 (a /30 is fine —
1 usable for the gateway, 1 for this server). Everything runs on **podman** (no compose).

---

## 0. Threat model — what LUKS does and does NOT do here

Be clear-eyed before spending effort:

**LUKS protects** data *at rest* on the underlying storage:
- A stolen / RMA'd / decommissioned disk or SSD.
- A raw storage snapshot pulled off the SAN/backing store while the VM is **powered off**.
- Backup media of the block device.

**LUKS does NOT protect** against:
- Anyone with **hypervisor / host root** — they can read the VM's RAM, where the
  master key lives while it's running.
- A **live snapshot** that captures memory (the key is in it).
- A running, unlocked system (this is the normal state — encryption is transparent once booted).

**Implication for this VM:** LUKS is worth doing (the box holds the hbbs private key,
the API DB with the Entra `client_secret`, and `jwt.key`), but it is **not a substitute**
for locking down hypervisor access and encrypting backups separately. Treat
host/hypervisor access as the real crown-jewel boundary.

---

## 1. VM spec

| Resource | Recommended | Notes |
|---|---|---|
| OS | **Ubuntu Server 24.04 LTS** | matches the dev/build environment; Subiquity has guided LUKS |
| vCPU | 2 | hbbs/hbbr/API are light; relay is bandwidth- not CPU-bound |
| RAM | 4 GB | plenty for the stack + podman |
| Disk 1 (OS) | 25 GB | unencrypted root — boots unattended |
| Disk 2 (data) | 40 GB | **LUKS** — podman storage + volumes (hbbs key, API DB); grow if recording |
| Firmware | UEFI + **vTPM 2.0** | vTPM auto-unlocks the data partition at boot (§4) |
| Network | 1 routed public IPv4 (the /30) | **not** behind port-translating NAT — see §2 |

---

## 2. Network plan (provision before install)

Clients must reach this host on:

| Port | Proto | Service | Open to |
|---|---|---|---|
| 21115 | tcp | hbbs NAT-type test | clients |
| 21116 | tcp | hbbs ID registration / hole-punch | clients |
| 21116 | **udp** | hbbs heartbeat (easy to forget!) | clients |
| 21117 | tcp | hbbr relay | clients |
| 21118 | tcp | hbbs web/ws client | only if serving web client |
| 21119 | tcp | hbbr web/ws relay | only if serving web client |
| 443 | tcp | TLS reverse proxy → API console | clients (off-net rule) |
| 22 *(or moved)* | tcp | admin SSH | **mgmt source IPs only** |

### This deployment's addressing
The VM sits on a private /30 (`10.2.15.72/30`):

| | |
|---|---|
| Host (VM) | `10.2.15.74/30` |
| Gateway | `10.2.15.73` |
| Netmask | `255.255.255.252` |
| Network / broadcast | `10.2.15.72` / `10.2.15.75` |

Static config via **netplan** (set after first boot — verify the NIC name with `ip link`,
usually `ens18` on Proxmox):

```yaml
# /etc/netplan/01-nextsession.yaml   (chmod 600)
network:
  version: 2
  ethernets:
    ens18:
      addresses: [ 10.2.15.74/30 ]
      routes:
        - to: default
          via: 10.2.15.73
      nameservers:
        addresses: [ <internal-DNS-1>, <internal-DNS-2> ]
```
```bash
sudo chmod 600 /etc/netplan/01-nextsession.yaml && sudo netplan apply
ip -4 addr show ens18 ; ping -c2 10.2.15.73
```

**Private IP → edge mapping required.** `10.2.15.74` is RFC1918, so off-net clients
can't reach it directly. The edge must map public `nextsession.nxlink.com` + the ports
above → `10.2.15.74`. **NAT caveat:** RustDesk does UDP hole-punching on 21115/21116 —
use **1:1 static NAT**; symmetric/PAT NAT pushes sessions onto the relay and hurts P2P.

---

## 3. Install Ubuntu — unencrypted root + a separate LUKS data partition

**Design decision:** the OS boots unattended; only the *data* is encrypted. All the
sensitive material (hbbs private key, API DB with the Entra `client_secret`, `jwt.key`,
the admin-password log) lives on a dedicated LUKS partition mounted at
`/srv/nextsession`. Root/OS stays unencrypted so the box always comes back up reachable
after a reboot; the data partition then auto-unlocks via the vTPM (§4), with a
passphrase as break-glass.

> **What this protects:** a stolen / powered-off / RMA'd disk reveals the OS and public
> config (deploy scripts, Caddyfile) but **not** the secrets or DB. What it does not
> protect: see §0 (hypervisor access, live memory). The OS being in the clear is an
> accepted trade for unattended boot.

### Disk layout
Cleanest on a VM: **two virtual disks** — Disk 1 = OS (unencrypted), Disk 2 = data (LUKS).
(A second partition on one disk works too; two disks are easier to resize/move.)

1. Boot the Ubuntu Server 24.04 installer. Install normally onto **Disk 1** (guided,
   **no** encryption). Set the admin user; don't import a cloud key you don't control.
2. Leave **Disk 2** untouched during install; format it after first boot.

### Format the data partition (LUKS2) after first boot
```bash
DATA=/dev/sdb                                   # <-- your data disk (verify with lsblk!)
sudo cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 \
     --key-size 512 --pbkdf argon2id "$DATA"    # set a STRONG passphrase -> vault
sudo cryptsetup open "$DATA" nextsession-data
sudo mkfs.ext4 -L nextsession-data /dev/mapper/nextsession-data
sudo mkdir -p /srv/nextsession
sudo mount /dev/mapper/nextsession-data /srv/nextsession

DATA_UUID=$(sudo blkid -s UUID -o value "$DATA") # LUKS container UUID — stable, use this
echo "LUKS UUID: $DATA_UUID"                     # note it for crypttab
```

### Make boot NOT wait on it (interim) — `noauto`
So a reboot never hangs waiting for the data key:
```bash
# /etc/crypttab  — noauto = don't try to unlock at boot (we do it manually for now)
echo "nextsession-data UUID=$DATA_UUID none luks,noauto" | sudo tee -a /etc/crypttab
# /etc/fstab     — noauto = don't fail boot if it isn't mounted yet
echo "/dev/mapper/nextsession-data /srv/nextsession ext4 defaults,noauto 0 2" | sudo tee -a /etc/fstab
```

### Encrypt (or disable) swap
Paged-out memory can contain secrets. Either disable swap, or encrypt it with a
**random** key (re-generated each boot, never on disk):
```bash
# /etc/crypttab
echo "swap /dev/sdaN /dev/urandom swap,cipher=aes-xts-plain64,size=256" | sudo tee -a /etc/crypttab
# point /etc/fstab swap line at /dev/mapper/swap   (or just `sudo swapoff -a` and remove it)
```

---

## 4. Auto-unlock the data partition with the vTPM

The key is sealed to the VM's vTPM; at boot the TPM releases it automatically — no
passphrase, no Tang, no manual step. Protects a **stolen/copied disk** (the key isn't on
it). Does **not** protect against hypervisor access or a VM image lifted off the host
*together with* its vTPM state — that's an accepted trade (see §0).

### 4a. Attach + verify the vTPM (Proxmox)
Prereqs: the VM must be **UEFI (OVMF)** with an EFI disk and machine type **q35**
(set under VM → Hardware → BIOS/Machine). Then, with the **VM powered off**, add the
TPM (it can't be hot-added):

- **GUI:** VM → Hardware → **Add → TPM State** → pick a storage (e.g. `local-lvm`),
  **Version 2.0**.
- **CLI** (on the Proxmox host, substitute `<vmid>`/storage):
  ```bash
  qm set <vmid> -tpmstate0 local-lvm:1,version=v2.0
  ```

Proxmox stores the vTPM as a small **swtpm state disk on the host storage** — that's the
"vTPM state lives on the host" point from §0/§4. It also means a **`vzdump` backup
bundles the encrypted disk *and* the TPM state together** → see the backup caveat in §10.

Boot the VM and confirm the guest sees the TPM:
```bash
sudo apt install -y tpm2-tools
ls /dev/tpmrm0                              # device node should exist
sudo tpm2_getcap properties-fixed | head   # talks to the TPM
```
If `/dev/tpmrm0` is missing, the TPM State device or UEFI/q35 prereq is off — fix before binding.

### 4b. Bind LUKS to the TPM and enable auto-unlock
```bash
sudo apt install -y clevis clevis-luks clevis-tpm2 clevis-systemd
sudo clevis luks bind -d /dev/sdb tpm2 '{"pcr_bank":"sha256","pcr_ids":"7"}'
# flip crypttab from manual to automatic:  luks,noauto  ->  luks
sudo sed -i 's/\bluks,noauto\b/luks/' /etc/crypttab
# mount at boot too: in /etc/fstab change the data line  noauto  ->  defaults  (keep nofail)
sudo systemctl daemon-reload
```
`pcr_ids:7` binds to the Secure Boot state. **Caveat:** firmware/Secure-Boot changes
(and some kernel/bootloader updates) alter PCRs and will make the TPM refuse the key —
the box then drops to the **passphrase prompt**. That's why the passphrase slot stays
(below). If you don't run Secure Boot, you can bind with `'{}'` (no PCR policy), which is
more update-proof but unseals on any boot of this VM.

### Initial setup / break-glass — manual unlock
Before you bind the TPM (and any time PCRs change), unlock by hand. Drop in a helper —
also handy for the first deploy in §7:

```bash
sudo tee /usr/local/sbin/ns-unlock >/dev/null <<'EOF'
#!/bin/sh
set -e
cryptsetup status nextsession-data >/dev/null 2>&1 || cryptdisks_start nextsession-data
mountpoint -q /srv/nextsession || mount /srv/nextsession
# start the stack (containers were created with --restart unless-stopped):
podman start nextsession-hbbr nextsession-hbbs nextsession-api 2>/dev/null || true
echo "data partition unlocked + mounted."
EOF
sudo chmod 755 /usr/local/sbin/ns-unlock
```

> Keep a **passphrase key slot** as break-glass (`cryptsetup luksDump /dev/sdb` lists
> slots — the passphrase slot from §3 must remain). **Back up the LUKS header** (§10):
> header loss = unrecoverable data.
> **Never** stash a plaintext keyfile on the unencrypted root to "auto-unlock" — that
> puts the key next to the ciphertext and defeats encryption entirely.

### Higher-assurance alternative — Tang (network-bound)
If you later decide a stolen *whole-VM image* (disk **+** vTPM state) is in scope, Tang
is stronger: the key never lives on the host, so an image taken **off your network**
stays locked. It costs a small internal-only Tang host. Same bind pattern with `tang`
(`'{"url":"http://tang.internal"}'`) and `luks,_netdev` in crypttab; run two for HA via
an `sss` policy. Non-destructive to add later — it's just another key slot.

---

## 5. First-boot hardening

```bash
# Patches + automatic security updates
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y unattended-upgrades fail2ban
sudo dpkg-reconfigure -plow unattended-upgrades

# --- SSH hardening: keys only, no root password login ---
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

**Firewall** — open only the client ports publicly; restrict SSH + dropbear to your
management source IPs. Using ufw:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
# RustDesk client-facing:
sudo ufw allow 21115/tcp
sudo ufw allow 21116/tcp
sudo ufw allow 21116/udp
sudo ufw allow 21117/tcp
sudo ufw allow 443/tcp
# Web client ports ONLY if you serve it:
# sudo ufw allow 21118/tcp ; sudo ufw allow 21119/tcp
# Admin — restrict to your mgmt range (replace M.M.M.M/NN):
sudo ufw allow from M.M.M.M/NN to any port 22 proto tcp
sudo ufw allow from M.M.M.M/NN to any port 2222 proto tcp
sudo ufw enable
```

The API/console itself binds to `127.0.0.1:21114` (set in `deploy-api.sh`) — it is
**never** exposed directly; only the 443 reverse proxy reaches it.

---

## 6. Install podman

```bash
sudo apt install -y podman
```

**Point podman's storage at the encrypted mount** — this is what puts the container
images *and* all named volumes (hbbs key, API DB) on the LUKS partition. Without this,
podman writes to `/var/lib/containers` on the unencrypted root and your secrets leak.

```bash
sudo mkdir -p /srv/nextsession/containers/storage
sudo sed -i 's|^graphroot = .*|graphroot = "/srv/nextsession/containers/storage"|' \
     /etc/containers/storage.conf 2>/dev/null \
  || echo -e '[storage]\ndriver = "overlay"\ngraphroot = "/srv/nextsession/containers/storage"' \
     | sudo tee /etc/containers/storage.conf
sudo podman info | grep -i graphroot   # confirm it points at /srv/nextsession
```
This guide runs the containers **rootful** (`sudo podman`) so graphroot/volumes sit on
the encrypted mount cleanly. Because that mount isn't present until you unlock, podman
simply can't start the stack early — which is the behaviour we want.

Pull the repo (clients are built elsewhere; the server just needs the scripts + the
apiserver submodule):

```bash
git clone https://github.com/phurd-nl/rustdesk.git nextsession
cd nextsession
git submodule update --init apiserver apiserver-web
```

---

## 7. Bring up the NextSession stack

First **unlock the data partition** (`sudo ns-unlock`) so podman's graphroot is present.
Run the scripts **rootful** (`sudo`) so volumes land on the encrypted mount.
**Order matters** — hbbs must generate its keypair before clients are built.

```bash
sudo ns-unlock                                  # mount /srv/nextsession first

# 1) Signal + relay. Prints the RS_PUB_KEY.
sudo PUBLIC_HOST=nextsession.nxlink.com ./server/deploy.sh
```
Copy the printed **RS_PUB_KEY**. Then **on the build host** (not the VM), set
`override-settings.key` in `branding/custom_client.json`, run
`python3 branding/make_custom.py`, and rebuild/sign the clients. (See `BRANDING.md`.)

```bash
# 2) API + console. Builds the web console, generates the jwt podman secret,
#    reads the hbbs key from the volume, prints the one-time admin password.
sudo PUBLIC_HOST=nextsession.nxlink.com ./server/deploy-api.sh
```
Capture the admin password from the output, then rotate the container log.

**Survive reboots:** the containers use `--restart unless-stopped`, which only covers
the podman runtime — not a full reboot. With the TPM bind (§4) the mount comes up at boot, so generate systemd
units ordered after the mount and the containers start untouched:
```bash
sudo podman generate systemd --new --files --name nextsession-hbbs   # repeat per container
# move the .service files to /etc/systemd/system/, add to each [Unit]:
#   RequiresMountsFor=/srv/nextsession
sudo systemctl daemon-reload && sudo systemctl enable nextsession-hbbs nextsession-hbbr nextsession-api
```

---

## 8. TLS reverse proxy on 443 → 127.0.0.1:21114

The console/API must be fronted by TLS. Caddy gives automatic Let's Encrypt certs with
the least config:

```bash
sudo apt install -y caddy
sudo tee /etc/caddy/Caddyfile >/dev/null <<'EOF'
nextsession.nxlink.com {
    reverse_proxy 127.0.0.1:21114
}
EOF
sudo systemctl reload caddy
```
Requires `nextsession.nxlink.com` A-record → your /30 server IP, and 80/443 reachable
for the ACME challenge (80 can be closed afterward if you use the TLS-ALPN challenge).
nginx + certbot works equally well if you prefer it.

---

## 9. Entra SSO, then lock to SSO-only

Follow `docs/entra-sso.md` to register the Entra app and add the OIDC provider in the
console (`https://nextsession.nxlink.com/_admin/`). Then lock down **in this order**
(critical — otherwise you lock yourself out):

1. Sign in once via Entra so your user is provisioned.
2. As the local admin, promote that user to admin (console → Users, or DB `is_admin=1`).
3. Re-run with password login disabled:
   ```bash
   SSO_ONLY=true PUBLIC_HOST=nextsession.nxlink.com ./server/deploy-api.sh
   ```
   Password login is now disabled for the client **and** the console; the console
   auto-redirects to Entra. Keep the local admin creds as break-glass.

---

## 10. Backups (do not skip)

Losing these is unrecoverable:

- **hbbs keypair** — `nextsession-hbbs-data` volume (`/root/id_ed25519*`). Losing it
  invalidates every deployed client's pinned `RS_PUB_KEY`. Back up off-box, encrypted.
  ```bash
  podman run --rm -v nextsession-hbbs-data:/d:ro busybox tar -czf - /d > hbbs-data-$(date +%F).tgz
  ```
- **API data volume** — `nextsession-api-data` (sqlite DB: users, address book, OIDC
  config incl. the Entra `client_secret`). Back up encrypted.
- **LUKS header** — `sudo cryptsetup luksHeaderBackup /dev/<part> --header-backup-file luks-header.img`.
  Store in the vault; header corruption otherwise = total data loss.
- **Signing seed** — `branding/secrets/nextsession_signing.key` lives on the **build host**,
  not here; back it up there.

Because the running VM's encryption is transparent, **encrypt the backups themselves**
(age/gpg) — don't rely on LUKS for data that has left the box.

> **Proxmox `vzdump` caveat (important with the vTPM):** a full-VM backup captures the
> LUKS data disk **and** the `tpmstate0` swtpm state — i.e. the ciphertext *and* the key
> that unlocks it, in one archive. So a stolen `vzdump` is restorable-and-unlockable,
> exactly the property LUKS was meant to deny. Mitigate: send backups to **Proxmox
> Backup Server with client-side encryption**, or an encrypted/locked-down backup target,
> and treat backup storage with the same care as the hypervisor itself.

---

## 11. Reboot drill (verify before you depend on it)

Reboot once and confirm the flow works end to end:

```bash
sudo reboot
# The OS boots unattended and SSH comes up WITHOUT the data partition (noauto).
ssh you@A.B.C.2
sudo ns-unlock        # interim: type passphrase → opens, mounts, starts containers
#   once the TPM bind (§4) is in place, the mount + containers come up on their own —
#   ns-unlock is then only needed as break-glass (e.g. after a PCR change)
```
Then confirm the stack and console answer:
```bash
sudo podman ps
curl -sk https://nextsession.nxlink.com/_admin/ -o /dev/null -w '%{http_code}\n'
```
This design's failure mode is gentler than full-disk: a reboot always leaves the box
**reachable** (root is unencrypted), so you can always get in to unlock or debug — the
only thing waiting on the key is the NextSession service. Still, run the drill before
you depend on it.
