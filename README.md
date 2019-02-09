# SCION-p4netfpga

Repository for Master's thesis project of Kamila Součková

## Repository structure

### `doc/`: Documentation

Master thesis, hardware documentation, etc.

### `lib/`: Modular, reusable P4 implementation of the SCION protocol

The main contribution of this project.

### `src/`: Implementation of a SCION/IP border router

A reference border router that uses the components from `lib/`. Runnable on several hardware platforms (see below).

This reference implementation assumes that the AS uses IP for internal routing. It is modular, so it can be modified to support different routing techniques, such as MPLS.

### `platforms/`: Files that allow the reference router to run on various hardware

Currently supported: Xilinx NetFPGA SUME, with the `SimpleSumeSwitch`
architecture. In the future, a custom architecture might be provided if useful.

### `controller/`: The control plane for the router

The control plane program that communicates with the router.

### `testdata/`: Packet generators for testing the implementation

things and stuff

### `3rdparty/`: Third party content.

Currently empty.

## Prerequisites

Prepare your dev machine according to <https://github.com/NetFPGA/P4-NetFPGA-public/wiki/Getting-Started>:

1. Obtain the 3 necessary Xilinx licenses: Vivado, SDNet, and 10G MAC.
2. This project is tested with **Vivado 2018.2** and **SDNet 2018.2**. Install those versions to avoid surprises.
3. Clone the NetFPGA repository and check out the `vivado-2018.2` branch:
   ```
   mkdir -p ~/projects
   cd ~/projects
   git clone https://github.com/NetFPGA/P4-NetFPGA-live.git P4-NetFPGA
   git checkout vivado-2018.2
   ```
4. Environment settings:
   * Put this into your .bashrc or something:
     ```
     ##### Vivado #####
     source /opt/Xilinx/Vivado/2018.2/settings64.sh

     #### P4-NetFPGA #####
     source ~/projects/P4-NetFPGA/tools/settings.sh

     #### SDNet ####
     export PATH=/opt/Xilinx/SDNet/2018.2/bin:$PATH
     source /opt/Xilinx/SDNet/2018.2/settings64.sh

     # point to Vivado and SDNet license file / server
     export XILINXD_LICENSE_FILE= ... 
     ```
   * Check `~/projects/P4-NetFPGA/tools/settings.sh`:
     * Make sure that `$SUME_FOLDER` points to where you checked out the NetFPGA repo.  (TODO is that needed at all?)
     * `$P4_PROJECT_NAME` is irrelevant, as this project is self-contained and does not depend on the NetFPGA build system.
5. Build the SUME hardware library cores and some software to access registers:
   ```
   cd $SUME_FOLDER/lib/hw/xilinx/cores/tcam_v1_1_0/ && make update && make
   cd $SUME_FOLDER/lib/hw/xilinx/cores/cam_v1_1_0/ && make update && make
   cd $SUME_SDNET/sw/sume && make
   cd $SUME_FOLDER && make
   ```
6. Build and load the SUME drivers:
   ```
   cd $DRIVER_FOLDER
   make all
   sudo make install
   sudo modprobe sume_riffa
   lsmod | grep sume_riffa
   ```
7. Clone this repository (if you haven't yet), `cd` into it and type `make` to
   see the list of make targets.
