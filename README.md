# Vagrant KVM Package

Create kvm vagrant boxes from from kvm images

## Installation

```
ln -s ~/vagrant-kvm-package/vagrant-kvm-package.sh /usr/local/bin/vagrant-kvm-package
```

## Usage Example

```
NAME=ubuntu-14.04
IMAGE=packer-ubuntu.qcow2
vagrant-kvm-package $NAME $IMAGE
```

This creates the Vagrantfile, box.xml, metadata.json and image.qcow2
and tars them into the box.

The domain specification in box.xml is created by running virt-install.
