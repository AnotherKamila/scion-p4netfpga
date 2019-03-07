#!/bin/sh

MAX_TEST_DURATION=30  # seconds

# set up capture for each interface
for pcap in *_expected.pcap; do
    intf="${pcap%_*}"
    count=$(tcpdump -enr "$pcap" | grep -v '^\s' | wc -l)
    echo "Expecting $count packets." >&2
    # trick: combine -G (rotate files every X seconds)
    #        with -W (max files)
    #        to timeout instead of waiting forever if it doesn't get all packets
    echo "Running command: tcpdump -nei $intf -c $count -W1 -G $MAX_TEST_DURATION" --direction=in -w "${intf}_received.pcap"
    tcpdump -nei $intf -c $count -W1 -G $MAX_TEST_DURATION  \
            --direction=in                                  \
            -w "${intf}_received.pcap" &
done
sleep 1  # give tcpdump time to start sniffing the interface

# replay packets to each interface
for pcap in *_applied.pcap; do
    intf="${pcap%_*}"
    # tcpreplay --topspeed -i $intf "$pcap" &
    tcpreplay --pps=1 -i $intf "$pcap" &
done

# wait for all tcpdumps to get their packets or timeout
wait
