# SCION-p4netfpga

Master's thesis project of Kamila Součková

## What can it do?

A P4-based border router for SCION, runnable in software or on the NetFPGA SUME.

Main results (TODO actually deliver them, plus TODO correlate this list with the section in thesis):

* Modular, portable P4 code implementing SCION parsing and forwarding.  
  => You can quickly make improvements to this, or base other SCION-related P4 projects on this.
* Complete hardware design for the NetFPGA SUME, able to forward at 40Gbps.  
  => You can readily use this with the NetFPGA, either as is, or as a base for other projects.
* Thin control plane layer that enables integrating this with other SCION infrastructure.  
  => You can use this in production, at 40Gbps.
* Workflow and documentation optimised for software engineers.  
  => You can use this without being a hardware person.

## Quick start

1. Set up your environment: See [Prerequisites](#Prerequisites)
2. Build this: `make` to see help, or `make build` to build everything needed to use this
3. Flash the NetFPGA:  
   Run as root (with the env vars available):
   1. `platforms/netfpga/scripts/program_switch.sh platforms/netfpga/$ARCH/hw/Scion.bit`
   2. reboot (needed because PCI device enumeration)
   3. `platforms/netfpga/scripts/pci_init.sh`
   (TODO make a `make flash` target instead of step 1)
4. TODO Start controller: How do we deploy this? => start control plane, make it talk to other SCION stuff

More details in TODO.
## What's where?

### `doc/`: Documentation

Master thesis, hardware documentation, etc.

### `lib/`: Modular, reusable P4 implementation of the SCION protocol

The main contribution of this project.

### `src/`: Implementation of a SCION/IP border router

A reference border router that uses the components from `lib/`. Runnable on several hardware platforms (see below).

This reference implementation assumes that the AS uses IP for internal routing. It is modular, so it can be modified to support different routing techniques, such as MPLS.

### `platforms/`: Files that allow the reference router to run on various hardware

Currently supported: Xilinx NetFPGA SUME, with the `XilinxStreamSwitch`
architecture. In the future, SimpleSumeSwitch might be supported, as well as the `bmv2` software switch.

### `controller/`: The control plane for the router

The control plane program that communicates with the router.

### `test/`: Packet generators for testing the implementation

things and stuff

### `3rdparty/`: Third party content.

Currently empty.

## Building this project

### Prerequisites

Prepare your dev machine according to <https://github.com/NetFPGA/P4-NetFPGA-public/wiki/Getting-Started>. Here is a quick, less detailed checklist:

1. Obtain the 3 necessary Xilinx licenses: Vivado, SDNet, and 10G MAC.
2. This project is tested with **Vivado 2018.2** and **SDNet 2018.2**. Install those versions to avoid surprises.
3. Clone the NetFPGA repository:
   ```
   mkdir -p ~/projects
   cd ~/projects
   git clone https://github.com/NetFPGA/P4-NetFPGA-live.git P4-NetFPGA
   ```
4. Environment settings:
   * Put this into your .bashrc or somewhere:
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
     * Make sure that `$SUME_FOLDER` points to where you checked out the NetFPGA repo.
     * `$P4_PROJECT_NAME` and the like are irrelevant, as this project is
       self-contained and does not depend on the NetFPGA build system. However,
       it does depend on some `$SUME_*` variables to find IP cores and scripts,
       so make sure those are correct. (Setting `$SUME_FOLDER` should be
       sufficient.)
5. Build the SUME hardware library cores and some software used for communication with the NetFPGA:
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
   
### Build this

7. Clone this repository (if you haven't yet), `cd` into it and type `make` to
   see the list of make targets.
   
   `make build` builds everything you need (for the selected `PLATFORM` and `ARCH`). To have more control over the build process: `cd platforms/<your_platform>; make`

   Use `make sim` to run the simulation.
   
   For the NetFPGA, use `cd platforms/netfpga; make simgui` to open the simulation in the Vivado GUI.

### Flash it!

TODO :D
