EC2-snapshot - create snapshots from all mounted EBS volumes
============================================================

EC2-snapshot is gem that allows you to easily create snapshots for mounted EBS volumes on
an EC2 instance.

The idea originated from the wish of automating snapshot creation for EC2 instances and making
it easy to integrate it into chef.

The gem was written with the idea of it running only on the EC2 instance for which snapshots
need to be created. Because we wanted to use it with chef, we needed to keep configuration to a minimum.
There is no need to provide an instance id or volume ids, as that will already be retrieved on the 
instance itself. The only necessities are the AWS credentials, region and an option to set which types
of volumes need to be snapshotted.

Requirements
------------

There are some requirements for using this gem:

* the gem only works on Linux, since it has dependencies on files such as /etc/hostname and /proc/mounts
* wget needs to be installed. This is required to automatically retrieve the current instance id
* xfs_freeze needs to be installed in order to be able to freeze a XFS filesystem to get a consistent snapshot


Getting started
---------------

Installing the Gem is pretty straighforward:

* Install the gem with <tt>gem install ec2-snapshot</tt>

Note that /etc/hostname is used to get the name of the current instance.
Also /proc/mounts is used to retrieve information on the filesystems to be snapshotted.


Using the executable
--------------------

An executable has been provided to easily use the gem within your own scripts.
Execute <tt>ec2-snapshot -h</tt> to get an overview of the arguments that the executable 
supports.


About EC2-snapshot
------------------

EC2-snapshot was created by Mattijs van Druenen (m.vandruenen *at* voormedia.com)

Copyright 2011 Voormedia - [www.voormedia.com](http://www.voormedia.com/)