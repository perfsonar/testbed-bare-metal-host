# perfSONAR Test Bed Host for Bare Metal

This directory contains infrastructure for running a multi-VM system
as part of the perfSONAR test bed.


## Theory of Operation

TODO: Write this


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
