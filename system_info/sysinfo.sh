#!/bin/bash

# sysinfo.sh - Display basic system information
# LPIC-1 Portfolio Script

echo "=== Hostname ==="
hostname

echo -e "\n=== Uptime ==="
uptime -p

echo -e "\n=== CPU Info ==="
lscpu | grep 'Model name\|CPU(s):\|Architecture'

echo -e "\n=== Memory Info ==="
free -h

echo -e "\n=== Disk Usage ==="
df -hT --total | grep -v tmpfs

echo -e "\n=== IP Addresses ==="
ip -brief addr show | grep -v lo

