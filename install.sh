#!/bin/bash
stty erase ^H

red='\e[91m'
green='\e[92m'
yellow='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

_red() { echo -e ${red}$*${none}; }
_green() { echo -e ${green}$*${none}; }
_yellow() { echo -e ${yellow}$*${none}; }
_magenta() { echo -e ${magenta}$*${none}; }
_cyan() { echo -e ${cyan}$*${none}; }

# Root
[[ $(id -u) != 0 ]] && echo -e "\n 请使用 ${red}root ${none}用户运行 ${yellow}~(^_^) ${none}\n" && exit 1

cmd="apt-get"

sys_bit=$(uname -m)

case $sys_bit in
'amd64' | x86_64) ;;
*)
    echo -e " 
	 这个 ${red}安装脚本${none} 不支持你的系统。 ${yellow}(-_-) ${none}

	备注: 仅支持 Ubuntu 16+ / Debian 8+ / CentOS 7+ 系统
	" && exit 1
    ;;
esac

if [[ $(command -v apt-get) || $(command -v yum) ]] && [[ $(command -v systemctl) ]]; then

    if [[ $(command -v yum) ]]; then

        cmd="yum"

    fi

else

    echo -e " 
	 这个 ${red}安装脚本${none} 不支持你的系统。 ${yellow}(-_-) ${none}

	备注: 仅支持 Ubuntu 16+ / Debian 8+ / CentOS 7+ 系统
	" && exit 1

fi

if [ ! -d "/etc/ethminerpro/" ]; then
    mkdir /etc/ethminerpro/
fi

error() {
    echo -e "\n$red 输入错误!$none\n"
}

install_download() {
    installPath="/etc/ethminerpro"
    $cmd update -y
    if [[ $cmd == "apt-get" ]]; then
        $cmd install -y git curl wget supervisor
        service supervisor restart
    else
        $cmd install -y epel-release
        $cmd update -y
        $cmd install -y git curl wget supervisor
        systemctl enable supervisord
        service supervisord restart
    fi
    [ -d ./ethminerpro ] && rm -rf ./ethminerpro
    git clone --depth=1 https://github.com/ethminerpro/ethminerproxy.git

    if [[ ! -d ./ethminerproxy ]]; then
        echo
        echo -e "$red 克隆脚本仓库出错了...$none"
        echo
        echo -e " 请尝试自行安装 Git: ${green}$cmd install -y git $none 之后再安装此脚本"
        echo
        exit 1
    fi
    mv ethminerproxy ethminerpro
    cp -rf ./ethminerpro /etc/
    if [[ ! -d $installPath ]]; then
        echo
        echo -e "$red 复制文件出错了...$none"
        echo
        echo -e " 使用最新版本的Ubuntu或者CentOS再试试"
        echo
        exit 1
    fi
}

