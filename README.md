# nftables-blacklist (formerly ipset-blacklist)

> **Freshly defrosted from the [GitHub Arctic Code Vault](https://archiveprogram.github.com/arctic-vault/)** and upgraded from iptables to nftables. Yes, the nftables syntax is... an acquired taste. But I finally bow to the netfilter overlords.
>
> **Early stage** - expect bugs. Testing and feedback welcome.

A Bash script that uses nftables to block large numbers of malicious IP addresses from public blacklists. Supports both IPv4 and IPv6 with CIDR notation.

> **Looking for the old ipset/iptables version?** See the [archive/](archive/) folder.

## Features

- **nftables**: Uses nftables instead of deprecated iptables/ipset
- **IPv4 + IPv6**: Full dual-stack support
- **CIDR support**: Efficiently blocks entire ranges with interval sets
- **Auto-merge**: nftables automatically consolidates overlapping ranges
- **Atomic updates**: Zero-gap protection during updates
- **O(1) lookups**: Hash table based for maximum performance
- **Pure Bash**: No Python, Perl, PHP, or awk required

## Requirements

- Debian 10+ / Ubuntu 20.04+ (or any Linux with nftables)
- nftables (`apt install nftables`)
- iprange (`apt install iprange`) - for CIDR optimization and whitelist
- curl, grep, sed, sort, wc (standard utilities)

## Quick Start (Debian/Ubuntu)

1. **Install dependencies:**
   ```bash
   apt update
   apt install nftables curl iprange
   systemctl enable nftables
   systemctl start nftables
   ```

2. **Download the script:**
   ```bash
   wget -O /usr/local/sbin/update-blacklist.sh \
     https://raw.githubusercontent.com/trick77/ipset-blacklist/master/update-blacklist.sh
   chmod +x /usr/local/sbin/update-blacklist.sh
   ```

3. **Create configuration directory and download config:**
   ```bash
   mkdir -p /etc/nftables-blacklist
   wget -O /etc/nftables-blacklist/nftables-blacklist.conf \
     https://raw.githubusercontent.com/trick77/ipset-blacklist/master/nftables-blacklist.conf
   ```

4. **Edit configuration (optional):**
   ```bash
   nano /etc/nftables-blacklist/nftables-blacklist.conf
   ```

5. **Run initial update:**
   ```bash
   /usr/local/sbin/update-blacklist.sh /etc/nftables-blacklist/nftables-blacklist.conf
   ```

6. **Verify it's working:**
   ```bash
   # List the blacklist table
   nft list table inet blacklist

   # Show IPv4 set contents
   nft list set inet blacklist blacklist4

   # Show IPv6 set contents
   nft list set inet blacklist blacklist6

   # Check drop counters
   nft list chain inet blacklist input
   ```

## Persistence Across Reboots

### Method 1: Include in nftables.conf (Recommended)

Add to `/etc/nftables.conf`:

```nft
#!/usr/sbin/nft -f
flush ruleset

# Include the blacklist (must exist)
include "/etc/nftables-blacklist/blacklist.nft"

# Your other rules here...
```

### Method 2: Systemd Service

Create `/etc/systemd/system/nftables-blacklist.service`:

```ini
[Unit]
Description=nftables IP blacklist
After=network.target nftables.service
Requires=nftables.service

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

## Automatic Updates (Cron Job)

Create `/etc/cron.d/nftables-blacklist`:

```cron
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root

# Update blacklist daily at 23:33
33 23 * * * root /usr/local/sbin/update-blacklist.sh --cron /etc/nftables-blacklist/nftables-blacklist.conf
```

**Note:** Don't update too frequently or some blacklist providers may ban your IP.

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
| `ENABLE_IPV4` | yes | Process IPv4 addresses |
| `ENABLE_IPV6` | yes | Process IPv6 addresses |
| `FORCE` | yes | Auto-create nftables structure if missing |
| `VERBOSE` | yes | Show progress output (set to "no" for cron) |
| `AUTO_WHITELIST` | no | Auto-detect and whitelist server's own IPs (recommended) |
| `NFT_CHAIN_PRIORITY` | -200 | Lower = checked earlier in firewall |
| `CURL_CONNECT_TIMEOUT` | 10 | Connection timeout in seconds |
| `CURL_MAX_TIME` | 30 | Maximum time per download |

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

The whitelist uses proper CIDR subtraction for IPv4, so whitelisting `10.0.0.0/8` will correctly exclude that entire range even if the blacklist contains individual IPs like `10.1.2.3`.

**Note:** IPv6 whitelist uses exact matching only (iprange doesn't support IPv6 CIDR operations).

### Auto-Detect Server IPs

Enable automatic detection of your server's IPs (recommended):

```bash
AUTO_WHITELIST=yes
```

This will:
- Detect all local interface IPs
- Query external services for public IPs (ipv4.o11.net / ipv6.o11.net with fallback to icanhazip.com)
- Uses 5-second timeout for external lookups

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

Set `FORCE=yes` in config (default), or create manually:

```bash
nft add table inet blacklist
nft add set inet blacklist blacklist4 '{ type ipv4_addr; flags interval; auto-merge; }'
nft add set inet blacklist blacklist6 '{ type ipv6_addr; flags interval; auto-merge; }'
nft add chain inet blacklist input '{ type filter hook input priority -200; policy accept; }'
nft add rule inet blacklist input ip saddr @blacklist4 counter drop
nft add rule inet blacklist input ip6 saddr @blacklist6 counter drop
```

### Check if an IP is blocked

```bash
nft get element inet blacklist blacklist4 { 1.2.3.4 }
nft get element inet blacklist blacklist6 { 2001:db8::1 }
```

### Integration with existing firewall

The default priority (-200) ensures the blacklist is checked early. Adjust `NFT_CHAIN_PRIORITY` in config if you need different ordering.

### Large IP sets (100k+ entries)

The script chunks IP additions (5000 per command by default) to avoid command-line limits. However, for very large sets, you may need to increase the kernel netlink buffer:

```bash
# Check current values
sysctl net.core.rmem_max net.core.rmem_default

# Increase for large sets (add to /etc/sysctl.d/99-nftables.conf)
net.core.rmem_max = 8388608
net.core.rmem_default = 8388608

# Apply
sysctl -p /etc/sysctl.d/99-nftables.conf
```

If you see errors like "Message too long" or "No buffer space available", increase these values.

### iptables compatibility mode

On modern Debian/Ubuntu, `iptables` is actually `iptables-nft` - a compatibility layer that translates iptables commands to nftables rules.

**Good news:** Our blacklist uses a separate table (`inet blacklist`), so it won't conflict with iptables-nft rules (which use `ip filter`).

**Caution:**
- `nft flush ruleset` deletes ALL nftables rules, including our blacklist AND iptables-nft rules
- `iptables -F` only flushes iptables-nft tables, our blacklist is unaffected

To check which iptables you're using:
```bash
update-alternatives --query iptables
# or
iptables -V  # shows "nf_tables" if using iptables-nft
```

To see all nftables tables (including iptables-nft compatibility tables):
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

## Migration from ipset-blacklist

The old ipset/iptables version is preserved in the `archive/` directory.

To migrate:

1. Install nftables and run the new script
2. Verify nftables rules are working
3. Remove old iptables/ipset rules:
   ```bash
   iptables -D INPUT -m set --match-set blacklist src -j DROP
   ipset destroy blacklist
   ```

## How It Works

1. Downloads blacklists from configured URLs
2. Extracts IPv4 and IPv6 addresses (handles various formats)
3. Filters out private/reserved ranges (RFC 1918, link-local, etc.)
4. Removes duplicates and sorts
5. Optionally aggregates IPv4 into CIDR blocks (using iprange)
6. Generates an nftables script with atomic flush+add
7. Applies via `nft -f` (all-or-nothing transaction)

The atomic update ensures there's never a gap in protection during updates.

## Files

| Path | Description |
|------|-------------|
| `/usr/local/sbin/update-blacklist.sh` | Main script |
| `/etc/nftables-blacklist/nftables-blacklist.conf` | Configuration |
| `/etc/nftables-blacklist/blacklist.nft` | Generated nftables script |
| `/etc/nftables-blacklist/ip-blacklist.list` | Combined IP list (reference) |
| `/etc/nftables-blacklist/ip-blacklist.list.v4` | IPv4 list only |
| `/etc/nftables-blacklist/ip-blacklist.list.v6` | IPv6 list only |

## License

MIT License - See LICENSE file for details.

## Credits

Originally based on [trick77/ipset-blacklist](https://github.com/trick77/ipset-blacklist).
Rewritten for nftables with IPv6 support.
