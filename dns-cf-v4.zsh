#!/usr/bin/env zsh
#set -x
set -o err_return
set -o no_unset
set -o pipefail

# Support CloudFlare multi zones (different config file)
# Update your CloudFlare DNS record to the ipv4/v6
# Delete your CloudFlare DNS record (ipv4/v6)
# Run in HOST with many VMs who use HOST's bridge interface
# Can update HOST ipv4 and ipv6(eui64) and VMs ipv6(eui64)

# curl https://raw.githubusercontent.com/hjjhjj/dns-cf-v4/main/dns-cf-v4.zsh > /usr/local/sbin/dns-cf-v4.zsh && chmod +x /usr/local/sbin/dns-cf-v4.zsh

# suppose that zone name is example.com
# config file is /root/.config/dns-cf-v4/example.com.conf

# # conf file, don't add space after '='
# # get zone_id from https://dash.cloudflare.com, Websites Overview
# zone_id=
# # get api_token from https://dash.cloudflare.com/profile/api-tokens
# api_token=
# # End conf file

# crontab for root
# update ipv4.example.com, config file /root/.config/dns-cf-v4/example.com.conf
# */11 * * * * /usr/local/sbin/dns-cf-v4.zsh -d ipv4.example.com -t A 2>&1 >/dev/null

# update ipv6.example.com, config file /root/.config/dns-cf-v4/example.com.conf
# get ipv6 prefix from bridge interface br0 of HOST, -s setup ipv6 suffix of HOST/VM
# NOTE: ping -6 ipv6.example.com a few miniutes later to make sure \
#       prefix:suffix IS EXACTLY MATCH dns server response. ( :0dad: is different to :dad: )
# */17 * * * * /usr/local/sbin/dns-cf-v4.zsh -d ipv6.example.com -t AAAA -i br0 -s 5054:ff:fe12:3456 2>&1 >/dev/null

# command line, delete ipv4.example.com record
# /usr/local/sbin/dns-cf-v4.zsh -d ipv4.example.com -t A -r

# command line, delete ipv6.example.com record
# /usr/local/sbin/dns-cf-v4.zsh -d ipv6.example.com -t AAAA -r

# command line, force set ipv4.example.com record to 8.8.8.8
# /usr/local/sbin/dns-cf-v4.zsh -d ipv4.example.com -t A -f 8.8.8.8


# default conf setting
ttl=1 # auto
proxy=false

readconf()
{
    local cfile=$1 
    [[ ! -f $cfile ]] && echo "can not found config file: $cfile, please check !" && return 2
    source $cfile
    [ -n $api_token ]
    [ -n $zone_id ]
}

listRecord()
{
    local zoneId=$1
    local recordName=$2
    local type=$3
    local apiKey=$4

    local result=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?name=$recordName&type=$type"\
        -H "Content-Type:application/json" \
        -H "Authorization: Bearer $apiKey")
    #echo $result

    local resourceId=$(echo "$result" | grep -Po '(?<="id":")[^"]+')
    local currentValue=$(echo "$result" | grep -Po '(?<="content":")[^"]+')

    local successStat=$(echo "$result" | grep -Po '(?<="success":)[^,]+')
    if [ "$successStat" != "true" ]; then
    #    local errors=$(echo "$result" | grep -Po '(?<="errors:\[\{":)[^}]+')
        return 3
    fi

    printf '%s\n%s' "$resourceId" "$currentValue"
}

createRecord()
{
    local zoneId=$1
    local recordName=$2
    local apiKey=$3
    local type=$4
    local value=$5

    local result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records" \
        -H "Authorization: Bearer $apiKey" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$type\",\"name\":\"$recordName\",\"content\":\"$value\",\"ttl\":1,\"proxied\":false}")
    local successStat=$(echo "$result" | grep -Po '(?<="success":)[^,]+')
    if [ "$successStat" != "true" ]; then
        return 1
    fi
    local recordId=$(echo "$result" | grep -Po '(?<="id":")[^"]+')
    echo "$recordId"
}

deleteRecord()
{
    local zoneId=$1
    local identifier=$2
    local apiKey=$3
    
    local result=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$identifier" \
        -H "Authorization: Bearer $apiKey" \
        -H "Content-Type: application/json")

    local successStat=$(echo "$result" | grep -Po '(?<="success":)[^,]+')
    [ "$successStat" = "true" ]
    return $?
}

updateRecord()
{
    local zoneId=$1
    local recordName=$2
    local apiKey=$3
    local resourceId=$4
    local type=$5
    local value=$6

    local result=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$resourceId" \
        -H "Authorization: Bearer $apiKey" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$type\",\"name\":\"$recordName\",\"content\":\"$value\",\"ttl\":1,\"proxied\":false}")

    local successStat=$(echo "$result" | grep -Po '(?<="success":)[^,]+')
    [ "$successStat" = "true" ]
    return $?
}

