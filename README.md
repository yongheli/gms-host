gms
===

To configure a Genome Modeling System node on top of Ubuntu 12.04 (Precise) Linux

For a non-VM configuration, run:
  
  make

For a VM using VirtualBox and Vagrant, run:
  
  make vm

Both appraches begin by downloading data and software and other git repos (submodules) which are not part of this repository.
The make target "make stage-files" performs this task in isolation first.

Subsequent steps occur on the VM in a VM-centric configuration. The Vagrantfile in the repo will mount the data rather than copy it in, allowing the VM to be torn down and rebuild quickly.

The non-VM configuration takes the same approach of downloading the data first, so a full copy of a configured gms repo directory is more efficient than just cloning it.


