#
# cron.d/gpuwatch -- AMD GPU Watchdog
#
# By default, run every 5 minutes
*/5 * * * * th0ma7 [ -x /home/th0ma7/gpuwatch.bash ] && /home/th0ma7/gpuwatch.bash -HWMON >> /var/log/miners/gpuwatch.log 2>&1
