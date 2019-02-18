#!/bin/sh

NF_VENDOR_ID=0x7028

DEV=$(grep -l $NF_VENDOR_ID /sys/bus/pci/devices/*/device)
if [ -z "$DEV" ]; then
    echo "PCI device not found! See TODO docs"
    exit 71
fi
echo 1 > $(dirname $DEV)/remove
echo 1 > /sys/bus/pci/rescan
