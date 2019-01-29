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
