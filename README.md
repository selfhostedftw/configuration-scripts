# Configuration Scripts

### Digital Ocean & Cloudflare Firewall
This script works between a Digital Ocean Droplet and Cloudflare. After you have set up a domain name with SSL enabled, it crates and attaches a new firewall to the droplet, and then only allows traffic from Cloudflare in. Run this script to enable a cron job and automatic updates (nightly at 5AM).

`curl -sSL https://raw.githubusercontent.com/selfhostedofficial/configuration-scripts/master/enable-automatic-updates-via-cron.sh | bash`
