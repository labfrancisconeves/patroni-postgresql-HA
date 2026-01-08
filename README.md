# PostgreSQL HA Setup with Patroni/etcd/keepalived

In this project, we implemented a high availability solution for PostgreSQL using three complementary components: ETCD, Patroni, and Keepalived. ETCD acts as a distributed configuration and coordination system, maintaining cluster state and ensuring consensus among nodes. Patroni is responsible for orchestrating PostgreSQL by managing replication, automatic failover, and health checks. Lastly, Keepalived manages the virtual IP (VIP) address, ensuring that the database service is always reachable at a fixed address, even in the event of a node failure, allowing seamless transitions for the end user. This integration provides a robust, resilient environment with automatic failover for PostgreSQL.

- [1\. Networking pre-requisites](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [PostgreSQL Replication and HA - Firewall and User Requirements](#PostgreSQLHASetupwithPatroni/etcd/k)
    - [Firewall Ports](#PostgreSQLHASetupwithPatroni/etcd/k)
    - [Required PostgreSQL Users](#PostgreSQLHASetupwithPatroni/etcd/k)
- [2\. Environment](#PostgreSQLHASetupwithPatroni/etcd/k)
- [3\. ETCD - Cluster](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Step 1. Install etcd on each node](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Step 2. Create user and folder for the service](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Step 3. Create file /etc/systemd/system/etcd.service](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Start and enable service on each node](#PostgreSQLHASetupwithPatroni/etcd/k)
- [4\. Postgresql 14](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Installation](#PostgreSQLHASetupwithPatroni/etcd/k)
- [5\. Patroni](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Dependency installation](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Create the service file (/etc/systemd/system/patroni.service)](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Create file /etc/patroni.yml](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Start and enable the service on the 2 nodes](#PostgreSQLHASetupwithPatroni/etcd/k)
- [6\. Keepalived](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Installation](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Create file /etc/keepalived/keepalived.conf](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Create the IP bounce script /usr/local/bin/check_patroni.sh](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Start and enable the service on the 2 nodes:](#PostgreSQLHASetupwithPatroni/etcd/k)
- [7\. Useful commands](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Check patroni cluster status](#PostgreSQLHASetupwithPatroni/etcd/k)# PostgreSQL HA Setup with Patroni/etcd/keepalived

In this project, we implemented a high availability solution for PostgreSQL using three complementary components: ETCD, Patroni, and Keepalived. ETCD acts as a distributed configuration and coordination system, maintaining cluster state and ensuring consensus among nodes. Patroni is responsible for orchestrating PostgreSQL by managing replication, automatic failover, and health checks. Lastly, Keepalived manages the virtual IP (VIP) address, ensuring that the database service is always reachable at a fixed address, even in the event of a node failure, allowing seamless transitions for the end user. This integration provides a robust, resilient environment with automatic failover for PostgreSQL.

- [1\. Networking pre-requisites](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [PostgreSQL Replication and HA - Firewall and User Requirements](#PostgreSQLHASetupwithPatroni/etcd/k)
    - [Firewall Ports](#PostgreSQLHASetupwithPatroni/etcd/k)
    - [Required PostgreSQL Users](#PostgreSQLHASetupwithPatroni/etcd/k)
- [2\. Environment](#PostgreSQLHASetupwithPatroni/etcd/k)
- [3\. ETCD - Cluster](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Step 1. Install etcd on each node](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Step 2. Create user and folder for the service](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Step 3. Create file /etc/systemd/system/etcd.service](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Start and enable service on each node](#PostgreSQLHASetupwithPatroni/etcd/k)
- [4\. Postgresql 14](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Installation](#PostgreSQLHASetupwithPatroni/etcd/k)
- [5\. Patroni](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Dependency installation](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Create the service file (/etc/systemd/system/patroni.service)](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Create file /etc/patroni.yml](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Start and enable the service on the 2 nodes](#PostgreSQLHASetupwithPatroni/etcd/k)
- [6\. Keepalived](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Installation](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Create file /etc/keepalived/keepalived.conf](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Create the IP bounce script /usr/local/bin/check_patroni.sh](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Start and enable the service on the 2 nodes:](#PostgreSQLHASetupwithPatroni/etcd/k)
- [7\. Useful commands](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Check patroni cluster status](#PostgreSQLHASetupwithPatroni/etcd/k)
  - [Check if the VIP is correctly attached](#PostgreSQLHASetupwithPatroni/etcd/k)

## 1. Networking pre-requisites

### PostgreSQL Replication and HA - Firewall and User Requirements

#### Firewall Ports

Ensure the following ports are open between the nodes (psql-01, 02, and 03):

| **Port** | **Protocol** | **Source → Destination** | **Purpose** |
| --- | --- | --- | --- |
| 5432 | TCP | All nodes | PostgreSQL replication and client conn. |
| 2379 | TCP | All nodes | ETCD client communication |
| 2380 | TCP | All nodes | ETCD peer-to-peer communication |
| 8008 | TCP | localhost only | Patroni REST API (internal checks) |
| 5000 | UDP | All nodes | VRRP traffic (Keepalived) |

#### Required PostgreSQL Users

- **Replication User**
  - **Username:** replicator
  - **Purpose:** Used by Patroni to set up streaming replication between nodes.

**Commands to create it:**

CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';

- **Monitoring / Admin User (optional, but recommended)**
  - **Username:** monitoring
  - **Purpose:** Allows read-only access to PostgreSQL statistics and health (e.g., for manual checks).

**Commands to create it:**

CREATE ROLE monitoring WITH LOGIN PASSWORD 'StrongPassword' NOSUPERUSER;

- **Superuser for Patroni**
  - This is typically configured in the patroni.yml under the superuser section and is used by Patroni for cluster management.

Example in patroni.yml:

postgresql:

&nbsp; superuser:

&nbsp;   username: postgres

&nbsp;   password: postgres_password

&nbsp; replication:

&nbsp;   username: replicator

&nbsp;   password: replicator_password

## 2\. Environment

| **Nó** | **IP** | **Roles** | **Operating System** |
| --- | --- | --- | --- |
| psql-01 | 10.20.20.180 | Etcd + patroni + keepalived | Oracle Linux 8.10 |
| psql-02 | 10.20.20.181 | Etcd + patroni + keepalived | Oracle Linux 8.10 |
| psql-03 | 10.20.20.182 | Etcd | Oracle Linux 8.10 |
| VIP (Keepalived) | 10.20.20.200 |     |     |

## 3\. ETCD - Cluster

### Step 1. Install etcd on each node

wget <https://github.com/etcd-io/etcd/releases/download/v3.5.9/etcd-v3.5.9-linux-amd64.tar.gz>

tar xvf etcd-v3.5.9-linux-amd64.tar.gz

sudo mv etcd-v3.5.9-linux-amd64/etcd\* /usr/local/bin/

### Step 2. Create user and folder for the service

sudo useradd -r -s /sbin/nologin etcd  
sudo mkdir -p /var/lib/etcd  
sudo chown etcd:etcd /var/lib/etcd

### Step 3. Create file /etc/systemd/system/etcd.service

Example for node 1 (psql-01):

sudo tee /etc/systemd/system/etcd.service > /dev/null <<EOF

\[Unit\]

Description=etcd key-value store

Documentation=<https://github.com/etcd-io/etcd>

After=network.target

\[Service\]

User=etcd

ExecStart=/usr/local/bin/etcd \\\\

&nbsp; --name psql-01 \\\\

&nbsp; --data-dir /var/lib/etcd \\\\

&nbsp; --listen-peer-urls <http://10.20.20.180:2380> \\\\

&nbsp; --listen-client-urls <http://10.20.20.180:2379,http://127.0.0.1:2379> \\\\

&nbsp; --initial-advertise-peer-urls <http://10.20.20.180:2380> \\\\

&nbsp; --advertise-client-urls <http://10.20.20.180:2379> \\\\

&nbsp; --initial-cluster psql-01=<http://10.20.20.180:2380,psql-02=http://10.20.20.181:2380,psql-03=http://10.20.20.182:2380> \\\\

&nbsp; --initial-cluster-state new \\\\

&nbsp; --initial-cluster-token etcd-cluster-01

Restart=on-failure

LimitNOFILE=65536

\[Install\]

WantedBy=multi-user.target

EOF

Example for node 2 (psql-02), replace:

- \--name psql-02
- IP 10.20.20.181 in the URLs

sudo tee /etc/systemd/system/etcd.service > /dev/null <<EOF

\[Unit\]

Description=etcd key-value store

Documentation=<https://github.com/etcd-io/etcd>

After=network.target

\[Service\]

User=etcd

ExecStart=/usr/local/bin/etcd \\\\

&nbsp; --name psql-02 \\\\

&nbsp; --data-dir /var/lib/etcd \\\\

&nbsp; --listen-peer-urls <http://10.20.20.181:2380> \\\\

&nbsp; --listen-client-urls <http://10.20.20.181:2379,http://127.0.0.1:2379> \\\\

&nbsp; --initial-advertise-peer-urls <http://10.20.20.181:2380> \\\\

&nbsp; --advertise-client-urls <http://10.20.20.181:2379> \\\\

&nbsp; --initial-cluster psql-01=<http://10.20.20.180:2380,psql-02=http://10.20.20.181:2380,psql-03=http://10.20.20.182:2380> \\\\

&nbsp; --initial-cluster-state new \\\\

&nbsp; --initial-cluster-token etcd-cluster-01

Restart=on-failure

LimitNOFILE=65536

\[Install\]

WantedBy=multi-user.target

EOF

Example for node 3 (psql-03), replace:

- \--name psql-03
- IP 10.20.20.182

sudo tee /etc/systemd/system/etcd.service > /dev/null <<EOF

\[Unit\]

Description=etcd key-value store

Documentation=<https://github.com/etcd-io/etcd>

After=network.target

\[Service\]

User=etcd

ExecStart=/usr/local/bin/etcd \\\\

&nbsp; --name psql-03 \\\\

&nbsp; --data-dir /var/lib/etcd \\\\

&nbsp; --listen-peer-urls <http://10.20.20.182:2380> \\\\

&nbsp; --listen-client-urls <http://10.20.20.182:2379,http://127.0.0.1:2379> \\\\

&nbsp; --initial-advertise-peer-urls <http://10.20.20.182:2380> \\\\

&nbsp; --advertise-client-urls <http://10.20.20.182:2379> \\\\

&nbsp; --initial-cluster psql-01=<http://10.20.20.180:2380,psql-02=http://10.20.20.181:2380,psql-03=http://10.20.20.182:2380> \\\\

&nbsp; --initial-cluster-state new \\\\

&nbsp; --initial-cluster-token etcd-cluster-01

Restart=on-failure

LimitNOFILE=65536

\[Install\]

WantedBy=multi-user.target

EOF

### Start and enable service on each node

sudo systemctl daemon-reload

sudo systemctl enable etcd

sudo systemctl start etcd

sudo systemctl status etcd

## 4\. Postgresql 14

### Installation

sudo dnf -qy module disable postgresql

sudo dnf install -y postgresql14 postgresql14-server postgresql14-contrib postgresql14-libs postgresql14-devel

## 5\. Patroni

### Dependency installation

sudo pip3 install patroni\[etcd\] python-etcd psycopg2-binary

### Create the service file (/etc/systemd/system/patroni.service)

On node 1:

\[Unit\]

Description=Runners to orchestrate a PostgreSQL cluster

After=network.target

\[Service\]

Type=simple

User=postgres

ExecStart=/usr/local/bin/patroni /etc/patroni.yml

Restart=on-failure

RestartSec=5

\[Install\]

WantedBy=multi-user.target

On node 2:

\[Unit\]

Description=Runners to orchestrate a PostgreSQL cluster

After=network.target

\[Service\]

Type=simple

User=postgres

ExecStart=/usr/local/bin/patroni /etc/patroni.yml

Restart=on-failure

RestartSec=5

\[Install\]

WantedBy=multi-user.target

### Create file /etc/patroni.yml

Node 1: psql-01

scope: postgres

namespace: /db/

name: psql-01

restapi:

&nbsp; listen: 0.0.0.0:8008

&nbsp; connect_address: 10.20.20.180:8008

etcd3:

&nbsp; name: etcd

&nbsp; hosts:

&nbsp;   - 10.20.20.180:2379

&nbsp;   - 10.20.20.181:2379

&nbsp;   - 10.20.20.182:2379

bootstrap:

&nbsp; dcs:

&nbsp;   ttl: 30

&nbsp;   loop_wait: 10

&nbsp;   retry_timeout: 10

&nbsp;   maximum_lag_on_failover: 1048576

&nbsp;   postgresql:

&nbsp;     use_pg_rewind: true

&nbsp;     parameters:

&nbsp;       max_connections: 100

&nbsp;       max_locks_per_transaction: 64

&nbsp;       max_worker_processes: 8

&nbsp;       wal_level: replica

&nbsp;       hot_standby: "on"

&nbsp;       wal_log_hints: "on"

&nbsp;       max_wal_senders: 10

&nbsp;       wal_keep_size: 64

&nbsp;       archive_mode: "off"

&nbsp;       archive_command: ''

&nbsp; initdb:

&nbsp; - encoding: UTF8

&nbsp; - locale: en_US.UTF-8

postgresql:

&nbsp; listen: 0.0.0.0:5432

&nbsp; connect_address: 10.20.20.180:5432

&nbsp; data_dir: /var/lib/pgsql/14/data

&nbsp; bin_dir: /usr/pgsql-14/bin

&nbsp; authentication:

&nbsp;   replication:

&nbsp;     username: replicator

&nbsp;     password: replicator_password

&nbsp;   superuser:

&nbsp;     username: postgres

&nbsp;     password: postgres_password

&nbsp; parameters:

&nbsp;   unix_socket_directories: '/var/run/postgresql'

tags:

&nbsp; nofailover: false

&nbsp; noloadbalance: false

&nbsp; clonefrom: false

&nbsp; nosync: false

Node 2: psql-02

scope: postgres

namespace: /db/

name: psql-02

restapi:

&nbsp; listen: 10.20.20.181:8008

&nbsp; connect_address: 10.20.20.181:8008

etcd3:

&nbsp; name: etcd

&nbsp; hosts:

&nbsp;   - 10.20.20.180:2379

&nbsp;   - 10.20.20.181:2379

&nbsp;   - 10.20.20.182:2379

bootstrap:

&nbsp; dcs:

&nbsp;   ttl: 30

&nbsp;   loop_wait: 10

&nbsp;   retry_timeout: 10

&nbsp;   maximum_lag_on_failover: 1048576

&nbsp;   postgresql:

&nbsp;     use_pg_rewind: true

&nbsp;     parameters:

&nbsp;       max_connections: 100

&nbsp;       max_locks_per_transaction: 64

&nbsp;       max_worker_processes: 8

&nbsp;       wal_level: replica

&nbsp;       hot_standby: "on"

&nbsp;       wal_log_hints: "on"

&nbsp;       max_wal_senders: 10

&nbsp;       wal_keep_size: 64

&nbsp;       archive_mode: "off"

&nbsp;       archive_command: ''

&nbsp; initdb:

&nbsp; - encoding: UTF8

&nbsp; - locale: en_US.UTF-8

postgresql:

&nbsp; listen: 0.0.0.0:5432

&nbsp; connect_address: 10.20.20.181:5432

&nbsp; data_dir: /var/lib/pgsql/14/data

&nbsp; bin_dir: /usr/pgsql-14/bin

&nbsp; authentication:

&nbsp;   replication:

&nbsp;     username: replicator

&nbsp;     password: replicator_password

&nbsp;   superuser:

&nbsp;     username: postgres

&nbsp;     password: postgres_password

&nbsp; parameters:

&nbsp;   unix_socket_directories: '/var/run/postgresql'

tags:

&nbsp; nofailover: false

&nbsp; noloadbalance: false

&nbsp; clonefrom: false

nosync: false

### Start and enable the service on the 2 nodes

/usr/local/bin/patroni /etc/patroni.yml

sudo systemctl start patroni

sudo systemctl enable patroni

## 6\. Keepalived

### Installation

sudo dnf install -y keepalived

### Create file /etc/keepalived/keepalived.conf

On node 1:

vrrp_script chk_patroni {

&nbsp;   script "/usr/local/bin/check_patroni.sh"

&nbsp;   interval 5

&nbsp;   timeout 3

&nbsp;   fall 2

&nbsp;   rise 1

}

vrrp_instance VI_PG {

&nbsp;   state BACKUP

&nbsp;   interface ens34

&nbsp;   virtual_router_id 51

&nbsp;   priority 100

&nbsp;   advert_int 1

&nbsp;   authentication {

&nbsp;       auth_type PASS

&nbsp;       auth_pass 12345678

&nbsp;   }

&nbsp;   virtual_ipaddress {

&nbsp;       10.20.20.200

&nbsp;   }

&nbsp;   track_script {

&nbsp;       chk_patroni

&nbsp;   }

}

On node 2:

vrrp_script chk_patroni {

&nbsp;   script "/usr/local/bin/check_patroni.sh"

&nbsp;   interval 5

&nbsp;   timeout 3

&nbsp;   fall 2

&nbsp;   rise 1

}

script_user keepalived_script

enable_script_security

vrrp_instance VI_PG {

&nbsp;   state BACKUP

&nbsp;   interface ens34

&nbsp;   virtual_router_id 51

&nbsp;   priority 90

&nbsp;   advert_int 1

&nbsp;   authentication {

&nbsp;       auth_type PASS

&nbsp;       auth_pass 12345678

&nbsp;   }

&nbsp;   virtual_ipaddress {

&nbsp;       10.20.20.200

&nbsp;   }

&nbsp;   track_script {

&nbsp;       chk_patroni

&nbsp;   }

}

### Create the IP bounce script /usr/local/bin/check_patroni.sh

On node 1:

# !/bin/bash

\# Confirma se este nó é o líder Patroni

curl -sf <http://127.0.0.1:8008/master> > /dev/null

exit \$?

On node 2:

# !/bin/bash

\# Verifica se este nó é o líder Patroni

curl -sf <http://10.20.20.181:8008/master> > /dev/null

exit \$?

### Start and enable the service on the 2 nodes

sudo systemctl start keepalived

sudo systemctl enable keepalived

## 7\. Useful commands

### Check patroni cluster status

patronictl -c /etc/patroni.yml list

\+ Cluster: postgres (7512856692302928302) -+-----------+----+-----------+-----------------+------------------------+

| Member          | Host         | Role    | State     | TL | Lag in MB | Pending restart | Pending restart reason |

+-----------------+--------------+---------+-----------+----+-----------+-----------------+------------------------+

| psql-01 | 10.20.20.180 | Leader  | running   | 24 |           | \*               | max_wal_senders: 10->5 |

| psql-02 | 10.20.20.181 | Replica | streaming | 24 |         0 | \*               | max_wal_senders: 10->5 |

+-----------------+--------------+---------+-----------+----+-----------+-----------------+------------------------+

### Check if the VIP is correctly attached

ip a | grep 10.20.20.200

&nbsp;   inet 10.20.20.200/32 scope global ens34  

&nbsp;   inet 10.20.20.200/24 scope global secondary ens34
  - [Check if the VIP is correctly attached](#PostgreSQLHASetupwithPatroni/etcd/k)

## 1. Networking pre-requisites

### PostgreSQL Replication and HA - Firewall and User Requirements

#### Firewall Ports

Ensure the following ports are open between the nodes (psql-01, 02, and 03):

| **Port** | **Protocol** | **Source → Destination** | **Purpose** |
| --- | --- | --- | --- |
| 5432 | TCP | All nodes | PostgreSQL replication and client conn. |
| 2379 | TCP | All nodes | ETCD client communication |
| 2380 | TCP | All nodes | ETCD peer-to-peer communication |
| 8008 | TCP | localhost only | Patroni REST API (internal checks) |
| 5000 | UDP | All nodes | VRRP traffic (Keepalived) |

#### Required PostgreSQL Users

- **Replication User**
  - **Username:** replicator
  - **Purpose:** Used by Patroni to set up streaming replication between nodes.

**Commands to create it:**

CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';

- **Monitoring / Admin User (optional, but recommended)**
  - **Username:** monitoring
  - **Purpose:** Allows read-only access to PostgreSQL statistics and health (e.g., for manual checks).

**Commands to create it:**

CREATE ROLE monitoring WITH LOGIN PASSWORD 'StrongPassword' NOSUPERUSER;

- **Superuser for Patroni**
  - This is typically configured in the patroni.yml under the superuser section and is used by Patroni for cluster management.

Example in patroni.yml:

postgresql:

&nbsp; superuser:

&nbsp;   username: postgres

&nbsp;   password: postgres_password

&nbsp; replication:

&nbsp;   username: replicator

&nbsp;   password: replicator_password

## 2\. Environment

| **Nó** | **IP** | **Roles** | **Operating System** |
| --- | --- | --- | --- |
| psql-01 | 10.20.20.180 | Etcd + patroni + keepalived | Oracle Linux 8.10 |
| psql-02 | 10.20.20.181 | Etcd + patroni + keepalived | Oracle Linux 8.10 |
| psql-03 | 10.20.20.182 | Etcd | Oracle Linux 8.10 |
| VIP (Keepalived) | 10.20.20.200 |     |     |

## 3\. ETCD - Cluster

### Step 1. Install etcd on each node

wget <https://github.com/etcd-io/etcd/releases/download/v3.5.9/etcd-v3.5.9-linux-amd64.tar.gz>

tar xvf etcd-v3.5.9-linux-amd64.tar.gz

sudo mv etcd-v3.5.9-linux-amd64/etcd\* /usr/local/bin/

### Step 2. Create user and folder for the service

sudo useradd -r -s /sbin/nologin etcd  
sudo mkdir -p /var/lib/etcd  
sudo chown etcd:etcd /var/lib/etcd

### Step 3. Create file /etc/systemd/system/etcd.service

Example for node 1 (psql-01):

sudo tee /etc/systemd/system/etcd.service > /dev/null <<EOF

\[Unit\]

Description=etcd key-value store

Documentation=<https://github.com/etcd-io/etcd>

After=network.target

\[Service\]

User=etcd

ExecStart=/usr/local/bin/etcd \\\\

&nbsp; --name psql-01 \\\\

&nbsp; --data-dir /var/lib/etcd \\\\

&nbsp; --listen-peer-urls <http://10.20.20.180:2380> \\\\

&nbsp; --listen-client-urls <http://10.20.20.180:2379,http://127.0.0.1:2379> \\\\

&nbsp; --initial-advertise-peer-urls <http://10.20.20.180:2380> \\\\

&nbsp; --advertise-client-urls <http://10.20.20.180:2379> \\\\

&nbsp; --initial-cluster psql-01=<http://10.20.20.180:2380,psql-02=http://10.20.20.181:2380,psql-03=http://10.20.20.182:2380> \\\\

&nbsp; --initial-cluster-state new \\\\

&nbsp; --initial-cluster-token etcd-cluster-01

Restart=on-failure

LimitNOFILE=65536

\[Install\]

WantedBy=multi-user.target

EOF

Example for node 2 (psql-02), replace:

- \--name psql-02
- IP 10.20.20.181 in the URLs

sudo tee /etc/systemd/system/etcd.service > /dev/null <<EOF

\[Unit\]

Description=etcd key-value store

Documentation=<https://github.com/etcd-io/etcd>

After=network.target

\[Service\]

User=etcd

ExecStart=/usr/local/bin/etcd \\\\

&nbsp; --name psql-02 \\\\

&nbsp; --data-dir /var/lib/etcd \\\\

&nbsp; --listen-peer-urls <http://10.20.20.181:2380> \\\\

&nbsp; --listen-client-urls <http://10.20.20.181:2379,http://127.0.0.1:2379> \\\\

&nbsp; --initial-advertise-peer-urls <http://10.20.20.181:2380> \\\\

&nbsp; --advertise-client-urls <http://10.20.20.181:2379> \\\\

&nbsp; --initial-cluster psql-01=<http://10.20.20.180:2380,psql-02=http://10.20.20.181:2380,psql-03=http://10.20.20.182:2380> \\\\

&nbsp; --initial-cluster-state new \\\\

&nbsp; --initial-cluster-token etcd-cluster-01

Restart=on-failure

LimitNOFILE=65536

\[Install\]

WantedBy=multi-user.target

EOF

Example for node 3 (psql-03), replace:

- \--name psql-03
- IP 10.20.20.182

sudo tee /etc/systemd/system/etcd.service > /dev/null <<EOF

\[Unit\]

Description=etcd key-value store

Documentation=<https://github.com/etcd-io/etcd>

After=network.target

\[Service\]

User=etcd

ExecStart=/usr/local/bin/etcd \\\\

&nbsp; --name psql-03 \\\\

&nbsp; --data-dir /var/lib/etcd \\\\

&nbsp; --listen-peer-urls <http://10.20.20.182:2380> \\\\

&nbsp; --listen-client-urls <http://10.20.20.182:2379,http://127.0.0.1:2379> \\\\

&nbsp; --initial-advertise-peer-urls <http://10.20.20.182:2380> \\\\

&nbsp; --advertise-client-urls <http://10.20.20.182:2379> \\\\

&nbsp; --initial-cluster psql-01=<http://10.20.20.180:2380,psql-02=http://10.20.20.181:2380,psql-03=http://10.20.20.182:2380> \\\\

&nbsp; --initial-cluster-state new \\\\

&nbsp; --initial-cluster-token etcd-cluster-01

Restart=on-failure

LimitNOFILE=65536

\[Install\]

WantedBy=multi-user.target

EOF

### Start and enable service on each node

sudo systemctl daemon-reload

sudo systemctl enable etcd

sudo systemctl start etcd

sudo systemctl status etcd

## 4\. Postgresql 14

### Installation

sudo dnf -qy module disable postgresql

sudo dnf install -y postgresql14 postgresql14-server postgresql14-contrib postgresql14-libs postgresql14-devel

## 5\. Patroni

### Dependency installation

sudo pip3 install patroni\[etcd\] python-etcd psycopg2-binary

### Create the service file (/etc/systemd/system/patroni.service)

On node 1:

\[Unit\]

Description=Runners to orchestrate a PostgreSQL cluster

After=network.target

\[Service\]

Type=simple

User=postgres

ExecStart=/usr/local/bin/patroni /etc/patroni.yml

Restart=on-failure

RestartSec=5

\[Install\]

WantedBy=multi-user.target

On node 2:

\[Unit\]

Description=Runners to orchestrate a PostgreSQL cluster

After=network.target

\[Service\]

Type=simple

User=postgres

ExecStart=/usr/local/bin/patroni /etc/patroni.yml

Restart=on-failure

RestartSec=5

\[Install\]

WantedBy=multi-user.target

### Create file /etc/patroni.yml

Node 1: psql-01

scope: postgres

namespace: /db/

name: psql-01

restapi:

&nbsp; listen: 0.0.0.0:8008

&nbsp; connect_address: 10.20.20.180:8008

etcd3:

&nbsp; name: etcd

&nbsp; hosts:

&nbsp;   - 10.20.20.180:2379

&nbsp;   - 10.20.20.181:2379

&nbsp;   - 10.20.20.182:2379

bootstrap:

&nbsp; dcs:

&nbsp;   ttl: 30

&nbsp;   loop_wait: 10

&nbsp;   retry_timeout: 10

&nbsp;   maximum_lag_on_failover: 1048576

&nbsp;   postgresql:

&nbsp;     use_pg_rewind: true

&nbsp;     parameters:

&nbsp;       max_connections: 100

&nbsp;       max_locks_per_transaction: 64

&nbsp;       max_worker_processes: 8

&nbsp;       wal_level: replica

&nbsp;       hot_standby: "on"

&nbsp;       wal_log_hints: "on"

&nbsp;       max_wal_senders: 10

&nbsp;       wal_keep_size: 64

&nbsp;       archive_mode: "off"

&nbsp;       archive_command: ''

&nbsp; initdb:

&nbsp; - encoding: UTF8

&nbsp; - locale: en_US.UTF-8

postgresql:

&nbsp; listen: 0.0.0.0:5432

&nbsp; connect_address: 10.20.20.180:5432

&nbsp; data_dir: /var/lib/pgsql/14/data

&nbsp; bin_dir: /usr/pgsql-14/bin

&nbsp; authentication:

&nbsp;   replication:

&nbsp;     username: replicator

&nbsp;     password: replicator_password

&nbsp;   superuser:

&nbsp;     username: postgres

&nbsp;     password: postgres_password

&nbsp; parameters:

&nbsp;   unix_socket_directories: '/var/run/postgresql'

tags:

&nbsp; nofailover: false

&nbsp; noloadbalance: false

&nbsp; clonefrom: false

&nbsp; nosync: false

Node 2: psql-02

scope: postgres

namespace: /db/

name: psql-02

restapi:

&nbsp; listen: 10.20.20.181:8008

&nbsp; connect_address: 10.20.20.181:8008

etcd3:

&nbsp; name: etcd

&nbsp; hosts:

&nbsp;   - 10.20.20.180:2379

&nbsp;   - 10.20.20.181:2379

&nbsp;   - 10.20.20.182:2379

bootstrap:

&nbsp; dcs:

&nbsp;   ttl: 30

&nbsp;   loop_wait: 10

&nbsp;   retry_timeout: 10

&nbsp;   maximum_lag_on_failover: 1048576

&nbsp;   postgresql:

&nbsp;     use_pg_rewind: true

&nbsp;     parameters:

&nbsp;       max_connections: 100

&nbsp;       max_locks_per_transaction: 64

&nbsp;       max_worker_processes: 8

&nbsp;       wal_level: replica

&nbsp;       hot_standby: "on"

&nbsp;       wal_log_hints: "on"

&nbsp;       max_wal_senders: 10

&nbsp;       wal_keep_size: 64

&nbsp;       archive_mode: "off"

&nbsp;       archive_command: ''

&nbsp; initdb:

&nbsp; - encoding: UTF8

&nbsp; - locale: en_US.UTF-8

postgresql:

&nbsp; listen: 0.0.0.0:5432

&nbsp; connect_address: 10.20.20.181:5432

&nbsp; data_dir: /var/lib/pgsql/14/data

&nbsp; bin_dir: /usr/pgsql-14/bin

&nbsp; authentication:

&nbsp;   replication:

&nbsp;     username: replicator

&nbsp;     password: replicator_password

&nbsp;   superuser:

&nbsp;     username: postgres

&nbsp;     password: postgres_password

&nbsp; parameters:

&nbsp;   unix_socket_directories: '/var/run/postgresql'

tags:

&nbsp; nofailover: false

&nbsp; noloadbalance: false

&nbsp; clonefrom: false

nosync: false

### Start and enable the service on the 2 nodes

/usr/local/bin/patroni /etc/patroni.yml

sudo systemctl start patroni

sudo systemctl enable patroni

## 6\. Keepalived

### Installation

sudo dnf install -y keepalived

### Create file /etc/keepalived/keepalived.conf

On node 1:

vrrp_script chk_patroni {

&nbsp;   script "/usr/local/bin/check_patroni.sh"

&nbsp;   interval 5

&nbsp;   timeout 3

&nbsp;   fall 2

&nbsp;   rise 1

}

vrrp_instance VI_PG {

&nbsp;   state BACKUP

&nbsp;   interface ens34

&nbsp;   virtual_router_id 51

&nbsp;   priority 100

&nbsp;   advert_int 1

&nbsp;   authentication {

&nbsp;       auth_type PASS

&nbsp;       auth_pass 12345678

&nbsp;   }

&nbsp;   virtual_ipaddress {

&nbsp;       10.20.20.200

&nbsp;   }

&nbsp;   track_script {

&nbsp;       chk_patroni

&nbsp;   }

}

On node 2:

vrrp_script chk_patroni {

&nbsp;   script "/usr/local/bin/check_patroni.sh"

&nbsp;   interval 5

&nbsp;   timeout 3

&nbsp;   fall 2

&nbsp;   rise 1

}

script_user keepalived_script

enable_script_security

vrrp_instance VI_PG {

&nbsp;   state BACKUP

&nbsp;   interface ens34

&nbsp;   virtual_router_id 51

&nbsp;   priority 90

&nbsp;   advert_int 1

&nbsp;   authentication {

&nbsp;       auth_type PASS

&nbsp;       auth_pass 12345678

&nbsp;   }

&nbsp;   virtual_ipaddress {

&nbsp;       10.20.20.200

&nbsp;   }

&nbsp;   track_script {

&nbsp;       chk_patroni

&nbsp;   }

}

### Create the IP bounce script /usr/local/bin/check_patroni.sh

On node 1:

# !/bin/bash

\# Confirma se este nó é o líder Patroni

curl -sf <http://127.0.0.1:8008/master> > /dev/null

exit \$?

On node 2:

# !/bin/bash

\# Verifica se este nó é o líder Patroni

curl -sf <http://10.20.20.181:8008/master> > /dev/null

exit \$?

### Start and enable the service on the 2 nodes

sudo systemctl start keepalived

sudo systemctl enable keepalived

## 7\. Useful commands

### Check patroni cluster status

patronictl -c /etc/patroni.yml list

\+ Cluster: postgres (7512856692302928302) -+-----------+----+-----------+-----------------+------------------------+

| Member          | Host         | Role    | State     | TL | Lag in MB | Pending restart | Pending restart reason |

+-----------------+--------------+---------+-----------+----+-----------+-----------------+------------------------+

| psql-01 | 10.20.20.180 | Leader  | running   | 24 |           | \*               | max_wal_senders: 10->5 |

| psql-02 | 10.20.20.181 | Replica | streaming | 24 |         0 | \*               | max_wal_senders: 10->5 |

+-----------------+--------------+---------+-----------+----+-----------+-----------------+------------------------+

### Check if the VIP is correctly attached

ip a | grep 10.20.20.200

&nbsp;   inet 10.20.20.200/32 scope global ens34  

&nbsp;   inet 10.20.20.200/24 scope global secondary ens34
