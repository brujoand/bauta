#! /bin/sh

rm -rf bin
mkdir bin
echo "#! /usr/bin/env bash" > bin/bauta
echo "# This is just a bunch of files cat'ed into one file." >> bin/bauta
echo "# Read https://github.com/brujoand/bauta instead." >> bin/bauta
cat helpers/*.bash bauta.bash | sed -e 's/^#.*//' -e 's/^source .*//' >> bin/bauta
chmod +x bin/bauta
