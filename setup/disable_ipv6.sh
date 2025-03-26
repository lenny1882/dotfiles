# create the long-life config file
echo "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee /etc/sysctl.d/99-my-disable-ipv6.conf

# ask the system to use it
sudo service procps reload

# check the result
cat /proc/sys/net/ipv6/conf/all/disable_ipv6