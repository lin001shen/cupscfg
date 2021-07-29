#!/bin/bash
# for cups config
readonly CFGDIR=~/cfgdir
readonly CUPS_DIR=/etc/cups

#CLOUD VENDOR: gcp, aws, or azure
CLOUD_VENDOR=gcp
CUPS_CFG_URL=gs://cups-cfg-bucket

function check_internet_access()
  if [[ "$(ping -c 1 8.8.8.8 | grep '100% packet loss' )" != "" ]]; then
    echo "Internet isn't present" >/tmp/cups_ck_internet.log
    echo "no"
else
    echo "Internet is present" >/tmp/cups_ck_internet.log
	echo "yes"
fi


function one_time_cfg()
{
  #1. set SELinux to permissive
  sudo setenforce 0
  sudo sed -i "s@SELINUX=.*@SELINUX=disabled@g" /etc/selinux/config

  #2. update
  sudo yum update -y

  #3. handle firewall: enable to access port 631
  sudo firewall-cmd --permanent --add-port=631/tcp
  sudo systemctl reload firewalld

  #4. install CUPS
  sudo yum install cups.x86_64 cups-libs.x86_64 cups-client.x86_64 cups-filters.x86_64 -y
  
  #dummy printer, for testing only
  sudo yum install cups-pdf -y
  
  sudo systemctl enable cups
  sudo systemctl enable cups-browsed
  sudo systemctl start cups
  sudo systemctl start cups-browsed

  #5. download cfg files  
  if [ ! -d $CFGDIR ]; then 
    mkdir -p $CFGDIR
	if [ "${CLOUD_VENDOR}" = "gcp" ]; then
      sudo gsutil -m cp $CUPS_CFG_URL/* $CFGDIR
    elif [ "${CLOUD_VENDOR}" = "aws" ]; then
      echo " To-DO for aws"
    elif [ "${CLOUD_VENDOR}" = "azure" ]; then
      echo " To-DO for azure"
    else
      echo "cloud-vendor is not supported"
    fi
  fi

  cups_cfg_files=`ls $CFGDIR`
  for cf in $cups_cfg_files
  do
    if [ -f $CUPS_DIR/$cf ]; then
      sudo mv $CUPS_DIR/$cf $CUPS_DIR/${cf}-orig
      sudo cp -p $CFGDIR/$cf $CUPS_DIR/
    fi
  done


  #5. restart cups services
  #sed -i "s@Listen localhost:631@Listen *:631@g" /etc/cups/cupsd.conf
  sudo systemctl restart cups
  sudo systemctl restart cups-browsed
}

#=================== main ==============
#check if the first time
if [ -f ~/cups-cfg.log ]; then
   date >>~/cups-cfg.log
   echo "Nothing to do " >> ~/cups-cfg.log
else
   internet_access=$(check_internet_access)
   if [ "$internet_access" = "yes" ]; then
      one_time_cfg
      date > ~/cups-cfg.log
      echo "First start; update and configure cups" >> ~/cups-cfg.log
   fi
fi
