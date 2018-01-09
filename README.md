
# Configuring repositories

## Yum

Create a file /etc/yum.repos.d/trust-networks.repo:

   [trustnetworks]
   name=Trust Networks
   baseurl=http://download.trustnetworks.com/fedora/$releasever/$basearch/
   gpgcheck=1
   enabled=1
   gpgkey=http://download.trustnetworks.com/trust-networks.asc

And then:

   yum install cyberprobe

## Debian/Ubuntu

For Stretch, append to end of /etc/apt/sources.list:

   deb http://download.trustnetworks.com/debian stretch main

For Jessie:

   deb http://download.trustnetworks.com/debian jessie main

For Wheezy:

   deb http://download.trustnetworks.com/debian wheezy main

And then:

   apt-get update
   apt-get install cyberprobe

