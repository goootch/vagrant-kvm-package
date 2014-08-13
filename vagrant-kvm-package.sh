#!/usr/bin/env bash

error() {
    local msg="${1}"
    echo "${msg}"
    exit 1
}

usage() {
  echo "Usage: ${0} NAME IMAGE"
    echo
    echo "Package a kvm qcow2 image into a kvm vagrant reusable box"
    echo "It uses virt-install to do so"
}

is_backing_file() {
  local img=$(readlink -e $1)
  qemu-img info $img | egrep -q "^backing file:"
  if [ "$?" -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

convert_to_nonbacking_file() {
  local in_img=$(readlink -e $1)
  local out_img=$2
	echo "Converting to a non-backing file. ($out_img)"
  qemu-img convert -c -p -O qcow2 $in_img $out_img
  if [ "$?" -ne 0 ]; then
    rm -rf $out_img
    return 1
  else
    return 0
  fi
}

if [ -z "$2" ]; then
    usage
    exit 1
fi

# defaults for virtual server
NAME="$1"
RAM=512
VCPUS=1

IMG=$(readlink -e $2)
IMG_BASENAME=$(basename $IMG)
IMG_DIR=$(dirname $IMG)

# Create stuff in tmp dir
TMP_DIR=$IMG_DIR/_tmp_package
mkdir -p $TMP_DIR

# We move the image to the tempdir
# ensure that it's moved back again
# and the tmp dir removed
trap "(test -f $TMP_DIR/$IMG_BASENAME && mv $TMP_DIR/$IMG_BASENAME $IMG_DIR); rm -rf $TMP_DIR" EXIT

# convert to non-backing file, if the image-file is "backing file"
if is_backing_file $IMG ; then
  convert_to_nonbacking_file $IMG $TMP_DIR/box-disk1.img || exit 1
  IMG=$TMP_DIR/box-disk1.img
else
  mv $IMG $TMP_DIR
  IMG=$TMP_DIR/$IMG_BASENAME
fi

# generate box.xml
cd $TMP_DIR

virt-install \
    --print-xml \
    --dry-run \
    --import \
    --name $NAME \
    --ram $RAM --vcpus=$VCPUS \
    --disk path="$IMG",bus=virtio,format=qcow2 \
    -w network=default,model=virtio > box.xml

# extract the mac for the Vagrantfile
MAC=$(cat box.xml | grep 'mac address' | cut -d\' -f2 | tr -d :)
IMG_ABS_PATH=$(cat box.xml | grep 'source file' | cut -d\' -f2)

# replace the absolute image path
sed -i "s#$IMG_ABS_PATH#${IMG##*/}#" box.xml

# Hmm. When not starting the vm (--print-xml) the memory attribute in
# the XML is missing the unit, which causes an exception in vagrant-kvm

# add the memory unit
sed -i "s/<memory>/<memory unit='KiB'>/" box.xml

cat > metadata.json <<EOF
{
    "provider": "kvm"
}
EOF

cat > Vagrantfile <<EOF
Vagrant.configure("2") do |config|
  config.vm.base_mac = "$MAC"
end
EOF

echo "Creating the a box file. ($IMG_DIR/$NAME.box)"
tar czf $NAME.box --totals ./metadata.json ./Vagrantfile ./box.xml ./${IMG##*/}
mv $NAME.box $IMG_DIR

echo "Complete!"
