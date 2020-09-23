nxfilter-pfsense
=============

A script that installs NxFilter software on pfSense.  Derived from [unifi-pfsense](https://github.com/gozoinks/unifi-pfsense) repository.

Purpose
-------

The objective of this project is to develop and maintain a script that installs [NxFilter](https://www.nxfilter.org/p3/) DNS based web filter software on FreeBSD-based systems, particularly the [pfSense](http://www.pfsense.org/) firewall.

Status
------

The project provides an rc script to start and stop the NxFilter service and an installation script to automatically download and install everything, including the startup script.

Challenges
----------

Because the NxFilter software is proprietary, it cannot be built from source and cannot be included directly in a package. To work around this, we can download the NxFilter software directly from the NxFilter homepage during the installation script process.

Licensing
---------

This project is licensed according to the two-clause BSD license.

The NxFilter software is licensed by Jahastech according to the license file included with the software.

Upgrading
------------------

At the very least, backup your configuration before proceeding.

Be sure to track NxFilter's release notes for information on the changes and what to expect. Proceed with caution.

Usage
------------

To install NxFilter and the rc startup script:

1. Log into the pfSense webConfigurator(System- > Advanced -> Admin Access) and change the TCP port to something other than port 80 and disable the WebGUI redirect rule.  NxFilter GUI and block page will need to use port 80.
2. In the webConfigurator, disable the DNS resolver(Services -> DNS Resolver -> General Settings).  NxFilter provides filtering DNS services on port 53.
3. In the webConfigurator, create firewall rules(Firewall -> Rules -> LAN) to allow access to LAN address for NxFilter udp ports 53, 1813 and tcp ports 80, 443, 19002:19004
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

Contributing
------------

By all means, feel free to contribute!  

Resources
----------

- [NxFilter product information page](https://nxfilter.org/p3/)
- [NxFilter downloads](https://nxfilter.org/p3/download/)
- [NxFilter documentation and tutorial](https://nxfilter.org/tutorial.html)
- [NxFilter support forum](https://www.reddit.com/r/nxfilter/)
