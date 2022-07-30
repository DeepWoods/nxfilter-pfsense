#!/bin/sh

# install-nxfilter.sh <version>
# Installs NxFilter DNS filter software on pfSense.

clear
# The latest version of NxFilter:
NXFILTER_VERSION=$1
if [ -z "$NXFILTER_VERSION" ]; then
  echo "NxFilter version not supplied, checking nxfilter.org for the latest version..."
  NXFILTER_VERSION=$(
    curl -sL 'https://nxfilter.org/curver.php' 2>/dev/null
  )

  if ! $(echo "$NXFILTER_VERSION" | egrep -q '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'); then
    echo "Fetched version \"$NXFILTER_VERSION\" doesn't make sense"
    echo "If that's correct, run this script again with \"$NXFILTER_VERSION\" as the first argument:  sh install-nxfilter.sh \"$NXFILTER_VERSION\""
    exit 1
  fi

  printf "OK to download and install NxFilter version $NXFILTER_VERSION ? [y/N] " && read RESPONSE
  case $RESPONSE in
    [Yy] ) ;;
    * ) exit 1;;
  esac
fi
NXFILTER_SOFTWARE_URI="http://pub.nxfilter.org/nxfilter-${NXFILTER_VERSION}.zip"

# service script
SERVICE_SCRIPT_URI="https://raw.githubusercontent.com/DeepWoods/nxfilter-pfsense/master/rc.d/nxfilter.sh"


# If pkg-ng is not yet installed, bootstrap it:
if ! /usr/sbin/pkg -N 2> /dev/null; then
  echo "FreeBSD pkgng not installed. Installing..."
  env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg bootstrap
  echo " ok"
fi

# If installation failed, exit:
if ! /usr/sbin/pkg -N 2> /dev/null; then
  echo "ERROR: pkgng installation failed. Exiting."
  exit 1
fi

# Determine this installation's Application Binary Interface
ABI=`/usr/sbin/pkg config abi`

# FreeBSD package source:
FREEBSD_PACKAGE_URL="https://pkg.freebsd.org/${ABI}/latest/"

# FreeBSD package list:
FREEBSD_PACKAGE_LIST_URL="${FREEBSD_PACKAGE_URL}packagesite.pkg"

# Stop NxFilter if it's already running
if [ -f /usr/local/etc/rc.d/nxfilter.sh ]; then
  if [ ! -z "$(ps ax | grep "/usr/local/nxfilter/nxd.jar" | grep -v grep | awk '{ print $1 }')" ]; then
    echo -n "Stopping the NxFilter service..."
    /usr/sbin/service nxfilter.sh stop
    echo " ok"
  fi
fi

# Make sure nxd.jar isn't still running for some reason
if [ ! -z "$(ps ax | grep "/usr/local/nxfilter/nxd.jar" | grep -v grep | awk '{ print $1 }')" ]; then
  echo -n "Killing nxd.jar process..."
  /bin/kill -15 `ps ax | grep "/usr/local/nxfilter/nxd.jar" | grep -v grep | awk '{ print $1 }'`
  echo " ok"
fi

# If an installation exists, back up configuration:
if [ -d /usr/local/nxfilter/conf ]; then
  echo "Backing up existing NxFilter config..."
  BACKUPFILE=/var/backups/nxfilter-`date +"%Y%m%d_%H%M%S"`.tgz
  /usr/bin/tar -vczf ${BACKUPFILE} /usr/local/nxfilter/conf/cfg.properties /usr/local/nxfilter/db/config.h2.db
fi

# Add the fstab entries required for OpenJDK to persist:
if [ $(grep -c fdesc /etc/fstab) -eq 0 ]; then
  echo -n "Adding fdesc filesystem to /etc/fstab..."
  echo -e "fdesc\t\t\t/dev/fd\t\tfdescfs\trw\t\t0\t0" >> /etc/fstab
  echo " ok"
fi

if [ $(grep -c proc /etc/fstab) -eq 0 ]; then
  echo -n "Adding procfs filesystem to /etc/fstab..."
  echo -e "proc\t\t\t/proc\t\tprocfs\trw\t\t0\t0" >> /etc/fstab
  echo " ok"
fi

# Run mount to mount the two new filesystems:
echo -n "Mounting new filesystems..."
/sbin/mount -a
echo " ok"

# Install OpenJDK JRE and dependencies:
# -F skips a package if it's already installed, without throwing an error.
echo "Installing required packages..."

fetch ${FREEBSD_PACKAGE_LIST_URL}
tar vfx packagesite.pkg

