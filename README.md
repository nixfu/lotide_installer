Since I have installed a test/dev environment of lotide/hitide in VMs a few times now, and my rule is if I have to do it more than once, it is time to automate it.

These fast and rough script automates the whole download/install/configuration process and at the end you get postgres installed/setup, and lotide/hitide setup as systemd services all on the same system, or all setup and running as docker containers. 

The scripts assume you are running as root or via sudo.

Warning, these have no error checking, or ability to re-run and skip previous steps etc. At the moment it is just the commands I normally did by hand when setting up quick dev/test environment. But that also means the scripts can also serve as a rough document to help people see the steps to do if they want to install it manually.

You can tweak the settings using the environment variables at the top. The default settings I used are good for getting an install working on a test vm on your local network. The docker script will need the hostnames/ip's of the hosts set to your environment before running.

The standalone script takes about 30-40 mins to download, compile(most of the time) and install everything.  The docker install is much faster since it is just downloading binaries.
