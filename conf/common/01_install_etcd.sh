#!/bin/bash
wget https://github.com/etcd-io/etcd/releases/download/v3.5.9/etcd-v3.5.9-linux-amd64.tar.gz
tar xzf etcd-v3.5.9-linux-amd64.tar.gz
sudo mv etcd-v3.5.9-linux-amd64/etcd* /usr/local/bin/
