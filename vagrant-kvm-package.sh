#!/usr/bin/env bash

function error() {
    local msg="${1}"
    echo "${msg}"
    exit 1
}

function usage() {
    echo "Usage: ${0} NAME IMAGE"
    echo
    echo "This packages a kvm qcow2 image into a kvm vagrant reusable box"
    echo "It uses virt-install and virsh to do so"
}

function vir_exists(){
    local name="${1}"
    virsh list --all | grep $name &> /dev/null
}

function vir_undefine(){
    local name="${1}"
    virsh undefine $name
}

function vir_shutdown(){
    local name="${1}"
    virsh shutdown $name
    while vir_running $NAME; do
        echo -n "."
        sleep 1
    done
}

function vir_running(){
    local name="${1}"
    virsh list | grep running | grep $name &> /dev/null
}

function vir_delete(){
    local name="${1}"
    vir_shutdown $name
    vir_undefine $name
}

if [ -z "$2" ]; then
    usage
    exit 1
fi

NAME="$1"
IMG=$(readlink -e $2)

# defaults for virtual server
RAM=2048
VCPUS=2

vir_exists $NAME && error "Domain $NAME already exists."

IMG_BASENAME=$(basename $IMG)
IMG_DIR=$(dirname $IMG)

TMPDIR=$IMG_DIR/_tmp_package
mkdir -p $TMPDIR 

trap "mv $TMPDIR/$IMG_BASENAME $IMG_DIR; rm -rf $TMPDIR" EXIT

mv $IMG $TMPDIR
IMG=$TMPDIR/$IMG_BASENAME

cd $TMPDIR

# blocks until guest is manually shutdown, therefore &
virt-install --import \
    --name $NAME \
    --ram $RAM --vcpus=$VCPUS\
    --disk path="$IMG",bus=virtio,format=qcow2\
    -w network=default,model=virtio &

PID=$!

# wait for domain to be started
sleep 10

virsh dumpxml $NAME > box.xml

# extract the mac for the Vagrantfile
MAC=$(cat box.xml | grep 'mac address' | cut -d\' -f2 | tr -d :)
IMG_ABS_PATH=$(cat box.xml | grep 'source file' | cut -d\' -f2)

# replace the absolute image path
sed -i s#$IMG_ABS_PATH#$IMG_BASENAME# box.xml

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

vir_running $NAME && vir_shutdown $NAME

# wait for virt-install shutdown
wait $PID

tar cvzf $NAME.box --totals ./metadata.json ./Vagrantfile ./box.xml ./$IMG_BASENAME
mv $NAME.box $IMG_DIR

vir_undefine $NAME

echo "$IMG_DIR/$NAME.box created"
