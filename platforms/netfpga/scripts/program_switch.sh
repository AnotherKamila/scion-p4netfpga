set -ex

KMOD=sume_riffa

rmmod $KMOD || true
xsct $SUME_SDNET/tools/run_xsct.tcl -tclargs $@
$(dirname $0)/pci_rescan.sh
rmmod $KMOD || true
modprobe $KMOD

for i in `seq 0 3`; do
    ifconfig nf$i up
done
