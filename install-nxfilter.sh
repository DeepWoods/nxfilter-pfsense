#!/bin/sh

# install-nxfilter.sh <version>
# Installs NxFilter DNS filter software on pfSense.

clear
# The latest version of NxFilter:
NXFILTER_VERSION=$1
if [ -z "$NXFILTER_VERSION" ]; then
  echo "Version not supplied, fetching latest"
  NXFILTER_VERSION=$(
    curl -sL 'https://nxfilter.org/p3/download' -H 'X-Requested-With: XMLHttpRequest' | grep -Eo "(http|https)://pub.nxfilter.org/nxfilter-[a-zA-Z0-9./?=_-]*.zip" | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" 2>/dev/null
  )

  if ! $(echo "$NXFILTER_VERSION" | egrep -q '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'); then
    echo "Fetched version \"$NXFILTER_VERSION\" doesn't make sense"
    echo "If that's correct, run this again with it as the first argument"
    exit 1
  fi

  printf "Is version $NXFILTER_VERSION OK? [y/N] " && read RESPONSE
  case $RESPONSE in
    [Yy] ) ;;
    * ) exit 1;;
  esac
fi
NXFILTER_SOFTWARE_URI="http://pub.nxfilter.org/nxfilter-${NXFILTER_VERSION}.zip"

# service script
SERVICE_SCRIPT_URI="https://raw.githubusercontent.com/DeepWoods/nxfilter-pfsense/master/rc.d/nxfilter"


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
FREEBSD_PACKAGE_URL="https://pkg.freebsd.org/${ABI}/latest/All/"

# FreeBSD package list:
FREEBSD_PACKAGE_LIST_URL="https://pkg.freebsd.org/${ABI}/latest/packagesite.txz"

# Stop NxFilter if it's already running
if [ -f /usr/local/etc/rc.d/nxfilter ]; then
  echo -n "Stopping the NxFilter service..."
  /usr/sbin/service nxfilter stop
  echo " ok"
fi

# Make sure nxd.jar isn't still running for some reason
if [ $(ps ax | grep "/usr/local/nxfilter/nxd.jar" | grep -v grep) -ne 0 ]; then
  echo -n "Killing nxd.jar process..."
  /bin/kill -15 `ps ax | grep "/usr/local/nxfilter/nxd.jar" | grep -v grep | awk '{ print $1 }'`
  echo " ok"
fi

# Add the fstab entries apparently required for OpenJDK to persist:
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
tar xv -C / -f /usr/local/share/pfSense/base.txz ./usr/bin/install

fetch ${FREEBSD_PACKAGE_LIST_URL}
tar vfx packagesite.txz

AddPkg () {
 	pkgname=$1
 	pkginfo=`grep "\"name\":\"$pkgname\"" packagesite.yaml`
 	pkgvers=`echo $pkginfo | pcregrep -o1 '"version":"(.*?)"' | head -1`

	# compare version for update/install
 	if [ `pkg info | grep -c $pkgname-$pkgvers` -eq 1 ]; then
			echo "Package $pkgname-$pkgvers already installed."
		else
			env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add -f ${FREEBSD_PACKAGE_URL}${pkgname}-${pkgvers}.txz
		fi
}

AddPkg jpeg-turbo
AddPkg cyrus-sasl
AddPkg xorgproto
AddPkg pixman
AddPkg png
AddPkg libssh2
AddPkg mpfr
AddPkg jbigkit
AddPkg alsa-lib
AddPkg freetype2
AddPkg fontconfig
AddPkg libXdmcp
AddPkg libpthread-stubs
AddPkg libXau
AddPkg libxcb
AddPkg libICE
AddPkg libSM
AddPkg java-zoneinfo
AddPkg libX11
AddPkg libXfixes
AddPkg libXext
AddPkg libXi
AddPkg libXt
AddPkg libfontenc
AddPkg mkfontscale
AddPkg dejavu
AddPkg libXtst
AddPkg libXrender
AddPkg libinotify
AddPkg javavmwrapper
AddPkg giflib
AddPkg openjdk8-jre


# Clean up downloaded package manifest:
rm packagesite.*

echo " ok"

# Switch to a temp directory for the NxFilter download:
cd `mktemp -d -t nxfilter`

echo -n "Downloading NxFilter..."
/usr/bin/fetch ${NXFILTER_SOFTWARE_URI}
echo " ok"

# Unpack the archive into the /usr/local directory:
echo -n "Installing NxFilter in /usr/local/nxfilter..."
/bin/mkdir -p /usr/local/nxfilter
/usr/bin/tar zxf nxfilter-${NXFILTER_VERSION}.zip -C /usr/local/nxfilter
echo " ok"


# Fetch the service script from github:
echo -n "Downloading service script..."
/usr/bin/fetch -o /usr/local/etc/rc.d/nxfilter ${SERVICE_SCRIPT_URI}
echo " ok"

# add execute permissions
chmod +x /usr/local/etc/rc.d/nxfilter
chmod +x /usr/local/nxfilter/bin/*.sh

# Add the startup variable to rc.conf.local.
# Eventually, this step will need to be folded into pfSense, which manages the main rc.conf.
# In the following comparison, we expect the 'or' operator to short-circuit, to make sure the file exists and avoid grep throwing an error.
if [ ! -f /etc/rc.conf.local ] || [ $(grep -c nxfilter_enable /etc/rc.conf.local) -eq 0 ]; then
  echo -n "Enabling the NxFilter service..."
  echo "nxfilter_enable=YES" >> /etc/rc.conf.local
  echo " ok"
fi

echo -n "Starting the NxFilter service..."
/usr/sbin/service nxfilter start
echo " All done!"