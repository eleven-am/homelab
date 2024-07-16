#!/bin/bash

apk search openssh
apk add openssh
rc-update add sshd
service sshd start

echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories
apk add -U tailscale
rc-update add tailscale
/etc/init.d/tailscale start
