#
# cron.d/gpuwatch -- AMD GPU Watchdog
#
# By default, run every 5 minutes
*/5 * * * * th0ma7 [ -x /usr/local/bin/gpuwatch.bash ] && /usr/local/bin/gpuwatch.bash -HWMON >> /var/log/miners/gpuwatch.log 2>&1
