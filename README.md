# crypto - th0ma7
Various derived &amp; home-made shell scripts for `ethminer` Mining

Donnations welcomed at: `0x522d164549E68681dfaC850A2cabdb95686C1fEC`

# Mining Scripts Preamble
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
$ sudo chown -R <myuser>:adm /var/log/miners
```

c) Mount the debugfs filesystem with video group access by adding the follwing to the `/etc/fstab`:
- `gid=44` being group `video` under Ubuntu
- `mode=550` provide read+execute only access to both user & group and prevents access to others
```
# debugfs - Allow video group access
nodev /sys/kernel/debug	   debugfs   defaults,gid=44,mode=550   0  0
```
Now mount the filesystem:
```
$ sudo mount -av
```
Confirm you have proper access:
```
$ ls -lad /sys/kernel/debug
dr-xr-x--- 30 root video 0 fév 18 21:45 /sys/kernel/debug
```

# Ethminer Service
Simple startup script for various releases for `ethminer`:
* https://github.com/ethereum-mining/ethminer/releases  
Loosely influenced by:
* https://gist.github.com/bmatthewshea/9a062c092fd673318f8d208ce44f4f51

Place the files as follow:
- ethminer-init.d      -> `/etc/init.d/ethminer`
- ethminer-default     -> `/etc/default/ethminer`
- ethminer-logrotate.d -> `/etc/logrotate.d/ethminer`

Or using the following commands:
```
$ sudo wget https://raw.githubusercontent.com/th0ma7/crypto/master/ethminer-service/ethminer-init.d --output-document=/etc/init.d/ethminer
$ sudo wget https://raw.githubusercontent.com/th0ma7/crypto/master/ethminer-service/ethminer-default --output-document=/etc/default/ethminer
$ sudo wget https://raw.githubusercontent.com/th0ma7/crypto/master/ethminer-service/ethminer-logrotate.d --output-document=/etc/logrotate.d/ethminer
$ sudo chmod 755 /etc/init.d/ethminer
```

Log files are located under `/var/log/miners/ethminer.log`<br/>
Make sure the log directory is read/write for the user account you use and create initial log file with proper permissions (see Mining Scripts Preamble section).
```
$ sudo mkdir /var/log/miners
$ sudo touch /var/log/miners/ethminer.log
$ sudo chmod 664 /var/log/miners/ethminer.log
$ sudo chown -R <myuser>:adm /var/log/miners
```

Adjust the following in `/etc/default/ethminer` (and also look into other possible details):
- `WALLET` -> Your ethereum wallet
- `RUNAS`  -> User account where the daemon run as (never use `root`!)
- `DAEMON` -> `ethminer` binary location
- `WORKER` -> Identifier or `hostname` you whish to use to identify it online
```
$ sudo perl -p -i -e 's/^RUNAS=.*/RUNAS="<myuser>"/g' /etc/default/ethminer
$ sudo perl -p -i -e 's/WALLET=.*/WALLET="<mywallet>"/g' /etc/default/ethminer
$ sudo perl -p -i -e 's?DAEMON=.*?DAEMON="/opt/ethminer/bin/ethminer"?g' /etc/default/ethminer
$ sudo perl -p -i -e 's/WORKER=.*/WORKER="<myhostname>"/g' /etc/default/ethminer
```

Add & enable the service, reload `systemd` and start the service:
```
$ sudo update-rc.d ethminer defaults
$ sudo update-rc.d ethminer enable
$ sudo systemctl daemon-reload
```
**IMPORTANT:**  Make sure log ethminer.log has propermissions as otherwise it will fail to start! (see above info)
```
$ sudo systemctl restart ethminer
```

# Ethminer Watchdog
Simple script to monitor the GPU of your mining rig along with status of `ethminer` service and restart or reboot if a GPU is hung.  Currently only works with AMD video cards.

Parameters:
- `--HWMON` or `-HWMON`        -> Print GPU temperature & Watt
- `--hs110`                    -> Probe for total rig Wattage from TP-Link HS-110 device
- `--debug`                    -> Activate debug mode
- `--noact` or `--no-act`      -> Simulate action but do not actually restart services or reboot the rig
- `--help`                     -> Show help

Place the files as follow:
- ethminer-watchdog.bash        -> `/usr/local/bin/ethminer-watchdog.bash`
- ethminer-watchdog_default     -> `/etc/default/ethminer-watchdog`
- ethminer-watchdog_cron.d      -> `/etc/cron.d/ethminer-watchdog`
- ethminer-watchdog_logrotate.d -> `/etc/logrotate.d/ethminer-watchdog`

Or using the following commands:
```
$ sudo wget https://raw.githubusercontent.com/th0ma7/crypto/master/ethminer-watchdog/ethminer-watchdog.bash --output-document=/usr/local/bin/ethminer-watchdog.bash
$ sudo wget https://raw.githubusercontent.com/th0ma7/crypto/master/ethminer-watchdog/ethminer-watchdog_default --output-document=/etc/default/ethminer-watchdog
$ sudo wget https://raw.githubusercontent.com/th0ma7/crypto/master/ethminer-watchdog/ethminer-watchdog_cron.d --output-document=/etc/cron.d/ethminer-watchdog
$ sudo wget https://raw.githubusercontent.com/th0ma7/crypto/master/ethminer-watchdog/ethminer-watchdog_logrotate.d --output-document=/etc/logrotate.d/ethminer-watchdog
$ sudo chmod 755 /usr/local/bin/ethminer-watchdog.bash
```

Edit the needed parameters in `/etc/default/ethminer-watchdog` file (see below for quick one-liners):
```
EMAIL=<EMAIL>                                # Email where to send service restart & reboot info
HS110_IP=<IP>                                # IP address of your TP-Link HS110 device, if any
```

Change the username `<USER>` to match your username `/etc/default/ethminer-watchdog`:
```
$ sudo perl -p -i -e 's/<USER>/MY_ACTUAL_USER/g' /etc/default/ethminer-watchdog
```

Change the IP `<IP>` to match your TP-Link HS-110 device, if any:
```
$ sudo perl -p -i -e 's/<IP>/MY_ACTUAL_IP/g' /etc/default/ethminer-watchdog
```

Change the username `<USER>` in the crontab file `/etc/cron.d/ethminer-watchdog`:
```
$ sudo perl -p -i -e 's/<USER>/MY_ACTUAL_USER/g' /etc/cron.d/ethminer-watchdog
```

Log files are located here: `/var/log/miners/ethminer-watchdog.log`<br/>
Make sure the log directory is read/write from the user account you use.
```
$ sudo mkdir /var/log/miners
$ sudo touch /var/log/miners/ethminer-watchdog.log
$ sudo chmod 664 /var/log/miners/ethminer-watchdog.log
$ sudo chown -R <myuser>:adm /var/log/miners
```

The script requires the following:
- `rocm-smi` from the rocm project (https://github.com/RadeonOpenCompute/ROCm)
```
$ wget -qO - http://repo.radeon.com/rocm/apt/debian/rocm.gpg.key | sudo apt-key add -
$ echo "deb [arch=amd64] http://repo.radeon.com/rocm/apt/debian/ bionic main" | sudo tee /etc/apt/sources.list.d/rocm.list
$ sudo apt update
$ sudo apt install rocm-smi
```
- `atiflash` to get further info of cards (https://drive.google.com/file/d/0B60njIARS0fLcEtsNXFfeTZ5LXc/view).  Can probably be found elsewhere, just place it under `/usr/local/bin`.  Once downloaded extract as `/usr/local/bin/atiflash`
```
$ sudo tar -xvf atiflash_linux.tar.xz -C /usr/local/bin
```
- TP-Link `hs100.sh` helper script for total Watt monitoring using HS-110 plugs (https://github.com/ggeorgovassilis/linuxscripts)
```
$ sudo wget https://raw.githubusercontent.com/ggeorgovassilis/linuxscripts/master/tp-link-hs100-smartplug/hs100.sh  --output-document=/usr/local/bin/hs100.sh
$ sudo chmod 755 /usr/local/bin/hs100.sh
```
- `jq` JSON parser
```
$ sudo apt update
$ sudo apt install jq
```
Install `mutt` client:
```
$ sudo apt install mutt
```

Configure `postfix` (dependancy package for `mutt`):
```
┌───────────────────────────┤ Postfix Configuration ├───────────────────────────┐
│                                                                               │ 
│ Please select the mail server configuration type that best meets your needs.  │
│                                                                               │ 
│  No configuration:                                                            │ 
│   Should be chosen to leave the current configuration unchanged.              │ 
│  Internet site:                                                               │ 
│   Mail is sent and received directly using SMTP.                              │ 
│                                                                               │ 
│                                    <Ok>                                       │ 
│                                                                               │ 
└───────────────────────────────────────────────────────────────────────────────┘ 

