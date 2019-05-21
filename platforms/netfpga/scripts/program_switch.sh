#!/bin/sh

KMOD=sume_riffa

set -ex

rmmod $KMOD || true
env DISPLAY=dummy xsct $SUME_SDNET/tools/run_xsct.tcl -tclargs $@
$(dirname $0)/pci_rescan.sh
rmmod $KMOD || true

echo 'Flashing completed.'
echo 'You should likely reboot the host now (otherwise DMA may not work).'
