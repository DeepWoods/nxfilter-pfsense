nxfilter-pfsense
=============

A script that installs NxFilter software on pfSense.  Derived from the [unifi-pfsense](https://github.com/unofficial-unifi/unifi-pfsense) repository.

Purpose
-------

The objective of this project is to develop and maintain a script that installs [NxFilter](https://www.nxfilter.org/) DNS based web filter software on FreeBSD-based systems, particularly the [pfSense](http://www.pfsense.org/) firewall.

Status
------

The project provides an rc script to start and stop the NxFilter service and an installation script to automatically download and install everything, including the startup script.

Compatibility
-------------

The script is known to work on FreeBSD-based systems, including pfSense, OPNsense, FreeNAS, and more.

> **Warning**This script *will destroy* a legacy BIOS system booting from an MBR formatted ZFS root volume; see [#168](https://github.com/unofficial-unifi/unifi-pfsense/issues/168). Again, using this script on a system with an MBR formatted ZFS root volume will break your system. It appears that one of the dependency packages may cause this. We have not isolated which. To avoid this problem, use UEFI mode if available, use GPT partitions, or use a filesystem other than ZFS.
> 
:bangbang:If you have already set up your system to use legacy BIOS, MBR partitons, and ZFS, then **do not run this script.**:bangbang:

Challenges
----------

Because the NxFilter software is proprietary, it cannot be built from source and cannot be included directly in a package. To work around this, we can download the NxFilter software directly from the NxFilter homepage during the installation script process.

Upgrading pfSense
-----------------

The pfSense updater will remove everything you install that didn't come through pfSense, including the packages installed by this script.

Before updating pfSense, save a backup of your NxFilter configuration to another system.

After updating pfSense, you will need to run this script again to restore the dependencies and the software.  You can then restore your previous configuration from the saved backup file, stop NxFilter and copy the config.h2.db into /usr/local/nxfilter/db directory.

Upgrading
------------------

At the very least, backup your configuration before proceeding.

Be sure to track NxFilter's release notes for information on the changes and what to expect. Proceed with caution.

Usage
------------

To install NxFilter and the rc startup script:

1. Log into the pfSense webConfigurator(System- > Advanced -> Admin Access) and change the TCP port to something other than port 80 and disable the WebGUI redirect rule.  NxFilter GUI and block page will need to use port 80.
2. In the webConfigurator, disable the DNS resolver(Services -> DNS Resolver -> General Settings).  NxFilter provides filtering DNS services on port 53.
3. In the webConfigurator, create firewall rules(Firewall -> Rules -> LAN) to allow access to the LAN address for NxFilter udp ports 53, 1813 and tcp ports 80, 443, 19002:19004
4. Log in to the pfSense command line shell as root.
5. Run these commands, which downloads the install script from this Github repository and then executes it with sh:

  ```
    curl -L -O 'https://raw.githubusercontent.com/DeepWoods/nxfilter-pfsense/master/install-nxfilter.sh' 
    sh install-nxfilter.sh
  ```

The install script will install dependencies, download the NxFilter software, make some adjustments and start the NxFilter application.

Starting and Stopping
---------------------

To start and stop NxFilter, use the `service` command from the command line.

- To start NxFilter:

  ```
    service nxfilter.sh start
  ```
  NxFilter takes a minute or two to start the web interface. The 'start' command exits immediately while the startup continues in the background.

- To stop NxFilter:

  ```
    service nxfilter.sh stop
  ```

Troubleshooting
---------------
The first step with any issue should be to stop and start the NxFilter service.  You should then check the nxfilter.log file in the /usr/local/nxfilter/log/ directory for errors.

`grep -i error /usr/local/nxfilter/log/nxfilter.log`

Issues with the script might include problems downloading packages, installing packages, interactions with pfSense such as dependency packages being deleted after updates, or incorrect dependencies being downloaded. Feel free to open an issue for anything like this.

Issues with the NxFilter software might include not starting up, not listening on port 53, exiting with a port conflict, stopping after startup, memory issues, file permissions, dependency conflicts, etc.. You should troubleshoot these issues as you would on any other installation of NxFilter. The answers to most questions about setting up or troubleshooting NxFilter are found most quickly on the [NxFilter forums](https://forum.nxfilter.org/).

It may turn out that some issue with the NxFilter software is caused by something this script is doing.  In a case like that, if you can connect the behavior of the NxFilter software with the actions taken by the script, please open an issue, or, better yet, fork and fix and submit a pull request.

### Java compatibility on FreeBSD

This script may create a conflict that breaks Java on a FreeBSD upgrade. To resolve this conflict do the following:

  ```
pkg unlock -yq javavmwrapper
pkg unlock -yq java-zoneinfo
pkg unlock -yq openjdk8
pkg unlock -yq snappyjava
pkg unlock -yq snappy
pkg remove -y javavmwrapper
pkg remove -y java-zoneinfo
  ```

Uninstalling
------------

This script does three things:
1. Download and install required dependency packages
2. Download and unpack the NxFilter software from Jahastech
3. Install an rc script so that the NxFilter softward can be started and stopped with `service`

Uninstalling therefore means one of two things:
- Removing the NxFilter software at `/usr/local/nxfilter` and removing the rc script at `/usr/local/etc/rc.d/nxfilter.sh`
- Removing the dependency packages that were installed

### Uninstall the NxFilter software

1. Back up your configuration, if you intend to keep it.
2. Remove the NxFilter software and rc script:
    ```
      rm -rf /usr/local/nxfilter
      rm /usr/local/etc/rc.d/nxfilter.sh
    ```

### Removing the dependency packages

To remove the packages that were installed by this script, you can go through the list of packages that were installed and remove them (look for the AddPkg lines). You will have to determine for yourself whether anything else on your system might still be using the packages installed by this script. Removing a package that is in use by something else will break that and other thing.

> **Note** that, on pfSense, all of them will probably be removed anyway the next time you update pfSense.
>

Contributing
------------

By all means, feel free to contribute!  


Licensing
---------

This project is licensed according to the two-clause BSD license.

The NxFilter software is licensed by Jahastech according to the license file included with the software.

Resources
----------

- [NxFilter product information page](https://nxfilter.org/)
- [NxFilter downloads](https://nxfilter.org/p4/download/)
- [NxFilter documentation and tutorial](https://tutorial.nxfilter.org/)
- [NxFilter support forum](https://forum.nxfilter.org/)
- [NxFilter Reddit support forum](https://www.reddit.com/r/nxfilter/)