┌──────┤ Postfix Configuration ├───────┐
│ General type of mail configuration:  │ 
│                                      │ 
│     * No configuration               │ 
│       Internet Site                  │ 
│       Internet with smarthost        │ 
│       Satellite system               │ 
│       Local only                     │ 
│                                      │ 
│       <Ok>           <Cancel>        │ 
│                                      │ 
└──────────────────────────────────────┘ 
```

Create a `.muttrc` in the $HOME directory of the user account the daemon will run into (never use `root`) with the following:
```
set realname = "<yourname>"
set from = "<gmailaddress>"
set use_from = yes
set envelope_from = yes

set smtp_url = "smtps://<gmailid>@gmail.com@smtp.gmail.com:465/"
set smtp_pass = "<gmailpassword>"
set imap_user = "<gmailaddress>"
set imap_pass = "<gmailpassword>"
set folder = "imaps://imap.gmail.com:993"
set spoolfile = "+INBOX"
set ssl_force_tls = yes

# G to get mail
bind index G imap-fetch-mail
set editor = "vim"
set charset = "utf-8"
set record = ''
```

Adjust permissions:
```
$ sudo touch $MAIL
$ sudo chmod 660 $MAIL
$ sudo chmod 600 ~/.muttrc
$ sudo chown `whoami`:mail $MAIL
```

Start `mutt` from the command line.  At first startup it may be impossible to connect:  You must autorise "less secure" connexions in gmail parameters from within your gmail user account settings. See also:
* https://support.google.com/accounts/answer/6010255?hl=en

# tmux
Simple console output script allowing to monitor your system status & hashrate in realtime.

Install `tmux`:
```
$ sudo apt install tmux
```

Place the files as follow:
- tmux.bash        -> `/usr/local/bin/tmux.bash`

Or using the following commands:
```
$ sudo wget https://raw.githubusercontent.com/th0ma7/crypto/master/tmux.bash --output-document=/usr/local/bin/tmux.bash
$ sudo chmod 755 /usr/local/bin/tmux.bash
```

Create a `TTY1` directory under `systemd`:
```
$ sudo mkdir /etc/systemd/system/getty@tty1.service.d
```

Create auto-login rule:
```
$ sudo -s
# cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/local/bin/tmux.bash
StandardInput=tty
StandardOutput=tty
EOF
# exit
```

Test:
```
$ sudo systemctl daemon-reload; systemctl restart getty@tty1.service
==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ===
Authentication is required to restart 'getty@tty1.service'.
Authenticating as: th0ma7,,, (th0ma7)
Password: 
==== AUTHENTICATION COMPLETE ===
```

Validate status:
```
$ systemctl status getty@tty1.service
● getty@tty1.service - Getty on tty1
   Loaded: loaded (/lib/systemd/system/getty@.service; enabled; vendor preset: enabled)
  Drop-In: /etc/systemd/system/getty@tty1.service.d
           └─override.conf
   Active: active (running) since mar 2018-01-02 13:31:35 EST; 1h 26min ago
     Docs: man:agetty(8)
           man:systemd-getty-generator(8)
           http://0pointer.de/blog/projects/serial-console.html
 Main PID: 1596 (tmux.bash)
   CGroup: /system.slice/system-getty.slice/getty@tty1.service
           ├─1596 /bin/sh /usr/local/bin/tmux.bash
           ├─1663 /usr/bin/tmux new-session -s th0ma7-miner-01 -n Mining -d /usr/bin/top -d1 -uth0ma7
           ├─1667 /usr/bin/top -d1 -uth0ma7
           ├─1670 tail -f /var/log/miners/ethminer.log
           ├─1673 /usr/bin/watch -d -t -n10 sensors | awk /^acpitz-virtual-0/,/^temp1.*/
           ├─1677 /usr/bin/watch -t -n1000 /bin/echo && /bin/echo kernel:  && /bin/uname -r
           ├─1688 /usr/bin/sudo /usr/bin/watch -t -n1 /bin/cat /sys/kernel/debug/dri/0/amdgpu_pm_info | awk /^GFX.Clocks/,/^GPU.Load.*/
           ├─1692 /usr/bin/sudo /usr/bin/watch -t -n1 cat /sys/kernel/debug/dri/2/amdgpu_pm_info | awk /^GFX.Clocks/,/^GPU.Load.*/
           ├─1696 /usr/bin/sudo /usr/bin/watch -t -n1 cat /sys/kernel/debug/dri/1/amdgpu_pm_info | awk /^GFX.Clocks/,/^GPU.Load.*/
           ├─1698 /usr/bin/watch -t -n1 /bin/cat /sys/kernel/debug/dri/0/amdgpu_pm_info | awk /^GFX.Clocks/,/^GPU.Load.*/
           ├─1700 /usr/bin/watch -t -n1 cat /sys/kernel/debug/dri/2/amdgpu_pm_info | awk /^GFX.Clocks/,/^GPU.Load.*/
           ├─1717 /usr/bin/watch -t -n1 cat /sys/kernel/debug/dri/1/amdgpu_pm_info | awk /^GFX.Clocks/,/^GPU.Load.*/
           └─1736 /usr/bin/tmux attach -t th0ma7-miner-01

