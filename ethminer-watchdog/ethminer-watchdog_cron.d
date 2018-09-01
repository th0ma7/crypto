#
# cron.d/ethminer-watchdog -- ethminer & AMD GPU Watchdog
#
# By default, run every 5 minutes
*/5 * * * * th0ma7 [ -x /usr/local/bin/ethminer-watchdog.bash ] && /usr/local/bin/ethminer-watchdog.bash --HWMON >> /var/log/miners/ethminer-watchdog.log 2>&1
