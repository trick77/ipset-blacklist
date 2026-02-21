# nftables-blacklist (formerly ipset-blacklist)

[![CI](https://github.com/trick77/nftables-blacklist/actions/workflows/ci.yaml/badge.svg)](https://github.com/trick77/nftables-blacklist/actions/workflows/ci.yaml)
[![Bash 4.0+](https://img.shields.io/badge/bash-4.0%2B-blue)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/github/license/trick77/nftables-blacklist)](LICENSE)

> **Freshly defrosted from the [GitHub Arctic Code Vault](https://archiveprogram.github.com/arctic-vault/)** and upgraded from iptables to nftables. Yes, the nftables syntax is... an acquired taste. But I finally bow to the netfilter overlords.
>
> **Early stage** - expect bugs.

A Bash script that uses nftables to block large numbers of malicious IP addresses from public blacklists. Supports both IPv4 and IPv6 with CIDR notation.

> **Looking for the old ipset/iptables version?** See the [archive/](archive/) folder.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Start (Debian/Ubuntu)](#quick-start-debianubuntu)
- [Persistence Across Reboots](#persistence-across-reboots)
- [Automatic Updates (Systemd Timer)](#automatic-updates-systemd-timer)
- [Check Dropped Packets](#check-dropped-packets)
- [Configuration Options](#configuration-options)
- [Customizing Blacklists](#customizing-blacklists)
- [Whitelist (Prevent Self-Blocking)](#whitelist-prevent-self-blocking)
- [Dry Run Mode](#dry-run-mode)
- [Troubleshooting](#troubleshooting)
- [Migrating from the old ipset/iptables version](#migrating-from-the-old-ipsetiptables-version)
- [How It Works](#how-it-works)
- [Files](#files)
- [License](#license)
- [Credits](#credits)

## Features

- **nftables**: Uses modern nftables instead of deprecated iptables/ipset
- **IPv4 + IPv6**: Blocks both IPv4 and IPv6 addresses
- **CIDR support**: Block entire subnets (e.g., `10.0.0.0/8`), not just individual IPs
- **Automatic aggregation**: Overlapping ranges are combined (e.g., two /24s become one /23)
- **Atomic updates**: Blacklist swaps instantly - no window where malicious traffic slips through
- **Fast filtering**: Efficient IP matching with minimal CPU overhead, even with 100k+ blocked IPs
- **Pure Bash**: No Python, Perl, PHP, or awk dependencies

## Requirements

- Debian 10+ / Ubuntu 20.04+ (or any Linux with nftables)
- nftables (`apt install nftables`)
- iprange (`apt install iprange`) - combines overlapping IP ranges and handles whitelist subtraction
- curl, grep, sed, sort, wc (usually pre-installed)

## Quick Start (Debian/Ubuntu)

1. **Install helper tools:**
   ```bash
   sudo apt install curl iprange
   ```

2. **Download the script:**
   ```bash
   sudo curl -fsSL -o /usr/local/sbin/update-blacklist.sh \
     https://raw.githubusercontent.com/trick77/nftables-blacklist/master/update-blacklist.sh
   sudo chmod +x /usr/local/sbin/update-blacklist.sh
   ```

3. **Create configuration directory and download config:**
   ```bash
   sudo mkdir -p /etc/nftables-blacklist
   [ -f /etc/nftables-blacklist/nftables-blacklist.conf ] \
     || sudo curl -fsSL -o /etc/nftables-blacklist/nftables-blacklist.conf \
          https://raw.githubusercontent.com/trick77/nftables-blacklist/master/nftables-blacklist.conf
   ```

4. **Edit configuration (optional):**
   ```bash
   sudo nano /etc/nftables-blacklist/nftables-blacklist.conf
   ```

5. **Run initial update:**
   ```bash
   sudo /usr/local/sbin/update-blacklist.sh /etc/nftables-blacklist/nftables-blacklist.conf
   ```

6. **Verify it's working:**
   ```bash
   # List the blacklist table
   sudo nft list table inet blacklist

   # Show IPv4 set contents
   sudo nft list set inet blacklist blacklist4

   # Show IPv6 set contents
   sudo nft list set inet blacklist blacklist6

   # Check drop counters
   sudo nft list chain inet blacklist input
   ```

## Persistence Across Reboots

### Option 1: Systemd Service (Recommended)

Create `/etc/systemd/system/nftables-blacklist.service`:

```ini
[Unit]
Description=nftables IP blacklist
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/update-blacklist.sh /etc/nftables-blacklist/nftables-blacklist.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
systemctl daemon-reload
systemctl enable nftables-blacklist.service
```

### Option 2: Include in nftables.conf

If you prefer to load the blacklist as part of your main nftables config, add this to `/etc/nftables.conf`:

```nft
include "/etc/nftables-blacklist/blacklist.nft"
```

Note: The blacklist.nft file must exist before nftables starts, so run the script at least once first.

## Automatic Updates (Systemd Timer)

Create `/etc/systemd/system/nftables-blacklist-update.timer`:

```ini
[Unit]
Description=Update nftables IP blacklist daily

[Timer]
OnCalendar=*-*-* 23:33:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
```

Create `/etc/systemd/system/nftables-blacklist-update.service`:

```ini
[Unit]
Description=Update nftables IP blacklist
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/update-blacklist.sh --cron /etc/nftables-blacklist/nftables-blacklist.conf
```

Enable it:

```bash
systemctl daemon-reload
systemctl enable --now nftables-blacklist-update.timer
```

Check timer status:

```bash
systemctl list-timers nftables-blacklist-update
```

**Tip:** Once or twice daily is enough. Updating too frequently may get you banned by blacklist providers.

## Check Dropped Packets

```bash
nft list chain inet blacklist input
```

Example output:

```
chain input {
    type filter hook input priority -200; policy accept;
    ip saddr @blacklist4 counter packets 1523 bytes 91380 drop comment "IPv4 blacklist"
    ip6 saddr @blacklist6 counter packets 42 bytes 3360 drop comment "IPv6 blacklist"
}
```

## Configuration Options

Edit `nftables-blacklist.conf`. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `ENABLE_IPV4` | yes | Block IPv4 addresses |
| `ENABLE_IPV6` | yes | Block IPv6 addresses |
| `FORCE` | yes | Automatically create the nftables table/sets if they don't exist |
| `VERBOSE` | yes | Show progress output (use `--cron` flag to suppress) |
| `AUTO_WHITELIST` | no | Auto-detect and whitelist your server's own IPs (recommended) |
| `NFT_CHAIN_PRIORITY` | -200 | When to check the blacklist (-200 = very early, before most other rules) |
| `CURL_CONNECT_TIMEOUT` | 10 | Seconds to wait for blacklist server connection |
| `CURL_MAX_TIME` | 30 | Maximum seconds per blacklist download |

## Customizing Blacklists

Edit the `BLACKLISTS` array in the config file:

```bash
BLACKLISTS=(
    # Your custom local list
    "file:///etc/nftables-blacklist/custom.list"

    # Public blacklists
    "https://www.spamhaus.org/drop/drop.lasso"
    "https://lists.blocklist.de/lists/all.txt"

    # Ban an entire country (use country code like 'cn', 'ru', etc.)
    # "https://raw.githubusercontent.com/ipverse/rir-ip/master/country/ru/ipv4-aggregated.txt"
)
```

For more blacklist sources, check [FireHOL's blocklist-ipsets](https://github.com/firehol/blocklist-ipsets).

## Whitelist (Prevent Self-Blocking)

Sometimes your server's IP may appear in a public blacklist. To prevent blocking yourself:

### Manual Whitelist

Edit the `WHITELIST` array in the config file:

```bash
WHITELIST=(
    "203.0.113.10"       # Your server IP
    "203.0.113.0/24"     # Your network range
    "2001:db8::1"        # IPv6 address
)
```

For IPv4, whitelisting a range like `10.0.0.0/8` will correctly exclude all IPs in that range, even if the blacklist contains individual IPs like `10.1.2.3`.

**Note:** IPv6 whitelist only matches exact addresses (CIDR ranges not supported for IPv6 whitelist).

### Auto-Detect Server IPs

To automatically whitelist your server's own IPs (recommended):

```bash
AUTO_WHITELIST=yes
```

This detects all local interface IPs and queries external services (o11.net, icanhazip.com) for your public IPs. Useful if your server's IP ends up on a public blacklist.

## Dry Run Mode

Test without actually applying rules:

```bash
update-blacklist.sh --dry-run /etc/nftables-blacklist/nftables-blacklist.conf
```

This will:
- Download all blacklists
- Process and filter IPs
- Generate the nftables script
- Show what would be applied (without executing)

## Troubleshooting

### "nftables table does not exist"

The script creates the required nftables structure automatically when `FORCE=yes` (the default). If you see this error, check that `FORCE=yes` is set in your config file.

### Check if an IP is blocked

```bash
nft get element inet blacklist blacklist4 { 1.2.3.4 }
nft get element inet blacklist blacklist6 { 2001:db8::1 }
```

### Integration with existing firewall

This script creates its own nftables table (`inet blacklist`) and loads rules directly with `nft -f`. It doesn't depend on any firewall service or manager.

It won't conflict with your existing firewall — whether you manage rules directly, through a firewall manager, or via `iptables` (which translates to nftables on modern systems). The default priority (-200) means packets hit the blacklist check before most other firewall rules.

If you need the blacklist checked at a different point, adjust `NFT_CHAIN_PRIORITY` in the config. Lower numbers = checked earlier.

### Large IP sets (100k+ entries)

The script handles large blacklists automatically by loading IPs in batches. However, with very large sets you may see errors like "Message too long" or "No buffer space available".

Fix by increasing the kernel network buffer:

```bash
# Add to /etc/sysctl.d/99-nftables.conf
net.core.rmem_max = 8388608
net.core.rmem_default = 8388608

# Apply now
sysctl -p /etc/sysctl.d/99-nftables.conf
```

### Still using iptables commands?

On modern Debian/Ubuntu, `iptables` commands are automatically translated to nftables behind the scenes. This blacklist uses a separate table, so there's no conflict.

**Watch out for:** `nft flush ruleset` - this deletes ALL nftables rules including the blacklist. The safer `iptables -F` only affects iptables rules and leaves the blacklist intact.

To see all tables (including any created by iptables commands):
```bash
nft list tables
```

### View generated script

```bash
cat /etc/nftables-blacklist/blacklist.nft
```

### Check plain text IP lists

```bash
wc -l /etc/nftables-blacklist/ip-blacklist.list.v4
wc -l /etc/nftables-blacklist/ip-blacklist.list.v6
```

## Migrating from the old ipset/iptables version

1. Remove the old ipset/iptables rules and clean up legacy files. The exact paths may vary depending on how you originally set it up — the commands below are examples based on the default configuration:
   ```bash
   # Remove iptables rule and ipset
   iptables -D INPUT -m set --match-set blacklist src -j DROP
   ipset destroy blacklist

   # Remove old cron job
   rm -f /etc/cron.d/update-blacklist

   # Remove old script
   rm -f /usr/local/sbin/update-blacklist.sh

   # Before deleting, check for any custom blacklists or URLs you want to preserve:
   # - Custom blacklist file: /etc/ipset-blacklist/ip-blacklist-custom.list
   # - Custom blacklist URLs in: /etc/ipset-blacklist/ipset-blacklist.conf (BLACKLISTS array)
   # Back up anything you need, then remove the old config and data directory
   rm -rI /etc/ipset-blacklist
   ```
2. Set up the new nftables version (see Quick Start)

> **Stale rule?** If the `iptables -D ... --match-set` command fails with *"Set blacklist doesn't exist"*, the ipset is already gone but a stale rule remains. Delete it by rule number instead:
> ```bash
> iptables -L INPUT --line-numbers
> iptables -D INPUT <rule-number>
> ```

> **Note for Debian Trixie (and newer) users:** On modern Debian, `iptables` is usually just a compatibility layer (`iptables-nft`) that translates commands to nftables under the hood. If you previously switched to the legacy iptables backend (`iptables-legacy` / `update-alternatives --set iptables /usr/sbin/iptables-legacy`), you'll need to switch back to the nftables backend for this script to work:
> ```bash
> update-alternatives --set iptables /usr/sbin/iptables-nft
> update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
> ```

The old version is preserved in the `archive/` folder if you need to reference it.

## How It Works

1. Downloads IP blacklists from configured URLs (Spamhaus, blocklist.de, etc.)
2. Extracts IPv4 and IPv6 addresses from various formats (plain IPs, CIDR, CSV, etc.)
3. Filters out private ranges (10.x, 192.168.x, etc.) so you don't accidentally block internal traffic
4. Removes duplicates and combines overlapping ranges to reduce set size
5. Applies the whitelist to ensure your own server IPs are never blocked
6. Loads all IPs into nftables in one transaction - the old blacklist is replaced instantly

The script creates a separate nftables table (`inet blacklist`) that won't interfere with your existing firewall rules.

## Files

| Path | Description |
|------|-------------|
| `/usr/local/sbin/update-blacklist.sh` | The script you run (manually or via cron) |
| `/etc/nftables-blacklist/nftables-blacklist.conf` | Your configuration (blacklist URLs, whitelist, options) |
| `/etc/nftables-blacklist/blacklist.nft` | Generated nftables rules (can be included in nftables.conf) |
| `/etc/nftables-blacklist/ip-blacklist.list.v4` | Plain text list of blocked IPv4 addresses |
| `/etc/nftables-blacklist/ip-blacklist.list.v6` | Plain text list of blocked IPv6 addresses |

## License

MIT License - See LICENSE file for details.

## Credits

Originally based on [trick77/ipset-blacklist](https://github.com/trick77/nftables-blacklist).
Rewritten for nftables with IPv6 support.
