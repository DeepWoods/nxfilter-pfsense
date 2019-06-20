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
    echo `ps | grep 'nxd.jar' | grep -v grep | awk '{ print $1 }'` > $pidfile
  fi
}

nxfilter_stop()
{
  if [ -f $pidfile ]; then
    echo -n "Stopping NxFilter..."

    /usr/local/nxfilter/bin/shutdown.sh &

    while [ `pgrep -F $pidfile` ]; do
      echo -n "."
      sleep 1
    done

    rm $pidfile

    echo "OK stopped";
  else
    echo "NxFilter not running. No PID file found."
  fi
}

load_rc_config ${name}
run_rc_command "$1"