#!/bin/bash

function is_root() {
    if [[ $EUID -eq 0 ]]; then
        echo 1
    else
        echo 0
    fi
}

function get_system_id() {
    if [[ -f /etc/os-release ]]; then
        source '/etc/os-release'
        echo "$ID"
      elif [[ -f /etc/lsb-release ]]; then
        echo "ubuntu"
      elif [[ -f /etc/centos-release ]]; then
            echo "centos"
      else
        echo "unknown"
      fi
}

SYSTEM_ID=$(get_system_id)

function basic_optimization() {
    if [[ -e /etc/sysctl.conf ]]; then
        sed -i '/fs.file-max/d' /etc/sysctl.conf
        sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
        sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
        sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
        sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
        sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
        sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
        echo "fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
net.ipv4.ip_forward = 1">>/etc/sysctl.conf
    else
        echo "Nothing has changed."
    fi
}

function adjust_resource_limits(){
    if [[ -e /etc/security/limits.conf ]]; then
        sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
          sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
          echo '* soft nofile 65536' >>/etc/security/limits.conf
          echo '* hard nofile 65536' >>/etc/security/limits.conf
    else
        echo "Nothing has changed."
    fi
}

function close_firewall() {
      if [[ ${SYSTEM_ID} == "centos" ]]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0
        systemctl stop firewalld
        systemctl disable firewalld > /dev/null 2>&1
      elif [[ ${SYSTEM_ID} == "ubuntu" ]]; then
          systemctl stop ufw
          systemctl disable ufw > /dev/null 2>&1
      else
          echo "Nothing has changed."
      fi
}

function update_kernel() {
    if [[ ${SYSTEM_ID} == "centos" ]]; then
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
        yum --enablerepo=elrepo-kernel install kernel-lt-devel kernel-lt -y
        grub2-set-default 0
    else
        echo "This script does not support kernel upgrades for the current system."
    fi
}

function enable_bbr(){
    if [[ ${SYSTEM_ID} == "centos" || ${SYSTEM_ID} == "ubuntu" ]]; then
        kernel_version=$(uname -r)
        if [[ $kernel_version =~ ^4\. || $kernel_version =~ ^5\. ]]; then
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p
        else
            echo "The current kernel version cannot enable BBR."
        fi
    else
        echo "This script does not support enable BBR for the current system."
    fi
}

function update_script(){
    script_dir=$(dirname "$0")
    script_name=$(basename "$0")
    url="https://"
    cp "${script_dir}/${script_name}" "${script_dir}/${script_name}_$(date +%Y%m%d%H%M)"
    wget -q --no-check-certificate "${url}" -O "${script_dir}/${script_name}"
    if [[ $? -eq 0 ]]; then
        echo "Script update completed."
    else
        echo "Script update failed."
    fi
}

function change_sshd_port(){
    new_port=$1
    if [[ ${SYSTEM_ID} == "centos" || ${SYSTEM_ID} == "ubuntu" ]]; then
        if [[ -e /etc/ssh/sshd_config ]]; then
            cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
            if [[ -z $(grep "^Port" /etc/ssh/sshd_config) ]]; then
                echo "Port ${new_port}" >> /etc/ssh/sshd_config
            else
                sed -i "s/^Port [0-9]*/Port ${new_port}/g" /etc/ssh/sshd_config
            fi
            systemctl restart sshd
        else
            echo "Configuration file for sshd not found"
        fi
    else
        echo "This script does not support change sshd port for the current system."
    fi
}

function add_ssh_key(){
    user=$1
    ssh_key=""
    if $(id -u ${user} >/dev/null 2>&1); then
        if [[ ${user} == 'root' ]]; then
        	mkdir /root/.ssh
        	touch /root/.ssh/authorized_keys
        	chmod 700 /root/.ssh
        	chmod 600 /root/.ssh/authorized_keys
        	echo "${ssh_key}" >> /root/.ssh/authorized_keys
        else
        	mkdir /home/${user}/.ssh
        	touch /home/${user}/.ssh/authorized_keys
        	chmod 700 /home/${user}/.ssh
        	chmod 600 /home/${user}/.ssh/authorized_keys
        	echo "${ssh_key}" >> /home/${user}/.ssh/authorized_keys
        	chown -R ${user}:${user} /home/${user}/.ssh
        fi
    else
    	echo "The user '${user}' does not exist"
    fi
}

function main() {
    case $1 in
          "root-check")
            is_root
            ;;
        "system-check")
            echo "$SYSTEM_ID"
              ;;
        "system-optimize")
            basic_optimization
            ;;
        "system-update")
            update_kernel
            ;;
        "system-firewall")
            close_firewall
            ;;
        "resource_limits")
            adjust_resource_limits
            ;;
        "tcp-bbr")
            enable_bbr
            ;;
        "script-update")
            update_script
            ;;
        "ssh-port")
            change_sshd_port $2
            ;;
        "ssh-key")
            add_ssh_key $2
            ;;
        ?*)
              echo "Unsupported feature"
              ;;
        *)
            ;;
      esac
}

main "$@"