# perfSONAR Test Bed Host for Bare Metal

This directory contains infrastructure for running a multi-VM system
as part of the perfSONAR test bed.

## Prerequisites

 * Bare-metal system running a recent RHEL- or Debian-derived Linux


## Theory of Operation

The system's job is to host multiple VirtualBox VMs that serve as
test bed systems,  

The system should have at least two network interfaces:

 * **Inside** - Used to reach the host via SSH for administrative
     purposes.
 
 * **Outside** - Use by the VMs to reach the Internet.

The two interfaces may be different VLANs on the same physical
interface if desired.


## System Setup

Install the OS and configure the inside interface as normal.  **Do not
configure the outside interface(s).**

Log in, become `root` and issue the following command:

```
curl https://github.com/perfsonar/testbed-bare-metal-host/blob/main/setup | sh -e
```

Once setup is complete, become `testbed` and create
`testbed-bare-metal-host/config.yaml` based on the sample in the same
directory.
