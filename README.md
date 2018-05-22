# th0ma7
Various derived &amp; home-made shell scripts for OpenWRT &amp; Mining

# Mining scripts preamble
Scripts are expected to be run within a dedicated user account (e.g. not `root`).<br/>
I recommend doing the following to ensure your user account as sufficient priviledges.

a) Add the user to the adm & video groups
```
$ sudo usermod -a -G adm <myuser>
$ sudo usermod -a -G video <myuser>
```

b) Create a `log` directory:
```
$ sudo mkdir /var/log/miners
$ sudo touch /var/log/miners/ethminer.log
$ sudo chmod 664 /var/log/miners/ethminer.log
$ sudo chown -R <myuser>:adm /var/log/miners
```

c) Mount the debugfs filesystem with video group access by adding the follwing to the `/etc/fstab`:
```
# debugfs - Allow video group access
nodev /sys/kernel/debug	   debugfs   defaults,gid=44,mode=550   0  0
```
Manually mount:
```
$ sudo mount -av
```
Confirm you have proper access:
```
$ ls -lad /sys/kernel/debug
dr-xr-x--- 30 root video 0 fév 18 21:45 /sys/kernel/debug
```

# ethminer
Simple startup script for various releases for ethminer:
* https://github.com/ethereum-mining/ethminer/releases  
Loosely influenced by:
* https://gist.github.com/bmatthewshea/9a062c092fd673318f8d208ce44f4f51

Place the files as follow:
- ethminer-init.d      -> `/etc/init.d/ethminer`
- ethminer-default     -> `/etc/default/ethminer`
- ethminer-logrotate.d -> `/etc/logrotate.d/ethminer`

Adjust your `WALLET` in `/etc/default/ethminer`

Reload systemd and start the service:
```
$ sudo systemctl daemon-reload
$ sudo systemctl restart ethminer
```

Log files are located under `/var/log/miners/ethminer.log`<br/>
Make sure the log directory is read/write from the user account you use.

# gpuwatch
Simple script to monitor the GPU of your mining rig and restart or reboot if a GPU is hung.<br/>
Currently only works with the conjunction of AMD video cards & ethereum

Place the files as follow:
- gpuwatch.bash        -> `/usr/local/bin/gpuwatch.bash`
- gpuwatch-cron.d      -> `/etc/cron.d/gpuwatch`
- gpuwatch-logrotate.d -> `/etc/logrotate.d/gpuwatch`

Adjust the username used in `/etc/cron.d/gpuwatch` file to match yours.

Log files are located here: `/var/log/miners/gpuwatch.log`<br/>
Make sure the log directory is read/write from the user account you use.

TODO:
- Document how to install & setup mutt for email relaying

# tmux
Simple console output script allowing to monitor your system status & hashrate in realtime.

Place the files as follow:
- tmux.bash        -> `/usr/local/bin/tmux.bash`

TODO:
- Dynamic calculation of tmux screens depending of number of GPU detected
- Further document howto setup systemd
