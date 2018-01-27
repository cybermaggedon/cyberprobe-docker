
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

Add our signing key...

  wget -q -O- http://download.trustnetworks.com/trust-networks.asc | \
    apt-key add -

Or simpler:

   apt-key adv --fetch-keys \
     http://download.trustnetworks.com/trust-networks.asc
     
For Stretch:

   echo 'deb http://download.trustnetworks.com/debian stretch main' \
     >> /etc/apt/sources.list

For Jessie:

   echo 'deb http://download.trustnetworks.com/debian jessie main' \
     >> /etc/apt/source.list

For Wheezy:

   echo 'deb http://download.trustnetworks.com/debian wheezy main' \
     >> /etc/apt/source.list

And then:

   apt-get update
   apt-get install cyberprobe

