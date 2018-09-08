#
# cron.d/ethminer-watchdog -- ethminer & AMD GPU Watchdog
#
# By default, run every 5 minutes
#*/5 * * * * <user> [ -x /usr/local/bin/ethminer-watchdog.bash ] && /usr/local/bin/ethminer-watchdog.bash --noact >> /var/log/miners/ethminer-watchdog.log 2>&1
*/5 * * * * <user> [ -x /usr/local/bin/ethminer-watchdog.bash ] && /usr/local/bin/ethminer-watchdog.bash >> /var/log/miners/ethminer-watchdog.log 2>&1
