#!/bin/bash
sudo useradd -r -s /sbin/nologin etcd
sudo mkdir -p /var/lib/etcd
sudo chown etcd:etcd /var/lib/etcd
