#!/bin/bash

set -e

rm -rf gen/ gen-target/
./scion.sh topology -c topology/MyTiny.topo

for f in $(find gen/ISD1/ASff00_0_110 -name 'topology.json') ; do
	cp $f $f.bak
	cat $f | jq '.BorderRouters."br1-ff00_0_110-1".Interfaces."1".PublicOverlay.Addr |= "10.10.10.1"'  > $f.new && mv $f.new $f
	cat $f | jq '.BorderRouters."br1-ff00_0_110-1".Interfaces."1".RemoteOverlay.Addr |= "10.10.10.11"' > $f.new && mv $f.new $f
	cat $f | jq '.BorderRouters."br1-ff00_0_110-1".Interfaces."2".PublicOverlay.Addr |= "10.10.10.2"'  > $f.new && mv $f.new $f
	cat $f | jq '.BorderRouters."br1-ff00_0_110-1".Interfaces."2".RemoteOverlay.Addr |= "10.10.10.12"' > $f.new && mv $f.new $f
done

for f in $(find gen/ISD1/ASff00_0_111 -name 'topology.json') ; do
	cp $f $f.bak
	cat $f | jq '.BorderRouters."br1-ff00_0_111-1".Interfaces."1".PublicOverlay.Addr |= "10.10.10.11"' > $f.new && mv $f.new $f
	cat $f | jq '.BorderRouters."br1-ff00_0_111-1".Interfaces."1".RemoteOverlay.Addr |= "10.10.10.1"'  > $f.new && mv $f.new $f
done

for f in $(find gen/ISD1/ASff00_0_112 -name 'topology.json') ; do
	cp $f $f.bak
	cat $f | jq '.BorderRouters."br1-ff00_0_112-1".Interfaces."1".PublicOverlay.Addr |= "10.10.10.12"' > $f.new && mv $f.new $f
	cat $f | jq '.BorderRouters."br1-ff00_0_112-1".Interfaces."1".RemoteOverlay.Addr |= "10.10.10.2"'  > $f.new && mv $f.new $f
done

cp -r gen gen-target
rm -r gen-target/ISD1/ASff00_0_110
rm -r gen/ISD1/ASff00_0_11{1,2}
