#!/bin/bash
sudo dnf -qy module disable postgresql
sudo dnf install -y postgresql14 postgresql14-server postgresql14-contrib postgresql14-libs postgresql14-devel
