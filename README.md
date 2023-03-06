# perfSONAR Test Bed Host for Bare Metal

This directory contains infrastructure for running a multi-VM system
on bare metal as part of the perfSONAR test bed.


## Prerequisites

This suite requires a bare-metal system with enough CPU, RAM and disk
to support as many VMs as you plan to run.  For perfSONAR, the
recommended per-VM configuration is four cores, 4 GiB of RAM and 40 GB
of disk.  The core requirement is not firm, as perfSONAR systems tend
not to require all of them at once.

The system needs a minimum of two network interfaces, either
physically-separate or a single physical interface on multiple VLANs:

 * **Inside** - Used to reach the host via SSH for administrative
   purposes.  This interface should be configured with an internal
   address and be protected from the Internet at large.

 * **Outside** - Use by the VMs to reach the Internet.  This interface
   should exist on the host but must not be configured with an IP
   address.  The guests will bridge to this interface and assign their
   own IPs.  Barring a compromise that breaks out of the VM "jail,"
   This keeps them isolated from the host.


## Setup

Install a recent RHEL- or Debian-derived Linux.  AlmaLinux 8 and
Debian 10 are the currently-recommended distributions.

Configure the inside interface on an inside address.

Log in as `root` and bring the system up to date:
 * **Red Hat:** `dnf -y makecache && dnf -y update && reboot`
 * **Debian:** `apt -y update && apt -y upgrade && reboot`

Log in as `root` and issue the following command:
```
curl https://raw.githubusercontent.com/perfsonar/testbed-bare-metal-host/main/bin/setup | sh -e
```

Become the `testbed` user.

`cd testbed-bare-metal-host`

Create `config/config.yaml` based on the sample in that directory.
Specific instructions can be found in the sample file.

Start the test bed running with `make up`.


## Maintenance

To run the Ansible playbooks against all hosts, run `make maintain`.
