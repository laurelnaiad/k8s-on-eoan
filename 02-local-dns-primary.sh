########################################################################

# 02-local-dns-as-primary

########################################################################
dig @127.0.0.1 A google.com
if [[ $? -ne 0 ]]
then
  echo "Cannot dig @127.0.0.1, therefore not configuring it as primary dns."
  exit 1
else
  ./dnsmasq-install/dnsmasq-as-primary.sh
fi
