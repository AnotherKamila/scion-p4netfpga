#!/bin/sh

set -e

KMOD=sume_riffa

rmmod $KMOD 2>/dev/null || true
$(dirname $0)/pci_rescan.sh
rmmod $KMOD 2>/dev/null || true
modprobe $KMOD

for i in `seq 0 3`; do
    ifconfig nf$i up
done

echo 'DMA is ready to use; nf* interfaces up'
