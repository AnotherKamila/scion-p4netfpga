#!/bin/sh

for expected in *_expected.pcap; do
    intf="${expected%_*}"
    captured="${intf}_received.pcap"
    ./pcap_diff.py -i "$expected" -i "$captured" -d
done
