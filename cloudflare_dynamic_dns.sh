#!/bin/bash

# cloudflare_dynamic_dns.sh

# Dependencies:  jq,   ubuntu install using:    sudo apt-get install jq

# Dynamic DNS with cloudflare.com
# 
# Track your servers changing DNS by running this script in cron on your server.
# This script will update one or a list of cloudflare DNS domain/subdomain records with your correct IP if it changes when compared with your cloudflare records.
# !!IMPORTANT!!  This script does rely on having an external script/website that you can curl / queary for your current ip address.

#/////////////   EDIT FOLLOWING VARIABLES WITH YOUR INFO  ////////////////////////////////////////////////

#cf_tkn , string value, is your unique cloudflare token for your account, available from cloudflare account area. e.g. cf_tkn='a1b2c3uuausdu9ouhnkjhkdufyiqueyhbsdkfjh'
cf_tkn=''
#cf_email , string value, is the email you used to register with cloudflare. e.g. cf_email='you@youremail.com'
cf_email=''
#cf_zone , string value, the domain zone of the DNS records you want to edit.  e.g.  cf_zone='yourdomain.com'
cf_zone=''
#A_cf_target , array of DNS target names for your zone that you want to update the ip address.  e.g. declare -a A_cf_target=(yourdomain.com subdomain1.yourdomain.com subdomain2.yourdomain.com)
declare -a A_cf_target=()
#A_cf_service_mode, array of equal size of A_cf_target, 0 1 values.  0=no cloudflare routing for domain,  1=turn on cloudflare routing for domain e.g. declare -a A_cf_service_mode=(1 0 0)
declare -a A_cf_service_mode=()

#current_server_ip 
#=================
#current_server_ip must contain your servers/computer current external ip, there are many websites you could curl the data from
#e.g. http://www.whatsmyip.org/

#i've chosen to write my own php file called hinfo.php with the following content and host it on a trusted external site I own.
#<?php
#echo $_SERVER['HTTP_CF_CONNECTING_IP']
#?>

#If your trusted server is behind a cloudflare firewall, your server must have the apache mod_cloudflare installed.
#more info https://www.cloudflare.com/resources-downloads#mod_cloudflare

#If your trusted server is not behind a cloudlare firewall change the contents of the hinfo.php file to
#<?php
#echo $_SERVER['REMOTE_ADDR']
#?>

ip_detect_url='http://www.trusteddomain.com/path/to/hinfo.php'
current_server_ip=$(curl -s -L "$ip_detect_url")

#////////////////////////////////////////////////////////////////////////////////////////////////////////


#---- DO NOT EDIT ANYTHING BELOW THIS LINE, NO NEED TO ----#

domaindata=$(curl -s https://www.cloudflare.com/api_json.html -d 'a=rec_load_all' -d "tkn=$cf_tkn"  -d "email=$cf_email"  -d "z=$cf_zone")

num_targets=${#A_cf_target[@]}

for ct in $(seq 0 $(($num_targets-1)) )
do

  cf_ip=$(echo $domaindata | jq -r ".response.recs.objs | .[] | select(.name==\"${A_cf_target[$ct]}\").content" )
  rec_id=$(echo $domaindata | jq -r ".response.recs.objs | .[] | select(.name==\"${A_cf_target[$ct]}\").rec_id")

  if [ "$current_server_ip" != "$cf_ip" ]; then 
    curl -s https://www.cloudflare.com/api_json.html \
    -d 'a=rec_edit' \
    -d "tkn=$cf_tkn"\
    -d "id=$rec_id" \
    -d "email=$cf_email" \
    -d "z=$cf_zone" \
    -d 'type=A' \
    -d "name=${A_cf_target[$ct]}" \
    -d "content=$current_server_ip" \
    -d "service_mode=${A_cf_service_mode[$ct]}" \
    -d 'ttl=1' > /dev/null
  fi

done
