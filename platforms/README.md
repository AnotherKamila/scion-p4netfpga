Makefiles and auxiliary files to support various platforms.

Currently supported platforms:

* `p4c`: [the reference P4 compiler](https://github.com/p4lang/p4c)
  (software-only)

  The "official" P4 compiler -- closely follows the specification.

  Open-source and freely available. Useful to quickly test functionality without
  requiring vendor-specific toolchains.

* `netfpga`: The NetFPGA board family. Multiple boards and architectures can be
  supported. Currently we support the NetFPGA SUME with the default
  `SimpleSumeSwitch` architecture.

  Other boards that use the Xilinx SDNet toolchain can also be supported by this
  target, as long as their architecture files are added.