jan 02 13:31:35 th0ma7-miner-01 systemd[1]: Started Getty on tty1.
jan 02 13:31:36 th0ma7-miner-01 sudo[1688]:     root : TTY=pts/4 ; PWD=/ ; USER=root ; COMMAND=/usr/bin/watch -t -n1 /bin/cat /sys/kernel/debug/dri/0/amdgpu_pm_info | awk /^GFX.Clocks/,/^GPU.Load.*/
jan 02 13:31:36 th0ma7-miner-01 sudo[1688]: pam_unix(sudo:session): session opened for user root by root(uid=0)
jan 02 13:31:36 th0ma7-miner-01 sudo[1692]:     root : TTY=pts/5 ; PWD=/ ; USER=root ; COMMAND=/usr/bin/watch -t -n1 cat /sys/kernel/debug/dri/2/amdgpu_pm_info | awk /^GFX.Clocks/,/^GPU.Load.*/
jan 02 13:31:36 th0ma7-miner-01 sudo[1692]: pam_unix(sudo:session): session opened for user root by root(uid=0)
jan 02 13:31:36 th0ma7-miner-01 sudo[1696]:     root : TTY=pts/6 ; PWD=/ ; USER=root ; COMMAND=/usr/bin/watch -t -n1 cat /sys/kernel/debug/dri/1/amdgpu_pm_info | awk /^GFX.Clocks/,/^GPU.Load.*/
jan 02 13:31:36 th0ma7-miner-01 sudo[1696]: pam_unix(sudo:session): session opened for user root by root(uid=0)
```
