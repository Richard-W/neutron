#!/bin/sh
cd ../build
make
cd ../examples
valac -X -L../build -X -I../build -X -lneutron -o example ./example.vala ../build/neutron.vapi --pkg gio-2.0 -g
LD_LIBRARY_PATH="../build" ./example -c ./example.conf
