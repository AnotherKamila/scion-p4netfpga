Because we cannot distribute the AES implementation we used, you need to add your own AES core.
You can add the files here, and instantiate your module in `./hdl/EXTERN_aes128_template.v`.

Note that the AES implementation must be pipelined: it needs to be able to accept data on every cycle.

You should also change the value of `@Xilinx_MaxLatency` in the extern declaration in P4 (`lib/scion/verification.p4`) if the latency your AES implementation isn't 10 cycles.

If you are from ETH, contact me to get access to the version of this repository that contains our AES code.
