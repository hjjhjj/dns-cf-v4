# dns-cf-v4
- Update your CloudFlare DNS record to the ipv4/v6
- Delete your CloudFlare DNS record (ipv4/v6)
- Run in HOST with many VMs who use HOST's bridge interface
- Can update HOST ipv4 and ipv6(eui64) and VMs ipv6(eui64)

suppose that zone name is example.com,
config file is /root/.config/dns-cf-v4/example.com.conf
```
# conf file, don't add space after '='
# get zone_id from https://dash.coudflare.com, Websites Overview
zone_id=
# get api_token from https://dash.cloudflare.com/profile/api-tokens
api_token=
# End conf file
```

crontab for root
```
# update ipv4.example.com, 
*/11 * * * * /usr/local/sbin/dns-cf-v4.zsh -d ipv4.example.com -t A 2>&1 >/dev/null

# update ipv6.example.com, config file /root/.config/dns-cf-v4/example.com.conf
# get ipv6 prefix from bridge interface br0 of HOST, -s setup ipv6 suffix of VM
# NOTE: ping -6 ipv6.example.com a few miniutes later to make sure \
#       prefix:suffix IS EXACTLY MATCH dns server response. ( :0dad: is different to :dad: )
*/17 * * * * /usr/local/sbin/dns-cf-v4.zsh -d ipv6.example.com -t AAAA -i br0 -s 5054:ff:fe12:3456 2>&1 >/dev/null
```

- command line, delete ipv4.example.com record
```
/usr/local/sbin/dns-cf-v4.zsh -d ipv6.example.com -t A -r
```
- command line, delete ipv6.example.com record
```
/usr/local/sbin/dns-cf-v4.zsh -d ipv6.example.com -t AAAA -r
```
- command line, force set ipv4.example.com record to 8.8.8.8
```
/usr/local/sbin/dns-cf-v4.zsh -d ipv4.example.com -t A -f 8.8.8.8
```