start_write_config() {
    echo
    echo "下载完成，开启守护"
    echo
    supervisorctl stop all
    chmod a+x $installPath/ethminerproxy_linux
    if [ -d "/etc/supervisor/conf/" ]; then
        rm /etc/supervisor/conf/ethminerpro.conf -f
        echo "[program:ethminerpro]" >>/etc/supervisor/conf/ethminerpro.conf
        echo "command=${installPath}/ethminerproxy_linux" >>/etc/supervisor/conf/ethminerpro.conf
        echo "directory=${installPath}/" >>/etc/supervisor/conf/ethminerpro.conf
        echo "autostart=true" >>/etc/supervisor/conf/ethminerpro.conf
        echo "autorestart=true" >>/etc/supervisor/conf/ethminerpro.conf
    elif [ -d "/etc/supervisor/conf.d/" ]; then
        rm /etc/supervisor/conf.d/ethminerpro.conf -f
        echo "[program:ethminerpro]" >>/etc/supervisor/conf.d/ethminerpro.conf
        echo "command=${installPath}/ethminerproxy_linux" >>/etc/supervisor/conf.d/ethminerpro.conf
        echo "directory=${installPath}/" >>/etc/supervisor/conf.d/ethminerpro.conf
        echo "autostart=true" >>/etc/supervisor/conf.d/ethminerpro.conf
        echo "autorestart=true" >>/etc/supervisor/conf.d/ethminerpro.conf
    elif [ -d "/etc/supervisord.d/" ]; then
        rm /etc/supervisord.d/ethminerpro.ini -f
        echo "[program:ethminerpro]" >>/etc/supervisord.d/ethminerpro.ini
        echo "command=${installPath}/ethminerproxy_linux" >>/etc/supervisord.d/ethminerpro.ini
        echo "directory=${installPath}/" >>/etc/supervisord.d/ethminerpro.ini
        echo "autostart=true" >>/etc/supervisord.d/ethminerpro.ini
        echo "autorestart=true" >>/etc/supervisord.d/ethminerpro.ini
    else
        echo
        echo "----------------------------------------------------------------"
        echo
        echo " Supervisor安装目录没了，安装失败"
        echo
        exit 1
    fi

    if [[ $cmd == "apt-get" ]]; then
        ufw disable
    else
        systemctl stop firewalld
    fi

    changeLimit="n"
    if [ $(grep -c "root soft nofile" /etc/security/limits.conf) -eq '0' ]; then
        echo "root soft nofile 60000" >>/etc/security/limits.conf
        changeLimit="y"
    fi
    if [ $(grep -c "root hard nofile" /etc/security/limits.conf) -eq '0' ]; then
        echo "root hard nofile 60000" >>/etc/security/limits.conf
        changeLimit="y"
    fi
    change_limit_up

    clear
    echo
    echo "----------------------------------------------------------------"
    echo
    if [[ "$changeLimit" = "y" ]]; then
        echo -e "$red系统连接数限制已经改了，如果第一次运行本程序需要<重启服务器>配置才能生效!$none"
        echo
    fi
    supervisorctl start all
    supervisorctl reload
    echo "如果还无法连接，请到云服务商控制台操作安全组，放行对应的端口"
    echo
    echo "安装完成...守护模式无日志，需要日志的请以nohup ./ethminerproxy_linux &方式运行"
    echo
    echo "以下配置文件：/etc/ethminerpro/conf.yaml，网页端可修改登录密码token"
    echo
    echo "[*---------]"
    sleep 1
    echo "[**--------]"
    sleep 1
    echo "[***-------]"
    sleep 1
    echo "[****------]"
    sleep 1
    echo "[*****-----]"
    sleep 1
    echo "[******----]"
    echo
    cat /etc/ethminerpro/conf.yaml
    echo "----------------------------------------------------------------"
}

uninstall() {
    clear
    if [ -d "/etc/supervisor/conf/" ]; then
        rm /etc/supervisor/conf/ethminerpro.conf -f
    elif [ -d "/etc/supervisor/conf.d/" ]; then
        rm /etc/supervisor/conf.d/ethminerpro.conf -f
    elif [ -d "/etc/supervisord.d/" ]; then
        rm /etc/supervisord.d/ethminerpro.ini -f
    fi
    supervisorctl reload
    echo -e "$yellow 已关闭自启动${none}"
}



update(){

    supervisorctl stop ethminerpro
    [ -d ./ethminerpro ] && rm -rf ./ethminerpro
    [ -d ./ethminerproxy ] && rm -rf ./ethminerproxy


    git clone https://github.com/ethminerpro/ethminerproxy.git

    if [[ ! -d ./ethminerproxy ]]; then
        echo
        echo -e "$red 克隆脚本仓库出错了...$none"
        echo
        echo -e " 请尝试自行安装 Git: ${green}$cmd install -y git $none 之后再安装此脚本"
        echo
        exit 1
    fi
    mv ethminerproxy ethminerpro
    rm /etc/ethminerpro/ethminerproxy_linux -f
    cp -rf ./ethminerpro/ethminerproxy_linux /etc/ethminerpro/ethminerproxy_linux


    chmod a+x /etc/ethminerpro/ethminerproxy_linux
    supervisorctl start ethminerpro


    sleep 2s
    echo "ethminerpro 已經更新至V5.1.0版本並啟動"
    cat /etc/ethminerpro/conf.yaml
    echo ""
    echo "以上是配置文件信息"
}



start(){

    supervisorctl start ethminerpro
    
    echo "ethminerpro已啟動"
}


restart(){
    supervisorctl restart ethminerpro

    echo "ethminerpro 已經重新啟動"
}


