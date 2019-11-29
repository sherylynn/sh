#!/bin/bash
. ~/namesilo_key.sh
echo "key is"
echo ${NAMESILO_KEY}
API_KEY=${NAMESILO_KEY}
MyDomain=sherylynn.win
HostA="ipv6"

renew_hostip()
{
        local   response_xml rspinfo
        local   record_id host_ip
        local   wan0_ip

        wan0_ip=$(~/sh/termux/ipv6.sh)
        #Get dnsListRecords
        response_xml=$(curl -s "https://www.namesilo.com/api/dnsListRecords?version=1&type=xml&key=${API_KEY}&domain=${MyDomain}")

        echo "Get Record_ID!"
        record_id=$(echo ${response_xml} | sed "s/^.*<record_id>\([0-9a-z]*\)<\/record_id><type>AAAA<\/type><host>$1\.${MyDomain}<\/host>.*$/\1/")
        echo $record_id
        if [[ ${#record_id} -gt 30 ]] && [[ ${#record_id} -lt 34 ]]; then
                echo "DNS Record ID of $1.${MyDomain} Is: ${record_id}"
        else
                echo "$1.${MyDomain} Record Is No Exist!"
        fi

        #See If Host Record ID No Exist? Create New One!
        if [[ ${#record_id} -gt 34 ]] || [[ ${#record_id} -lt 30 ]]; then
                echo "Create A New Record!"
                rspinfo=$(curl -s "https://www.namesilo.com/api/dnsAddRecord?version=1&type=xml&key=${API_KEY}&domain=${MyDomain}&rrtype=AAAA&rrhost=$1&rrvalue=${wan0_ip}&rrttl=7207")
                return 0;
        fi

        echo "Get Host's IP"
        if [ "$1"x == ""x ]; then
                host_ip=$(echo ${response_xml} | sed "s/^.*<host>${MyDomain}<\/host><value>\([0-9\.]*\)<\/value>.*$/\1/")
                echo "Host's IP of ${MyDomain} Is: ${host_ip}"
        else 
                host_ip=$(echo ${response_xml} | sed "s/^.*<host>$1\.${MyDomain}<\/host><value>\([0-9\.]*\)<\/value>.*$/\1/")
                echo "Host's IP of $1.${MyDomain} Is: ${host_ip}"
        fi

        #See If Wan IP Was Changed ?
        if [ "${wan0_ip}" == "${host_ip}" ]; then
                echo "IP is no change, don't need updata!"
                return 0
        fi

        echo "Update Host IP!"
        rspinfo=$(curl -s "https://www.namesilo.com/api/dnsUpdateRecord?version=1&type=xml&key=${API_KEY}&domain=${MyDomain}&rrid=\
${record_id}&rrhost=$1&rrvalue=${wan0_ip}&rrttl=7207")
#       echo ${rspinfo}

        return 0
}

date +%D%t%H:%M:%S
echo "*****************************************"
renew_hostip	${HostA}
echo "*****************************************"
exit 0
