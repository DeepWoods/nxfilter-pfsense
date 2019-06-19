#!/bin/sh

# REQUIRE: FILESYSTEMS
# REQUIRE: NETWORKING
# PROVIDE: NxFilter

. /etc/rc.subr

name="nxfilter"
rcvar="nxfilter_enable"
start_cmd="nxfilter_start"
stop_cmd="nxfilter_stop"

pidfile="/var/run/${name}.pid"

load_rc_config ${name}

nxfilter_start()
{
  if checkyesno ${rcvar}; then
    echo "Starting NxFilter..."
    /usr/local/nxfilter/bin/startup.sh -d 
    echo $! > $pidfile
  fi
}

nxfilter_stop()
{
  if [ -f $pidfile ]; then
    echo -n "Stopping NxFilter..."

    /usr/local/nxfilter/bin/shutdown.sh 

    while [ `pgrep -F $pidfile` ]; do
      echo -n "."
      sleep 5
    done

    rm $pidfile

    echo " stopped";
  else
    echo "NxFilter not running. No PID file found."
  fi
}

run_rc_command "$1"