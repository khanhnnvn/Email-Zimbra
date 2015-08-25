#!/bin/bash

function valid_ip()
{
    local ip=$1
    local stat=1
    if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IF
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function change_zimbra_settings {
    su zimbra -c "/opt/zimbra/bin/zmprov --ldap rd test.com $domain_name"
    sudo -u zimbra -i  /opt/zimbra/libexec/zmsetservername $server_name
}

function change_host_settings {
    sed -i "s/^192\.168\.100\.6.*$/$server_IP $server_name $domain_name/" /etc/hosts
	echo HOSTNAME $server_name >> /etc/sysconfig/network 
	sed -i "s/^GATEWAY.*/GATEWAY=\"$gw_IP\"/" /etc/sysconfig/network
	sed -i "s/^GATEWAY.*/GATEWAY=$gw_IP/" /etc/sysconfig/network-scripts/ifcfg-eth0
	sed -i "s/^IPADDR.*/IPADDR=$server_IP/" /etc/sysconfig/network-scripts/ifcfg-eth0
}

function change_DNS_settings {
    sed "s/yourhostnamehere/$server_name/g" zone |\
        sed "s/yourdomainnamehere/$domain_name/g" >\
        sed "s/youriphere/$server_IP/g" >\
            /var/named/chroot/var/named/$domain_name.host
    sed "s/yourdomainnamehere/$domain_name/g" hosts >\
        /var/named/chroot/etc/named.conf
    rndc reload
}

function clean_up {
    case $dns_server in
        "noi bo" )
        break
        ;;
        * ) 
        echo $dns_server > /etc/resolv.conf
		chkconfig named off
		;;
	esac
}

function read_answer {
    answer=""
    until ([ "$answer" = "yes" ] || [ "$answer" = "no" ])
    do
        read answer
        case $answer in
            "Yes" | "yes" | "Y" | "y" )
            answer="yes"
            break
            ;;
            "No" | "no" | "N" | "n" )
            answer="no"
            break
            ;;
            * )
            echo "Xin hay nhap 'Y' hoac 'N'"
            ;;
        esac
    done
}

if [[ $EUID -ne 0 ]]; then
    echo "Ban phai chay script nay duoi quyen root!"
    exit 1
fi

echo "CHAO MUNG BAN DEN VOI AMS"
echo "Chuong trinh nay se tro giup ban thiet lap cac thong so cua may chu AMS."
echo "Truoc khi tien hanh thiet lap, cac ban can tham khao thong so tu nguoi"
echo "quan tri hoac lien he voi chung toi de duoc tro giup chi tiet (xin xem"
echo "them tai lieu di kem)."
echo "Ban co dong y tiep tuc hay khong: Y/N"
read_answer
if [ "$answer" = "no" ]; then
    exit 1
fi

answer=""
until [ "$answer" = "yes" ]
do
    echo "Server IP Address/Dia chi IP cua may chu:"
    read server_IP
    until (valid_ip $server_IP)
    do
        echo "Dia chi IP khong hop le! Xin hay dien lai!"
        read server_IP
    done
    echo "Gateway IP/Dia chi IP cua Gateway:"
	read gw_IP
	until (valid_ip $gw_IP)
	do
		echo "Dia chi IP khong hop le! Xin hay dien lai!"
		read gw_IP
	done
	echo "Domain name/Ten mien cua he thong"
    read domain_name
    echo "Server name/Ten may chu (ext. mail.server.com ):"
    read server_name
    echo "Use an extend DNS/Su dung may chu DNS ngoai: Y/N"
    read_answer
    if [ "$answer" = "no" ]; then
        dns_server="noi bo"
    else
        echo "Your extend DNS IP/IP cua may chu DNS ngoai:"
        read dns_server
        until (valid_ip $dns_server)
        do
            echo "Dia chi IP khong hop le! Xin hay nhap lai:"
            read dns_server
        done
    fi
    echo "Xin kiem tra lai xem cac thong tin sau day co chinh xac khong:"
    echo "Ten day du cua may chu:" $server_name
    echo "Ten mien email:" $domain_name
    echo "Dia chi IP cua may chu:" $server_IP
	echo "Dia chi IP cua gateway:" $gw_IP
    echo "May chu DNS:" $dns_server
    echo "Y|N" 
    read_answer
    if [ "$answer" = "no" ]; then
        echo "Ban co muon nhap lai khong?"
        read_answer
        if [ "$answer" = "no" ]; then
            exit 1
        else
            answer=""
        fi
    fi
done
echo "OK"

change_DNS_settings
change_zimbra_settings
change_host_settings
clean_up
su zimbra -c "/opt/zimbra/bin/zmcontrol start"

echo 'Viec cai dat da hoan tat, ban co the vao dia chi' 
echo 'https://'$server_name':7071 de bat dau thiet lap'

