# th0ma7
Various derived &amp; home-made shell scripts for OpenWRT &amp; Mining

Donnations welcomed at: `0x522d164549E68681dfaC850A2cabdb95686C1fEC`

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

Or using the following commands:
```
$ sudo wget https://raw.githubusercontent.com/th0ma7/th0ma7/master/ethminer/ethminer-init.d --output-document=/etc/init.d/ethminer
$ sudo wget https://raw.githubusercontent.com/th0ma7/th0ma7/master/ethminer/ethminer-default --output-document=/etc/default/ethminer
$ sudo wget https://raw.githubusercontent.com/th0ma7/th0ma7/master/ethminer/ethminer-logrotate.d --output-document=/etc/logrotate.d/ethminer
$ sudo chmod 755 /etc/init.d/ethminer
```

Adjust the following in `/etc/default/ethminer` (and also look into other possible details):
- `WALLET` -> Your ethereum wallet
- `RUNAS`  -> User account where the daemon run as (not root!)
- `DAEMON` -> `ethminer` binary location
- `WORKER` -> Identifier or `hostname` you whish to use to identify it online
```
$ sudo perl -p -i -e 's/^RUNAS=.*/RUNAS="<myuser>"/g' /etc/default/ethminer
$ sudo perl -p -i -e 's/WALLET=.*/WALLET="<mywallet>"/g' /etc/default/ethminer
$ sudo perl -p -i -e 's?DAEMON=.*?DAEMON="/opt/ethminer/bin/ethminer"?g' /etc/default/ethminer
$ sudo perl -p -i -e 's/WORKER=.*/WORKER="<myhostname>"/g' /etc/default/ethminer
```

Reload systemd and start the service:
```
$ sudo update-rc.d ethminer defaults
$ sudo update-rc.d ethminer enable
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

Or using the following commands:
```
$ sudo wget https://raw.githubusercontent.com/th0ma7/th0ma7/master/gpuwatch/gpuwatch.bash --output-document=/usr/local/bin/gpuwatch.bash
$ sudo wget https://raw.githubusercontent.com/th0ma7/th0ma7/master/gpuwatch/gpuwatch-cron.d --output-document=/etc/cron.d/gpuwatch
$ sudo wget https://raw.githubusercontent.com/th0ma7/th0ma7/master/gpuwatch/gpuwatch-logrotate.d --output-document=/etc/logrotate.d/gpuwatch
$ sudo chmod 755 /usr/local/bin/gpuwatch.bash
```

Adjust the username used in `/etc/cron.d/gpuwatch` file to match yours.
```
$ sudo perl -p -i -e 's/ th0ma7 / <myuser> /g' /etc/cron.d/gpuwatch
```

Log files are located here: `/var/log/miners/gpuwatch.log`<br/>
Make sure the log directory is read/write from the user account you use.

Install `mutt` client:
```
$ sudo apt-get install mutt
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

In the useri account the daemon will run into (not `root`), create a `.muttrc` with the following:
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

Place the files as follow:
- tmux.bash        -> `/usr/local/bin/tmux.bash`

TODO:
- Dynamic calculation of tmux screens depending of number of GPU detected
- Further document howto setup systemd
