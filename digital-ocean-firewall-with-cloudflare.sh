#!/usr/bin/env bash
set -o errexit
​
###########################
## ----- Variables ----- ##
###########################
​
### install_do_ctl
do_ctl_github_url='https://api.github.com/repos/digitalocean/doctl/releases/latest'
do_ctl_file='doctl-latest-linux-amd64.tar.gz'
do_ctl_bin='/usr/local/bin/doctl'
​
###########################
## ----- Functions ----- ##
###########################
​
### install_do_ctl: Checks if the doctl binary exists if it doesn't - downloadds the latest from the official Github repo and install is, does doctl init to set the TOKEN for future operations
function install_do_ctl() {
     if [ -f "${do_ctl_bin}" ]; 
     
     then
     # Asks for token if installed
     read -p ' doctl is already installed, please enter your doctl personal ACCESS TOKEN: ' do_ctl_token
     # Setup the token
     /usr/local/bin/doctl auth init "${do_ctl_token}"
     else
     # Installs the latest from the official Github repository
     curl -s ${do_ctl_github_url} | grep "browser_download_url.*linux-amd64.tar.gz" | cut -d : -f 2,3 | tr -d \" | xargs curl -SsL -o ~/${do_ctl_file}
     tar -xzf ~/${do_ctl_file} && rm -rf ~/${do_ctl_file}
     sudo mv ~/doctl /usr/local/bin
     read -p ' doctl has been installed, please enter your doctl personal ACCESS TOKEN: ' do_ctl_token 
     # Setup the token
     /usr/local/bin/doctl auth init "${do_ctl_token}"
     
     fi
}
​
### install_crontab: Install crontab for the firewall update script, initially for 5AM of  the droplet's timezone
function install_cf_fw_update_cronjob() {
     echo '0 5 * * * root /opt/cf_fw_update.sh' | sudo tee /tmp/cf_fw_cron >/dev/null >/dev/null
     crontab /tmp/cf_fw_cron
     sudo rm -rf /tmp/cf_fw_cron
}
​
### Install the script for the initial firewall - creates a files in /opt/cffw and puts the bash scripts below inside + executing for initial firewall
function install_cf_fw_script() {
     cat <<-'EOF' > /tmp/cf_fw.sh
#!/usr/bin/env bash
​
###########################
## ----- Variables ----- ##
###########################
all_ipv4_ipv6='0.0.0.0/0,address:::/0'
all_icmp="protocol:icmp,address:${all_ipv4_ipv6}"
all_tcp="protocol:tcp,ports:all,address:${all_ipv4_ipv6}"
all_udp="protocol:udp,ports:all,address:${all_ipv4_ipv6}"
​
ssh_access="protocol:tcp,ports:22,address:${all_ipv4_ipv6}"
​
### - Digital Ocean
droplet_id=$(curl -sSL http://169.254.169.254/metadata/v1/id)
fw_id=$(doctl compute firewall list | grep ${droplet_id} | awk '{print $1}')
fw_name="fw-${droplet_id}"
fw_name_update=$(doctl compute firewall list | grep ${droplet_id} | awk '{print $2}')
​
### - Clouflare
cf_ipv4_list_url='https://www.cloudflare.com/ips-v4'
cf_ipv6_list_url='https://www.cloudflare.com/ips-v6'
#### IPv4s Netblocks
mapfile -t cf_ipv4 < <(curl -sSL ${cf_ipv4_list_url})
cf_ipv4=( "${cf_ipv4[@]/%/,}" ) && cf_ipv4=( "${cf_ipv4[@]/#/address:}" )
cf_ipv4s=$(echo ${cf_ipv4[*]} | tr -d ' ')
#### IPv6s Netblocks
mapfile -t cf_ipv6 < <(curl -sSL ${cf_ipv6_list_url})
#### Add atributies to the netblocks
cf_ipv6=( "${cf_ipv6[@]/%/,}" ) && cf_ipv6=( "${cf_ipv6[@]/#/address:}" )
cf_ipv6s=$(echo ${cf_ipv6[*]} | tr -d ' ')
#### Cloudflare sets
cf_http="protocol:tcp,ports:80,${cf_ipv4s::-1},${cf_ipv6s::-1}"
cf_https="protocol:tcp,ports:443,${cf_ipv4s::-1},${cf_ipv6s::-1}"
​
### Firewall rules
#### Inbound
fw_in="${cf_http} ${cf_https} ${ssh_access}"
#### Outbound
fw_out="${all_tcp} ${all_udp} ${all_icmp}"
​
###########################
## ----- Functions ----- ##
###########################
​
### Downloading the latest netblocks in a separate file
cf_dw_all_netblocks() {
     sudo curl -sSL ${cf_ipv4_list_url} > /opt/cffw/cf_netblocks
     sudo curl -sSL ${cf_ipv6_list_url} >> /opt/cffw/cf_netblocks
} 
​
### fw_create_attach: Creates dir for the files, downloads the latest Clouflare netblocks and creates the initial set of netblock for update checks, installs the firewall
fw_create_attach() {
     sudo mkdir /opt/cffw
     cf_dw_all_netblocks
     doctl compute firewall c --output json --droplet-ids "${droplet_id}" --name ${fw_name}  --inbound-rules "${fw_in}" --outbound-rules "${fw_out}"
}
​
###########################
## ------ Actions ------ ##
###########################
fw_create_attach
​
## Self destroy the script since the firewall is created
rm -- "$0"
exit
EOF
​
​
bash /tmp/cf_fw.sh
exit 0
}
​
### Install the updating script in /opt/cffw 
function install_cf_fw_update_script() {
     cat <<-'EOF' > /opt/cffw/cf_fw_update.sh
#!/usr/bin/env bash
​
###########################
## ----- Variables ----- ##
###########################
​
all_ipv4_ipv6='0.0.0.0/0,address:::/0'
all_icmp="protocol:icmp,address:${all_ipv4_ipv6}"
all_tcp="protocol:tcp,ports:all,address:${all_ipv4_ipv6}"
all_udp="protocol:udp,ports:all,address:${all_ipv4_ipv6}"
​
ssh_access="protocol:tcp,ports:22,address:${all_ipv4_ipv6}"
​
##y Digital Ocean
droplet_id=$(curl -sSL http://169.254.169.254/metadata/v1/id)
fw_id=$(doctl compute firewall list | grep ${droplet_id} | awk '{print $1}')
fw_name="fw-${droplet_id}"
fw_name_update=$(doctl compute firewall list | grep ${droplet_id} | awk '{print $2}')
​
### Clouflare
​
cf_ipv4_list_url='https://www.cloudflare.com/ips-v4'
cf_ipv6_list_url='https://www.cloudflare.com/ips-v6'
#### IPv4s Netblocks
mapfile -t cf_ipv4 < <(curl -sSL ${cf_ipv4_list_url})
cf_ipv4=( "${cf_ipv4[@]/%/,}" ) && cf_ipv4=( "${cf_ipv4[@]/#/address:}" )
cf_ipv4s=$(echo ${cf_ipv4[*]} | tr -d ' ')
#### IPv6s Netblocks
mapfile -t cf_ipv6 < <(curl -sSL ${cf_ipv6_list_url})
#### Add atributies to the netblocks
cf_ipv6=( "${cf_ipv6[@]/%/,}" ) && cf_ipv6=( "${cf_ipv6[@]/#/address:}" )
cf_ipv6s=$(echo ${cf_ipv6[*]} | tr -d ' ')
#### Cloudflare sets
cf_http="protocol:tcp,ports:80,${cf_ipv4s::-1},${cf_ipv6s::-1}"
cf_https="protocol:tcp,ports:443,${cf_ipv4s::-1},${cf_ipv6s::-1}"
​
### Inbound rules
fw_in="${cf_http} ${cf_https} ${ssh_access}"
​
### Outbound rules
fw_out="${all_tcp} ${all_udp} ${all_icmp}"
​
​
###########################
## ----- Functions ----- ##
###########################
​
cf_dw_all_netblocks() {
     sudo curl -sSL ${cf_ipv4_list_url} > /opt/cffw/cf_netblocks
     sudo curl -sSL ${cf_ipv6_list_url} >> /opt/cffw/cf_netblocks
}
​
### Downloads the latest list with netblocks and updates the firewall
fw_update() {
     cf_dw_all_netblocks
     doctl compute firewall u ${fw_id} --output json --name "fw-${droplet_id}" --inbound-rules "${fw_in}" --outbound-rules "${fw_out}"
}
​
### Checks if there is change of the  Cloudflare Netblocks since last install/update
fw_check_for_update() {
     cf_today=$(date +%F)
     sudo curl -sSL ${cf_ipv4_list_url} > /opt/cffw/cf_netblocks-${cf_today}
     sudo curl -sSL ${cf_ipv6_list_url} >> /opt/cffw/cf_netblocks-${cf_today}
     cmp --silent /opt/cffw/cf_netblocks /opt/cffw/cf_netblocks-${cf_today} || fw_update
}
​
###########################
## ------ Actions ------ ##
###########################
​
fw_check_for_update
exit 0
EOF
​
chmod +x /opt/cffw/cf_fw_update.sh
exit 0
}
​
###########################
## ------ Actions ------ ##
###########################
​
### - Install doctl
install_do_ctl
​
### Install cf_fw.sh in /tmp and run it
install_cf_fw_script
​
### Install cf_fw_update.sh in /opt/cffw
install_cf_fw_update_script
​
### Install cronjob
install_cf_fw_update_cronjob
exit 0
