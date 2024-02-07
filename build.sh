#! /usr/bin/env sh
set -x

make ${@}

mv *.mod src/
mv *.o src/
mv *.so src/
