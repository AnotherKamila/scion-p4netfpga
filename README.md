# SCION-p4netfpga

Master's thesis project of Kamila Součková

See doc/thesis/thesis.pdf.

## What can it do?

A P4-based border router for SCION, runnable in software or on the NetFPGA SUME.

Main results:

* Modular, portable P4 code implementing SCION parsing and forwarding.  
  => You can quickly make improvements to this, or base other SCION-related P4 projects on this.
* Complete hardware design for the NetFPGA SUME, able to forward at 40Gbps.  
  => You can readily use this with the NetFPGA, either as is, or as a base for other projects.
* Thin control plane layer that enables integrating this with other SCION infrastructure.  
* Workflow and documentation optimised for software engineers.  
  => You can use this without being a hardware person.

Note that this is academic code: it worked once ;-) However, if you want to use this, contact me, I am happy to help.

## Quick start

**Note: Because we cannot distribute the AES implementation we used, you need to add your own AES core.** See `platforms/netfpga/hw/externs/aes128/README.md`.
If you are from ETH, contact me to get access to the version of this repository that contains the AES code.

1. Set up your environment: See [Prerequisites](#prerequisites)
   Note: Right now we also need to edit NetFPGA repo's index of externs, which is terrible. We attempted to solve this problem (see https://github.com/NetFPGA/P4-NetFPGA-live/issues/24 for the current status), but we're not there yet.
   For now, add the following to `~/projects/P4-NetFPGA/contrib-projects/sume-sdnet-switch/bin/extern_data.py`:
   ```
   "aes128": {"hdl_template_file": "externs/aes128/hdl/EXTERN_aes128_template.v",
              "replacements": {"@RESULT_WIDTH@": "output_width(result)",
                               "@MODULE_NAME@": "module_name",
                               "@EXTERN_NAME@": "extern_name"}
   },

   ```
2. Build this: `make` to see help, or `make build` to build everything needed to use this
3. Flash the NetFPGA:  
   Run **as root** (with the env vars set up):
   1. `make flash`
   2. reboot
   3. `make devinit`
4. Start controller:
   1. deploy SCION infra, make the SW BR bind to NetFPGA's `nf*` interfaces by configuring them with the IP addresses specified for the BR in its topology.json.
   2. start NetFPGA controller: `pipenv run python -m controller.main`

More details [below](#building-this-project).

## What's where?

### `doc/`: Documentation

Master thesis, hardware documentation, etc.

### `lib/`: Modular, reusable P4 implementation of the SCION protocol

The main contribution of this project.

Note: Due to lack of time, some of the things which should be in `lib/` are instead in `src/main-xilinx_stream_switch.p4`. The author hopes to have the opportunity to clean this up one day.

### `src/`: Implementation of a SCION/IP border router

A reference border router that uses the components from `lib/`.

This reference implementation assumes that the AS uses IP for internal routing. However, it is modular, so it can be modified to support different routing techniques, such as MPLS.

### `platforms/`: Files that allow the reference router to run on various hardware

Currently supported: Xilinx NetFPGA SUME, with the `XilinxStreamSwitch`
architecture.
In theory, it should be easy to add support for the `bmv2` software switch.
Our aim was to make this project easily portable to other platforms.

### `controller/`: The control plane for the router

The control plane program that communicates with the router.

### `test/`: Packet generators for testing the implementation

`gen_testdata.py` generates packets with specificed properties; `scion_scapy.py` implements a SCION scapy packet

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

All of this must be run **as root**. Remember that your root shell also needs the
Xilinx and NetFPGA environment variables set up.

Flash the bitfile with `make flash`.

If you want to pass a different bitfile:
```
platforms/netfpga/scripts/program_switch.sh path_to_your_file.bit
```

**Reboot** afterwards to have the PCI bus work reliably. This is needed because
the PCI addresses may have changed and the PCI device enumeration only happens
at boot.

When the machine has rebooted, run `make devinit` to
initialise the NetFPGA's DMA. You need to run this after every reboot / power
on.

If the machine was powered off (cold) and `make devinit` gives you an error,
reboot and try again. Yes, really.