AddPkg () {
 	pkgname=$1
  pkg unlock -yq $pkgname
 	pkginfo=`grep "\"name\":\"$pkgname\"" packagesite.yaml`
 	pkgvers=`echo $pkginfo | pcregrep -o1 '"version":"(.*?)"' | head -1`
	pkgurl="${FREEBSD_PACKAGE_URL}`echo $pkginfo | pcregrep -o1 '"path":"(.*?)"' | head -1`"

	# compare version for update/install
 	if [ `pkg info | grep -c $pkgname-$pkgvers` -eq 1 ]; then
	  echo "Package $pkgname-$pkgvers already installed."
	else
	  env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add -f "$pkgurl"

	  # if update openjdk8 then force detele snappyjava to reinstall for new version of openjdk
	  #if [ "$pkgname" == "openjdk8" ]; then
	  #  pkg unlock -yq snappyjava
	  #  env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete snappyjava
    #fi
  fi
  pkg lock -yq $pkgname
}

#Add the following Packages for installation or reinstallation (if something was removed)
AddPkg png
AddPkg freetype2
AddPkg fontconfig
AddPkg alsa-lib
AddPkg libfontenc
AddPkg mkfontscale
AddPkg dejavu
AddPkg giflib
AddPkg xorgproto
AddPkg libXdmcp
AddPkg libpthread-stubs
AddPkg libXau
AddPkg libxcb
AddPkg libICE
AddPkg libSM
AddPkg libX11
AddPkg libXfixes
AddPkg libXext
AddPkg libXi
AddPkg libXt
AddPkg libXtst
AddPkg libXrender
AddPkg libinotify
AddPkg javavmwrapper
AddPkg java-zoneinfo
#AddPkg expat
#AddPkg libxml2
AddPkg openjdk8

# Clean up downloaded package manifest:
rm packagesite.*
echo " ok"

# Switch to a temp directory for the NxFilter download:
cd `mktemp -d -t nxfilter`

echo -n "Downloading v${NXFILTER_VERSION} NxFilter..."
/usr/bin/fetch ${NXFILTER_SOFTWARE_URI}
echo " ok"

# Unpack the archive into the /usr/local directory:
echo -n "Installing NxFilter in /usr/local/nxfilter..."
/bin/mkdir -p /usr/local/nxfilter
/usr/bin/tar zxf nxfilter-${NXFILTER_VERSION}.zip -C /usr/local/nxfilter
echo " ok"

# Fetch the service script from github:
echo -n "Creating nxfilter.sh service script in /usr/local/etc/rc.d/ ..."
#/usr/bin/fetch -o /usr/local/etc/rc.d/nxfilter.sh ${SERVICE_SCRIPT_URI}
# Create the file instead.
/bin/cat <<"EOF" >/usr/local/etc/rc.d/nxfilter.sh
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
    # check for leftover pid file
    if [ -f $pidfile ]; then
      # check if file contains something
      if `grep -q '[^[:space:]]' < "$pidfile"` ; then
        # check to see if pid from file is actually running, if not remove pid file
        if `cat "$pidfile" | xargs ps -p >/dev/null` ; then
          echo "NxFilter process is already running"
          exit 1
        else
          rm $pidfile
        fi
      else
        rm $pidfile
      fi
    fi 

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
    # check if file contains something
    if `grep -q '[^[:space:]]' < "$pidfile"` ; then
      # check to see if pid from file is actually running, if not remove pid file
      if `cat "$pidfile" | xargs ps -p >/dev/null` ; then
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
      echo "NxFilter not running. No PID found."
      rm $pidfile
    fi
  else
    echo "NxFilter not running. No PID file found."
  fi 
}

load_rc_config ${name}
run_rc_command "$1"
EOF
echo " ok"

# add execute permissions
echo -n "Setting execute permissons for scripts..."
chmod +x /usr/local/etc/rc.d/nxfilter.sh
chmod +x /usr/local/nxfilter/bin/*.sh
echo " ok"

# Add the startup variable to rc.conf.local.
# Eventually, this step will need to be folded into pfSense, which manages the main rc.conf.
# In the following comparison, we expect the 'or' operator to short-circuit, to make sure the file exists and avoid grep throwing an error.
if [ ! -f /etc/rc.conf.local ] || [ $(grep -c nxfilter_enable /etc/rc.conf.local) -eq 0 ]; then
  echo -n "Enabling the NxFilter service..."
  echo "nxfilter_enable=YES" >> /etc/rc.conf.local
  echo " ok"
fi

# Restore the backup configuration:
if [ ! -z "${BACKUPFILE}" ] && [ -f ${BACKUPFILE} ]; then
  echo "Restoring NxFilter config..."
  mv /usr/local/nxfilter/conf /usr/local/nxfilter/conf-`date +%Y%m%d-%H%M`
  /usr/bin/tar -vxzf ${BACKUPFILE} -C /
fi

echo "Running the NxFilter service..."
/usr/sbin/service nxfilter.sh start
echo "All done!"