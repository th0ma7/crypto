#!/bin/sh
### BEGIN INIT INFO
# Provides:          ethminer
# Required-Start:    $remote_fs $syslog $network $named
# Required-Stop:     $remote_fs $syslog $network $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ethminer start-stop-daemon init script
# Description:       This allows you to start/stop ethminer as if it
#                    were a daemon
### END INIT INFO
# Author: Brady Shea <use@github-comments>
# Source: https://gist.github.com/bmatthewshea/9a062c092fd673318f8d208ce44f4f51

set -e
. /lib/lsb/init-functions


export GPU_FORCE_64BIT_PTR=1
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100

DAEMON="/opt/ethminer/bin/ethminer"
LOGFILE="/var/log/miners/ethminer.log"
#
#WALLET="0812f4b6de7356e209f092dd1ec865d5d9b5e2f6"
WALLET="522d164549E68681dfaC850A2cabdb95686C1fEC"
RUNAS="th0ma7"
WORKER="th0ma7-miner-01"
#
GPU="-G"
#
SERVERS="us1.ethermine.org"
FSERVERS="us2.ethermine.org"
TCPPORT="4444"
SSLPORT="5555"
FARM_RECHECK="2000"

# pool, proxy, solo :
MINING_MODE="pool"
# <= 0.13
STRATUMCLIENT="1"
STRATUMPROTO="0"
# >= 0.14
# stratum+ssl stratum+tcp stratum+tls stratum+tls12 stratum1+ssl stratum1+tcp stratum1+tls stratum1+tls12 stratum2+ssl stratum2+tcp stratum2+tls stratum2+tls12
STRATUMURL="stratum+ssl"
#STRATUMURL="stratum+tcp"
# The current stable OpenCL kernel only supports exactly 8 threads. Thread parameter will be ignored.
CLPARALLELHASH="2"

# Default Settings - Edit /etc/default/ethminer instead
if [ -r /etc/default/ethminer ]; then
        . /etc/default/ethminer
fi

# Find ethminer version
VERSION=`$DAEMON -V 2>&1 | grep -v ^$ | head -1 | awk '{print $NF}'`
echo $VERSION
case $VERSION in
  0.12.0 ) EXTRA_PARAM="-SC $STRATUMCLIENT -SP $STRATUMPROTO -S $SERVERS:$TCPPORT -FS $FSERVERS:$TCPPORT -O $WALLET.$WORKER";;
  0.13.0 ) EXTRA_PARAM="-HWMON -SC $STRATUMCLIENT -SP $STRATUMPROTO -S $SERVERS:$TCPPORT -FS $FSERVERS:$TCPPORT -O $WALLET.$WORKER";;
#  0.14.* ) EXTRA_PARAM="-HWMON -P $STRATUMURL://0x$WALLET.$WORKER@$SERVERS:$SSLPORT -P $STRATUMURL://0x$WALLET.$WORKER@$FSERVERS:$SSLPORT";;
#  0.14.* ) EXTRA_PARAM="-HWMON -P $STRATUMURL://0x$WALLET.$WORKER@$SERVERS:$SSLPORT -P $STRATUMURL://0x$WALLET.$WORKER@$FSERVERS:$SSLPORT --cl-parallel-hash $CLPARALLELHASH --cl-kernel 1";;
  0.14.* ) EXTRA_PARAM="-HWMON -P $STRATUMURL://0x$WALLET.$WORKER@$SERVERS:$SSLPORT -P $STRATUMURL://0x$WALLET.$WORKER@$FSERVERS:$SSLPORT --cl-parallel-hash $CLPARALLELHASH --cl-kernel 1";;
  0.15.0.dev* ) EXTRA_PARAM="-HWMON -P $STRATUMURL://0x$WALLET.$WORKER@$SERVERS:$SSLPORT -P $STRATUMURL://0x$WALLET.$WORKER@$FSERVERS:$SSLPORT --cl-parallel-hash $CLPARALLELHASH --cl-kernel 1";;
  0.15.0rc* ) EXTRA_PARAM="-P $STRATUMURL://0x$WALLET.$WORKER@$SERVERS:$SSLPORT -P $STRATUMURL://0x$WALLET.$WORKER@$FSERVERS:$SSLPORT --cl-parallel-hash $CLPARALLELHASH --cl-kernel 1";;
esac

if [ "$MINING_MODE" = "pool" ]; then
  # Running Stratum Pool connection (-S)
  DAEMON_OPTS="$GPU $EXTRA_PARAM --farm-recheck $FARM_RECHECK"
else
  # Running ETH-PROXY or SOLO mining - Set to farm mode (-F)
  DAEMON_OPTS="$GPU $EXTRA_PARAM --farm-recheck $FARM_RECHECK -SP $STRATUMPROTO -F $SERVERS"
fi

DESC="ethminer start-stop-daemon init script"
NAME=ethminer
PIDFILE=/var/run/$NAME.pid

start() {
        # print expected options
        echo "$DAEMON $DAEMON_OPTS" >> $LOGFILE 2>&1
	# DEBUG - exit
        #echo "$DAEMON $DAEMON_OPTS" && exit 1
        printf "Starting '$NAME'..."
          start-stop-daemon --chuid $RUNAS --start --quiet --make-pidfile --pidfile $PIDFILE --background --startas /bin/bash -- -c "exec $DAEMON $DAEMON_OPTS >> $LOGFILE 2>&1"
        sleep 1
        printf "Done."
}

stop () {
        printf "Stopping '$NAME'..."
        start-stop-daemon --stop --quiet --oknodo --pidfile $PIDFILE
        sleep 1
        printf "Done."
}

status() {
#  status_of_proc -p /var/run/$NAME.pid "" $NAME && exit 0 || exit $?
   status_of_proc $DAEMON "$NAME"
}

case "$1" in
    start)
    start
  ;;
    stop)
    stop
  ;;
    restart)
    stop
    start
  ;;
    status)
    status
  ;;
    *)
    echo "Usage: $NAME {start|stop|restart|status}" >&2
    exit 1
  ;;
esac

exit 0
