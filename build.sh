#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Usage: $0 DIST COMPONENT"
    exit 1
fi

[ -r ./builder.conf ] && source ./builder.conf

set -e
[ "$DEBUG" = "1" ] && set -x

DIST=$1
COMPONENT=$2

SCRIPT_DIR=$PWD

: ${MAKE_TARGET=rpms}

ORIG_SRC=$PWD/qubes-src/$COMPONENT
DIST_SRC_ROOT=$PWD/$DIST/home/user/qubes-src/
DIST_SRC=$DIST_SRC_ROOT/$COMPONENT

REQ_PACKAGES="build-pkgs-$COMPONENT.list"

export USER_UID=$UID
if ! [ -e $DIST/home/user/.prepared_base ]; then
    sudo -E ./prepare-chroot $PWD/$DIST $DIST
    touch $DIST/home/user/.prepared_base
fi

if [ -r $REQ_PACKAGES ] && ! [ -e $DIST/home/user/.installed_$REQ_PACKAGES ]; then
    sed "s/DIST/$DIST/g" $REQ_PACKAGES > build-pkgs-temp.list
    sudo -E ./prepare-chroot $PWD/$DIST $DIST build-pkgs-temp.list
    rm -f build-pkgs-temp.list
    touch $DIST/home/user/.installed_$REQ_PACKAGES
fi

mkdir -p $DIST_SRC_ROOT
rm -rf $DIST_SRC
cp -alt $DIST_SRC_ROOT $ORIG_SRC
rm -rf $DIST_SRC/rpm/{x86_64,i686,noarch}
# Disable rpm signing in chroot - there are no signing keys
sed -i -e 's/rpm --addsign/echo \0/' $DIST_SRC/Makefile*
sudo chroot $DIST su - -c "cd /home/user/qubes-src/$COMPONENT; make $MAKE_TARGET" user
[ "$NO_SIGN" != "1" ] && rpm --addsign $DIST_SRC/rpm/*/*rpm
for i in $DIST_SRC/rpm/*; do
    ARCH_RPM_DIR=$ORIG_SRC/rpm/`basename $i`
    mkdir -p $ARCH_RPM_DIR
    mv -vt $ARCH_RPM_DIR $i/*
done