stop(){
    supervisorctl stop ethminerpro
    echo "ethminerpro 已停止"
}

change_limit(){
    change_limit_up
    if grep -q "1000000" "/etc/profile"; then
        echo -n "您的系統連接數限制可能已修改，當前連接限制："
        ulimit -n
        exit
    fi
change_limit_up
}

change_limit_up(){

# 优化TCP窗口
    sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_adv_win_scale/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    cat >>/etc/sysctl.conf <<EOF
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 16384 16777216
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p && sysctl --system

#开启内核转发
    sed -i '/net.ipv4.conf.all.route_localnet/d' /etc/sysctl.conf
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.all.forwarding/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.default.forwarding/d' /etc/sysctl.conf
    cat >>'/etc/sysctl.conf' <<EOF
net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
EOF
    sysctl -p && sysctl --system

#修改连接数
    echo "1000000" >/proc/sys/fs/file-max
    sed -i '/fs.file-max/d' /etc/sysctl.conf
    cat >>'/etc/sysctl.conf' <<EOF
fs.file-max=1000000
EOF

    ulimit -SHn 1000000 && ulimit -c unlimited
    echo "root     soft   nofile    1000000
root     hard   nofile    1000000
root     soft   nproc     1000000
root     hard   nproc     1000000
root     soft   core      1000000
root     hard   core      1000000
root     hard   memlock   unlimited
root     soft   memlock   unlimited

*     soft   nofile    1000000
*     hard   nofile    1000000
*     soft   nproc     1000000
*     hard   nproc     1000000
*     soft   core      1000000
*     hard   core      1000000
*     hard   memlock   unlimited
*     soft   memlock   unlimited
" >/etc/security/limits.conf
    if grep -q "ulimit" /etc/profile; then
        :
    else
        sed -i '/ulimit -SHn/d' /etc/profile
        echo "ulimit -SHn 1000000" >>/etc/profile
    fi
    if grep -q "pam_limits.so" /etc/pam.d/common-session; then
        :
    else
        sed -i '/required pam_limits.so/d' /etc/pam.d/common-session
        echo "session required pam_limits.so" >>/etc/pam.d/common-session
    fi

    sed -i '/DefaultTimeoutStartSec/d' /etc/systemd/system.conf
    sed -i '/DefaultTimeoutStopSec/d' /etc/systemd/system.conf
    sed -i '/DefaultRestartSec/d' /etc/systemd/system.conf
    sed -i '/DefaultLimitCORE/d' /etc/systemd/system.conf
    sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
    sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf

    cat >>'/etc/systemd/system.conf' <<EOF
[Manager]
#DefaultTimeoutStartSec=90s
DefaultTimeoutStopSec=30s
#DefaultRestartSec=100ms
DefaultLimitCORE=infinity
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF

    systemctl daemon-reload

    echo "系統連接數限制已修改，手動reboot重啟下系統即可生效"
}



check_limit(){
    echo -n "您的系統當前連接限制："
    ulimit -n
}

clear
while :; do
    echo
    echo "-------- ethminerpro 一键安装脚本 by:ethminerpro--------"
    echo "github下载地址:https://github.com/ethminerpro/ethminerproxy"
    echo "官方电报群:https://t.me/trexminerproxy"
    echo
    echo " 1. 安  装"
    echo
    echo " 2. 卸  载"
    echo
    echo " 3. 更  新"
    echo
    echo " 4. 启  动"
    echo
    echo " 5. 重  启"
    echo
    echo " 6. 停  止"
    echo
    echo " 7. 一鍵解除Linux連接數限制(需手動重啟系統生效)"
    echo
    echo " 8. 查看當前系統連接數限制"
    echo
    read -p "$(echo -e "请选择 [${magenta}1-8$none]:")" choose
    case $choose in
    1)
        install_download
        start_write_config
        break
        ;;
    2)
        uninstall
        break
        ;;
    3)
        update
        ;;
    4)
        start
        ;;
    5)
        restart
        ;;
    6)
        stop
        ;;
    7)
        change_limit
        ;;
    8)
        check_limit
        ;;

    *)
	echo "error請輸入正確的數字！"
        ;;
    esac
done
