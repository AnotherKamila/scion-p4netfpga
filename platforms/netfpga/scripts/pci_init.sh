#!/bin/sh

set -e

KMOD=sume_riffa

rmmod $KMOD || true
$(dirname $0)/pci_rescan.sh
rmmod $KMOD || true
modprobe $KMOD

for i in `seq 0 3`; do
    ifconfig nf$i up
done

echo 'DMA is ready to use; nf* interfaces up'
