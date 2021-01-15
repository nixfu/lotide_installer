Since I have installed a test/dev environment of lotide/hitide in VMs a few times now, and my rule is if I have to do it more than once, it is time to automate it.

This fast and rough script automates the whole download/install/configuration process and at the end you get postgres installed/setup, and lotide/hitide setup as systemd services all on the same system. The script assumes you are running it as root or via sudo.

Warning, it has no error checking, or ability to re-run and skip previous steps etc. At the moment it is just the commands I normally did by hand when setting up quick dev/test VMs. But that also means this script can also serve as a rough document to help people see the steps to do if they want to install it manually.

You can tweak the settings using the environment variables at the top. The default settings I used are good for getting an install working on a test vm on your local network.

After firing up another VM image copy of a bare bones Ubuntu 20.04 server and running it, this script takes about 30-40 minutes to do install all the prerequisite packages, setup postgres, download and compile both lotide, and hitide, and set everything needed to run them as system services.  Most of the time obviously is spent compiling the rust code.
