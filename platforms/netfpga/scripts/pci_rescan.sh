#!/bin/sh

NF_VENDOR_ID=0x7028

DEV=$(grep -l $NF_VENDOR_ID /sys/bus/pci/devices/*/device)
if [ -z "$DEV" ]; then
cat <<- EOF >&2
	PCI device not found! Try the following:
	 1. Flash a known good design to the NetFPGA
	 2. Reboot the host
	 3. Run this again (as root)
	EOF
	exit 71
fi
echo 1 > $(dirname $DEV)/remove
echo 1 > /sys/bus/pci/rescan
