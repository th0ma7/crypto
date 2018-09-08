#
# cron.d/ethminer-watchdog -- ethminer & AMD GPU Watchdog
#
# By default, run every 5 minutes
*/5 * * * * <USER> [ -x /usr/local/bin/ethminer-watchdog.bash ] && /usr/local/bin/ethminer-watchdog.bash >> /var/log/miners/ethminer-watchdog.log 2>&1
