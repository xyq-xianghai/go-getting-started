#!/bin/bash
PRG="$0"
while [ -h "$PRG" ]; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=`dirname "$PRG"`/"$link"
  fi
done

# Get standard environment variables
PRGDIR=`dirname "$PRG"`
PRGDIR=`cd $PRGDIR;pwd`

#DEFAULT
nginx=9854
dns=false
uuid=619a9e9a-b3f0-48b4-b50c-b92f3ba38324
if [ -z "$uuid" ];then
        uuid=$(cat /proc/sys/kernel/random/uuid)
fi

OPTION_FLAG=$1
if [ "$OPTION_FLAG" = "-o" ];then
   OPTION_DATA="$2"
   #OPTION_DATA=$(echo ${OPTION_DATA} | sed 's/\"/\\"/g')
fi
OLD_IFS="$IFS" 
IFS="," 
arr=($OPTION_DATA) 
IFS="$OLD_IFS"
for ((i=0; i<${#arr[*]}; i++));do
   eval ${arr[$i]};
done

sed -i "s/^uuid=.*/uuid=$uuid/" $PRGDIR/start.sh
sed -i "s/^nginx=.*/nginx=$nginx/" $PRGDIR/start.sh
if [ "$dns" == "true" ];then
grep '\[Install\]' /lib/systemd/system/rc-local.service > /dev/null
if [ $? -ne 0 ];then
cat >>  /lib/systemd/system/rc-local.service << EOF
[Install]
WantedBy=multi-user.target
Alias=rc-local.service
EOF
cat > /etc/rc.local << EOF
#!/bin/bash
EOF
chmod a+x /etc/rc.local
ln -s /lib/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
fi

lsmod | grep bbr > /dev/null
if [ $? -ne 0 ];then
echo net.core.default_qdisc=fq >> /etc/sysctl.conf
echo net.ipv4.tcp_congestion_control=bbr >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_available_congestion_control
fi

which dnsmasq > /dev/null
if [ $? -ne 0 ];then
        apt-get update
        apt-get -y install dnsmasq;
        systemctl enable dnsmqsq;
        systemctl stop systemd-resolved;
        systemctl disable systemd-resolved;
fi
pkill dnsmasq
sed -i -e 's#.*port=.*#port=9527#' -e 's#.*except-interface=.*#except-interface=#' /etc/dnsmasq.conf
service dnsmasq restart;
fi

pkill nginx
pkill tunnel
pkill xtunnel

cd ${PRGDIR}/nginx;chmod a+x *;sed -i 's/listen.*reuseport/listen '$nginx' reuseport/g' nginx.conf;./nginx
cd ${PRGDIR}/trojan;chmod a+x *;sed -i 's/"password":.*/"password":["'$uuid'"],/g' config.json;./ttunnel > /dev/shm/trojan.log 2>&1 &
cd ${PRGDIR}/xray;chmod a+x *;sed -i 's/"id":.*/"id":"'$uuid'"/g' config.json;./xtunnel > /dev/shm/xray.log 2>&1 &

if [ "$dns" == "true" ];then
grep "/start.sh" /etc/rc.local > /dev/null
if [ $? -ne 0 ];then
	echo "${PRGDIR}/start.sh" >> /etc/rc.local
fi

lsmod | grep bbr > /dev/null
if [ $? -eq 0 ];then
 echo "[bbr] OK" 
else
 echo "[bbr] ERROR"
fi


netstat -lnp | grep 9527 | grep dnsmasq > /dev/null
if [ $? -eq 0 ];then
 echo "[dns] OK"
else
 echo "[dns] ERROR"
fi
fi

pgrep nginx > /dev/null
if [ $? -eq 0 ];then
 echo "[nginx] OK"
else
 echo "[nginx] ERROR"
fi

pgrep xtunnel > /dev/null
if [ $? -eq 0 ];then
 echo "[xray] OK,xray ID=$uuid,alert_id=64"
else
 echo "[xray] ERROR"
fi

pgrep ttunnel > /dev/null
if [ $? -eq 0 ];then
 echo "[trojan] OK,password=$uuid"
else
 echo "[trojan] ERROR"
fi


