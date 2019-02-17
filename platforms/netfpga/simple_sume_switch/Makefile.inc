PLATFORM=netfpga        ## Select the platform. Try make -C platforms ls
ARCH=simple_sume_switch ## Select the architecture
# TARGET_SUPPORTS=
TARGET_SUPPORTS=PACKET_MOD SUCKING_AND_IM_LYING_ABOUT_PACKET_MOD  # TODO this is false and it's only here while I'm fighting with toolchain and should be removed!
