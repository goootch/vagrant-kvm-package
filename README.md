# Vagrant KVM Package

Create [kvm-vagrant](https://github.com/adrahon/vagrant-kvm) base
boxes from kvm images. I highly recommend creating the kvm image with
[packer](http://packer.io). There are some templates available for
creating qemu images, with packer, at
[packer-qemu-templates](https://github.com/jakobadam/packer-qemu-templates)

## Requirements

* [vagrant](https://github.com/mitchellh/vagrant)
* [kvm-vagrant](https://github.com/adrahon/vagrant-kvm)

## Installation

```
$ ln -s ~/vagrant-kvm-package/vagrant-kvm-package.sh /usr/local/bin/vagrant-kvm-package
```

## Usage Example

Package a new box:

```
$ vagrant-kvm-package ubuntu-14.04 packer-ubuntu.qcow2
```

This creates the Vagrantfile, box.xml, metadata.json and image.qcow2
and tars them into a box. The domain specification in box.xml is
created automatically by running virt-install under the hood. In
addition, the script extracts the mac address which is put into the
Vagrantfile.

Add box to vagrant:

```
$ vagrant box add ubuntu-14.04.box --name ubuntu-14.04
```