conf_example()
{
    echo
    echo "# conf file, don't add space after '='"
    echo "# get zone_id from https://dash.coudflare.com, Websites Overview"
    echo "zone_id="
    echo "# get api_token from https://dash.cloudflare.com/profile/api-tokens"
    echo "api_token="
    echo "# End conf file"
    echo
}

usage()
{
    echo "Usage: first to create conf file in $HOME/.config/dns-cf-v4/{ROOT_DOMAIN}.conf"
    echo "ROOT_DOMAIN: www.example.com ROOT_DOMAIN is example.com"
    conf_example
    echo "dns-cf-v4.zsh -d domain # domain record to be processed"
    echo "              -t A|AAAA # record type , A for ipv4, AAAA for ipv6"
    echo "              -r        # remove the domain record"
    echo "              -i ifname # ipv6, bridge interface name, such as br0"
    echo "              -s suffix # ipv6 suffix, 1234:5678:90ab:cdef"
    echo "              -f ip     # force set ipv4/v6 address to the given value"
    exit 0
}

# use domain flow if you have many wan ip
getIpv4Address()
{
    curl -s ipv4.ident.me
    # curl -s  ifconfig.co
    # curl -s ipv4.nsupdate.info/myip
}

getIpv6Address()
{
    local suffix=$1
    local ifname=$2 

    local myipv6=$(ip -o -6 a s $ifname|grep -v deprecated|grep ' inet6 [^f:]'|sed -nr 's#^.+? +inet6 ([a-f0-9:]+)/.+? scope global .*? valid_lft ([0-9]+sec) .*#\2 \1#p'|grep 'ff:fe'|sort -nr|head -n1|cut -d' ' -f2)
    if [ $? -ne 0 ]; then
        return 1
    fi
    local prefix=$(echo $myipv6 | cut -d':' -f 1-4)
    if [ $#prefix -eq 0 ]; then
        return 1
    fi

    printf '%s:%s' "$prefix" "$suffix"
}

[ $# -eq 0 ] && usage

# get parameter
DEL_RECORD=false
IFNAME=""
SUFFIX=""
FORCE_IP=""

while getopts hrd:t:i:s:f: opts; do
    case ${opts} in
        r) DEL_RECORD=true ;;
        d) domain=${OPTARG} ;;
        t) record_type=${OPTARG} ;;
        i) IFNAME=${OPTARG} ;;
        s) SUFFIX=${OPTARG} ;;
        f) FORCE_IP=${OPTARG} ;;
        h|:|*) usage ;;
    esac
done

ROOT_DOMAIN=`echo $domain | awk -F'.' '{printf "%s.%s", $(NF-1), $NF}'`

# read conf
readconf $HOME/.config/dns-cf-v4/"${ROOT_DOMAIN}".conf

if [ $DEL_RECORD = false ] && [ "$FORCE_IP" = "" ]; then
    # get ip
    if [ "$record_type" = "A" ]; then
        externalIpAdd=$(getIpv4Address)
        echo "external ipv4 address: $externalIpAdd"
    elif [ $record_type = "AAAA" ]; then
        if [ -z $IFNAME ] || [ -z $SUFFIX ]; then
            echo "AAAA need ifname and suffix!"
            return 10
        fi
        externalIpAdd=$(getIpv6Address "$SUFFIX" "$IFNAME")
        echo "external ipv6 address: $externalIpAdd"
    else
        return 6
    fi
fi

currentStat=$(listRecord "$zone_id" "$domain" "$record_type" "$api_token")
#currentStat=""
resourceId=$(echo "$currentStat" | sed -n '1p')
currentValue=$(echo "$currentStat" | sed -n '2p')

if [ "$FORCE_IP" != "" ]; then
    echo "force set ip: $FORCE_IP"
    externalIpAdd=$FORCE_IP
fi

if [ -z $resourceId ]  ; then
    if [ $DEL_RECORD = false ]; then
        createdRecordResourceId=$(createRecord "$zone_id" "$domain" "$api_token" "$record_type" "$externalIpAdd")
        echo "$domain : => $externalIpAdd"
        return 0
    else
        return 5 # can not delete without resourceId.
    fi
fi

if [ $DEL_RECORD = true ]; then
    deleteRecord "$zone_id" "$resourceId" "$api_token"
    echo "del domain record: $domain OK!"
else
    if [ "$currentValue" != "$externalIpAdd" ]; then
        updateRecord "$zone_id" "$domain" "$api_token" "$resourceId" "$record_type" "$externalIpAdd"
        echo "$domain: $currentValue => $externalIpAdd"
    else
        echo "$domain ip not change."
    fi
fi
