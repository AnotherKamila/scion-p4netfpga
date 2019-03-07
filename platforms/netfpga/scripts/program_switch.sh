!/bin/sh

KMOD=sume_riffa

if [ -z "$DISPLAY" ]; then
    echo "Xilinx's xsct tool will not work without having DISPLAY set."
    echo "Try again with ssh -Y. ¯\_(ツ)_/¯"
    exit 78
fi

set -ex

rmmod $KMOD || true
xsct $SUME_SDNET/tools/run_xsct.tcl -tclargs $@
$(dirname $0)/pci_rescan.sh
rmmod $KMOD || true
modprobe $KMOD

for i in `seq 0 3`; do
    ifconfig nf$i up
done
