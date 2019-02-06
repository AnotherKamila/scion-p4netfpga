Makefiles and auxiliary files to support various platforms.

<!-- TODO would be cool to autogenerate this list -->
# Supported Platforms

This is the list of the currently supported platforms and architectures. The
project is designed to be portable, so adding a new platform or architecture
requires relatively little effort (see below).

## `bmv2`: reference software switch

The switch provided by [the reference P4
compiler](https://github.com/p4lang/p4c) (software-only).

Open-source and freely available. Useful to quickly test functionality without
requiring vendor-specific toolchains.

#### Available Architectures:

* `V1Switch`: the [`simple_switch`](https://github.com/p4lang/behavioral-model/blob/master/targets/README.md#simple_switch) target with the [v1model](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4) reference architecture


## `netfpga`: The NetFPGA board family

The NetFPGA is an open-source hardware and software platform for rapid prototyping of computer network devices

Currently we support the **NetFPGA SUME** board. 
Other boards that use the Xilinx SDNet toolchain can also be supported by this
target, as long as their architecture files are added.

#### Available Architectures:

* `SimpleSumeSwitch`: the default architecture provided by the NetFPGA SUME P4 toolkit
  Note that due to the limitations of the current version of P4-SDNet compiler, this architecture cannot handle long SCION paths.
  **To speed up development, this platform is temporarily abandoned and doesn't compile. Later in the project it will either be made to work or removed.**
* `XilinxStreamSwitch`: the experimental architecture providing access to the experimental `packet_mod` feature. Experimental.
  This architecture improves performance and reduces FPGA area usage by not parsing the parts of the header which aren't needed. Thanks to that, it can handle longer paths compared to the `SimpleSumeSwitch` despite the limitations of the P4-SDNet compiler.
  

# Adding a new architecture

TODO

# Adding a new platform

TODO
