#!/bin/sh
cd ../build
make
cd ../examples
valac -X -L../build -X -I../build -X -lwebcon -o example ./example.vala ../build/webcon.vapi
LD_LIBRARY_PATH="../build" ./example -c ./example.conf
