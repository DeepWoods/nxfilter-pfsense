#!/bin/sh

# REQUIRE: FILESYSTEMS NETWORKING
# PROVIDE: nxfilter

. /etc/rc.subr

name="nxfilter"
desc="NxFilter DNS filter."
rcvar="nxfilter_enable"
start_cmd="nxfilter_start"
stop_cmd="nxfilter_stop"

pidfile="/var/run/${name}.pid"

nxfilter_start()
{
  if checkyesno ${rcvar}; then
    echo "Starting NxFilter..."
    /usr/local/nxfilter/bin/startup.sh -d &
    # wait for process to start before adding pid to file
    x=1
    while [ "$x" -le 15 ];
    do
        ps | grep 'nxd.jar' | grep -v grep >/dev/null
        if [ $? -eq 0 ]; then
            break
        fi
        echo -n "."
        sleep 1
        x=$(( x + 1 ))
    done
    echo `ps | grep 'nxd.jar' | grep -v grep | awk '{ print $1 }'` > $pidfile
    echo " OK"
  fi
}

nxfilter_stop()
{
  if [ -f $pidfile ]; then
    # check to be sure pid from file is actually running
    if `cat $pidfile | xargs ps -p >/dev/null` ; then
        echo "Stopping NxFilter..."
        /usr/local/nxfilter/bin/shutdown.sh &

        while [ `pgrep -F $pidfile 2>/dev/null` ]; do
            echo -n "."
            sleep 1
        done
    fi
    rm $pidfile

    echo "OK stopped";
  else
    echo "NxFilter not running. No PID file found."
  fi
}

load_rc_config ${name}
run_rc_command "$1"