cat > /usr/local/etc/rc.d/wireguard-start.sh << 'SCRIPT'
#!/bin/sh
LOG=/var/log/wireguard-start.log

echo "$(date '+%Y-%m-%d %H:%M:%S') === WireGuard modules loading ===" >> "$LOG"

MODULES="libblake2s libblake2s-generic libcurve25519 libcurve25519-generic \
libchacha chacha-neon poly1305-neon libchacha20poly1305 ip6table_nat wireguard"

# 重试3次，每次间隔60秒
for attempt in 1 2 3; do
    ALL_OK=true
    for mod in $MODULES; do
        ko="/lib/modules/${mod}.ko"
        if ! lsmod 2>/dev/null | grep -q "^${mod//-/_} "; then
            if [ -f "$ko" ]; then
                if ! insmod "$ko" 2>>"$LOG"; then
                    ALL_OK=false
                    echo "  attempt $attempt FAIL: $mod" >> "$LOG"
                fi
            else
                echo "  MISSING: $ko" >> "$LOG"
                ALL_OK=false
            fi
        fi
    done
    if $ALL_OK; then
        break
    fi
    echo "  retry $attempt in 60s..." >> "$LOG"
    sleep 60
done

if lsmod | grep -q "^wireguard "; then
    echo "$(date '+%H:%M:%S') ✅ WireGuard loaded" >> "$LOG"
else
    echo "$(date '+%H:%M:%S') ❌ WireGuard FAILED" >> "$LOG"
fi
SCRIPT
chmod +x /usr/local/etc/rc.d/wireguard-start.sh
