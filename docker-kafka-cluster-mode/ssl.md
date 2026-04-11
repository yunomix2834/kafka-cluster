Password cho TLS store:

```bash id="knuh2e"
changeit
```

---

# PHASE 1 — Gen CA và 3 broker cert trên bastion

Tôi làm theo kiểu:

* gen **1 CA**
* gen **3 private key + CSR + signed cert**
* đóng gói từng broker thành **PKCS#12 (`.p12`)**
* sau đó copy `.p12` + `ca.crt` sang từng server
* trên từng server mới convert sang `JKS`

Cách này giúp bastion chỉ cần `openssl`, không cần `keytool`.

## 1.1. Tạo thư mục trên bastion

```
BASE=./kafka-ca
PASS=changeit

mkdir -p "$BASE"/ca
mkdir -p "$BASE"/brokers/kafka-0
mkdir -p "$BASE"/brokers/kafka-1
mkdir -p "$BASE"/brokers/kafka-2

chmod 700 "$BASE" "$BASE/ca" "$BASE"/brokers "$BASE"/brokers/*
```

## 1.2. Tạo CA

```
openssl genrsa -out "$BASE/ca/ca.key" 4096

openssl req -x509 -new -nodes \
  -key "$BASE/ca/ca.key" \
  -sha256 \
  -days 3650 \
  -out "$BASE/ca/ca.crt" \
  -subj "/C=VN/ST=HN/L=HN/O=CMC/OU=Kafka/CN=Kafka-CA"
```

## 1.3. Tạo script gen cert cho broker

```
cat > "$BASE/gen-broker-cert.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE=./kafka-ca
PASS=changeit

NAME="$1"
IP="$2"

OUT="$BASE/brokers/$NAME"
mkdir -p "$OUT"

cat > "$OUT/$NAME.cnf" <<EOCONF
[ req ]
prompt = no
default_bits = 2048
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ dn ]
C = VN
ST = HN
L = HN
O = CMC
OU = Kafka
CN = ${IP}

[ req_ext ]
subjectAltName = @alt_names
extendedKeyUsage = serverAuth,clientAuth

[ alt_names ]
IP.1 = ${IP}
DNS.1 = ${NAME}
EOCONF

openssl genrsa -out "$OUT/$NAME.key" 2048

openssl req -new \
  -key "$OUT/$NAME.key" \
  -out "$OUT/$NAME.csr" \
  -config "$OUT/$NAME.cnf"

openssl x509 -req \
  -in "$OUT/$NAME.csr" \
  -CA "$BASE/ca/ca.crt" \
  -CAkey "$BASE/ca/ca.key" \
  -CAcreateserial \
  -out "$OUT/$NAME.crt" \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile "$OUT/$NAME.cnf"

openssl pkcs12 -export \
  -name "$NAME" \
  -inkey "$OUT/$NAME.key" \
  -in "$OUT/$NAME.crt" \
  -certfile "$BASE/ca/ca.crt" \
  -out "$OUT/$NAME.p12" \
  -passout pass:"$PASS"
EOF

chmod +x "$BASE/gen-broker-cert.sh"
```

## 1.4. Gen cho cả 3 broker

```
"$BASE/gen-broker-cert.sh" kafka-0 10.60.68.211
"$BASE/gen-broker-cert.sh" kafka-1 10.60.68.242
"$BASE/gen-broker-cert.sh" kafka-2 10.60.68.32
```

## 1.5. Verify nhanh trên bastion

```
openssl x509 -in "$BASE/brokers/kafka-0/kafka-0.crt" -noout -subject -issuer
openssl x509 -in "$BASE/brokers/kafka-1/kafka-1.crt" -noout -subject -issuer
openssl x509 -in "$BASE/brokers/kafka-2/kafka-2.crt" -noout -subject -issuer
```

```bash id="s48g0d"
openssl x509 -in "$BASE/brokers/kafka-1/kafka-1.crt" -noout -text | egrep -A2 'Subject Alternative Name|Extended Key Usage'
```

---

# PHASE 2 — Chép cert sang cả 3 server

## 2.1. Tạo thư mục đích trên từng server

Từ bastion chạy:

```
for HOST in 10.60.68.211 10.60.68.242 10.60.68.32; do
  ssh root@"$HOST" 'mkdir -p /etc/kafka/certs && chmod 700 /etc/kafka/certs'
done
```

## 2.2. Copy CA cert và broker bundle

```
scp "$BASE/ca/ca.crt" root@10.60.68.211:/etc/kafka/certs/ca.crt
scp "$BASE/ca/ca.crt" root@10.60.68.242:/etc/kafka/certs/ca.crt
scp "$BASE/ca/ca.crt" root@10.60.68.32:/etc/kafka/certs/ca.crt

scp "$BASE/brokers/kafka-0/kafka-0.p12" root@10.60.68.211:/etc/kafka/certs/kafka.p12
scp "$BASE/brokers/kafka-1/kafka-1.p12" root@10.60.68.242:/etc/kafka/certs/kafka.p12
scp "$BASE/brokers/kafka-2/kafka-2.p12" root@10.60.68.32:/etc/kafka/certs/kafka.p12
```

## 2.3. Cấp quyền trên cả 3 con server
```bash
chown -R 1001:1001 /etc/kafka/certs
chmod 700 /etc/kafka/certs
chmod 600 /etc/kafka/certs/kafka.keystore.jks
chmod 600 /etc/kafka/certs/kafka.truststore.jks
chmod 644 /etc/kafka/certs/ca.crt
```

---

# PHASE 3 — Trên từng server, convert sang JKS

## 3.1. Trên server `10.60.68.211` (`kafka-0`)

```
mkdir -p /etc/kafka/certs
chmod 700 /etc/kafka/certs

[ -d /etc/kafka/certs/kafka.keystore.jks ] && mv /etc/kafka/certs/kafka.keystore.jks /etc/kafka/certs/kafka.keystore.jks.bak.$(date +%F-%H%M%S)
[ -d /etc/kafka/certs/kafka.truststore.jks ] && mv /etc/kafka/certs/kafka.truststore.jks /etc/kafka/certs/kafka.truststore.jks.bak.$(date +%F-%H%M%S)

docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -importkeystore \
  -srckeystore /work/certs/kafka.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass changeit \
  -srcalias kafka-0 \
  -destkeystore /work/certs/kafka.keystore.jks \
  -deststoretype JKS \
  -deststorepass changeit \
  -destkeypass changeit \
  -destalias kafka-0 \
  -noprompt

docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -importcert \
  -alias CARoot \
  -keystore /work/certs/kafka.truststore.jks \
  -storetype JKS \
  -storepass changeit \
  -file /work/certs/ca.crt \
  -noprompt

chmod 600 /etc/kafka/certs/*.jks
chmod 600 /etc/kafka/certs/*.p12
chmod 644 /etc/kafka/certs/ca.crt

docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -list \
  -keystore /work/certs/kafka.keystore.jks \
  -storepass changeit
```

## 3.2. Trên server `10.60.68.242` (`kafka-1`)

```
mkdir -p /etc/kafka/certs
chmod 700 /etc/kafka/certs

[ -d /etc/kafka/certs/kafka.keystore.jks ] && mv /etc/kafka/certs/kafka.keystore.jks /etc/kafka/certs/kafka.keystore.jks.bak.$(date +%F-%H%M%S)
[ -d /etc/kafka/certs/kafka.truststore.jks ] && mv /etc/kafka/certs/kafka.truststore.jks /etc/kafka/certs/kafka.truststore.jks.bak.$(date +%F-%H%M%S)

docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -importkeystore \
  -srckeystore /work/certs/kafka.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass changeit \
  -srcalias kafka-1 \
  -destkeystore /work/certs/kafka.keystore.jks \
  -deststoretype JKS \
  -deststorepass changeit \
  -destkeypass changeit \
  -destalias kafka-1 \
  -noprompt

docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -importcert \
  -alias CARoot \
  -keystore /work/certs/kafka.truststore.jks \
  -storetype JKS \
  -storepass changeit \
  -file /work/certs/ca.crt \
  -noprompt

chmod 600 /etc/kafka/certs/*.jks
chmod 600 /etc/kafka/certs/*.p12
chmod 644 /etc/kafka/certs/ca.crt

docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -list \
  -keystore /work/certs/kafka.keystore.jks \
  -storepass changeit
```

## 3.3. Trên server `10.60.68.32` (`kafka-2`)

```
mkdir -p /etc/kafka/certs
chmod 700 /etc/kafka/certs

[ -d /etc/kafka/certs/kafka.keystore.jks ] && mv /etc/kafka/certs/kafka.keystore.jks /etc/kafka/certs/kafka.keystore.jks.bak.$(date +%F-%H%M%S)
[ -d /etc/kafka/certs/kafka.truststore.jks ] && mv /etc/kafka/certs/kafka.truststore.jks /etc/kafka/certs/kafka.truststore.jks.bak.$(date +%F-%H%M%S)

docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -importkeystore \
  -srckeystore /work/certs/kafka.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass changeit \
  -srcalias kafka-2 \
  -destkeystore /work/certs/kafka.keystore.jks \
  -deststoretype JKS \
  -deststorepass changeit \
  -destkeypass changeit \
  -destalias kafka-2 \
  -noprompt

docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -importcert \
  -alias CARoot \
  -keystore /work/certs/kafka.truststore.jks \
  -storetype JKS \
  -storepass changeit \
  -file /work/certs/ca.crt \
  -noprompt

chmod 600 /etc/kafka/certs/*.jks
chmod 600 /etc/kafka/certs/*.p12
chmod 644 /etc/kafka/certs/ca.crt

docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -list \
  -keystore /work/certs/kafka.keystore.jks \
  -storepass changeit
```

---

# PHASE 4 — Stop an toàn và rollout cả 3 node

## 4.1. Trên **mỗi server**, backup metadata trước

### Server `10.60.68.211`

```bash id="2s7nq0"
TS=$(date +%F-%H%M%S)
mkdir -p /root/backup-kafka-$TS
docker inspect database > /root/backup-kafka-$TS/database.inspect.json
echo "$TS" > /root/backup-kafka-$TS/ts.txt.md
```

### Server `10.60.68.242`

```bash id="oer77m"
TS=$(date +%F-%H%M%S)
mkdir -p /root/backup-kafka-$TS
docker inspect database > /root/backup-kafka-$TS/database.inspect.json
echo "$TS" > /root/backup-kafka-$TS/ts.txt.md
```

### Server `10.60.68.32`

```bash id="f9me2c"
TS=$(date +%F-%H%M%S)
mkdir -p /root/backup-kafka-$TS
docker inspect database > /root/backup-kafka-$TS/database.inspect.json
echo "$TS" > /root/backup-kafka-$TS/ts.txt.md
```

## 4.2. Dừng cả 3 container cũ

### Trên `10.60.68.211`

```
TS=$(cat /root/backup-kafka-*/ts.txt.md | tail -n 1)
docker stop -t 120 database
cp -a /var/lib/kafka/data /root/backup-kafka-$TS/data
docker rename database database-old-$TS
```

### Trên `10.60.68.242`

```
TS=$(cat /root/backup-kafka-*/ts.txt.md | tail -n 1)
docker stop -t 120 database
cp -a /var/lib/kafka/data /root/backup-kafka-$TS/data
docker rename database database-old-$TS
```

### Trên `10.60.68.32`

```
TS=$(cat /root/backup-kafka-*/ts.txt.md | tail -n 1)
docker stop -t 120 database
cp -a /var/lib/kafka/data /root/backup-kafka-$TS/data
docker rename database database-old-$TS
```

---

# PHASE 5 — Chạy 3 container mới

## 5.1. Server `10.60.68.211` (`kafka-0`)

```
docker run -d --name database \
  --hostname kafka-0 \
  --restart unless-stopped \
  -p 7071:7071 \
  -p 9092:9092 \
  -p 9093:9093 \
  -p 9094:9094 \
  -e KAFKA_CFG_PROCESS_ROLES=controller,broker \
  -e KAFKA_CFG_NODE_ID=0 \
  -e KAFKA_KRAFT_CLUSTER_ID=3dd86896-6318-403a-ac1c-bb34036ac82f \
  -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=0@10.60.68.211:9093,1@10.60.68.242:9093,2@10.60.68.32:9093 \
  -e KAFKA_CFG_LISTENERS=BROKER://:9092,CONTROLLER://:9093,EXTERNAL://:9094 \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=BROKER://10.60.68.211:9092,EXTERNAL://10.60.68.211:9094 \
  -e KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=BROKER:PLAINTEXT,CONTROLLER:PLAINTEXT,EXTERNAL:SSL \
  -e KAFKA_CFG_INTER_BROKER_LISTENER_NAME=BROKER \
  -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=true \
  -e KAFKA_CFG_DEFAULT_REPLICATION_FACTOR=3 \
  -e KAFKA_CFG_MIN_INSYNC_REPLICAS=2 \
  -e KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR=3 \
  -e KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=3 \
  -e KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR=2 \
  -e KAFKA_CFG_NUM_PARTITIONS=3 \
  -e JMX_PORT=2020 \
  -e KAFKA_TLS_TYPE=JKS \
  -e KAFKA_CERTIFICATE_PASSWORD=changeit \
  -e KAFKA_TLS_CLIENT_AUTH=none \
  -v /var/lib/kafka/data:/bitnami/kafka/data:rw \
  -v /opt/guest-agent/etc/kafka_client.conf:/etc/kafka_client.conf:rw \
  -v /etc/kafka/certs/kafka.keystore.jks:/opt/bitnami/kafka/config/certs/kafka.keystore.jks:ro \
  -v /etc/kafka/certs/kafka.truststore.jks:/opt/bitnami/kafka/config/certs/kafka.truststore.jks:ro \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7
```

## 5.2. Server `10.60.68.242` (`kafka-1`)

```
docker run -d --name database \
  --hostname kafka-1 \
  --restart unless-stopped \
  -p 7071:7071 \
  -p 9092:9092 \
  -p 9093:9093 \
  -p 9094:9094 \
  -e KAFKA_CFG_PROCESS_ROLES=controller,broker \
  -e KAFKA_CFG_NODE_ID=1 \
  -e KAFKA_KRAFT_CLUSTER_ID=3dd86896-6318-403a-ac1c-bb34036ac82f \
  -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=0@10.60.68.211:9093,1@10.60.68.242:9093,2@10.60.68.32:9093 \
  -e KAFKA_CFG_LISTENERS=BROKER://:9092,CONTROLLER://:9093,EXTERNAL://:9094 \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=BROKER://10.60.68.242:9092,EXTERNAL://10.60.68.242:9094 \
  -e KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=BROKER:PLAINTEXT,CONTROLLER:PLAINTEXT,EXTERNAL:SSL \
  -e KAFKA_CFG_INTER_BROKER_LISTENER_NAME=BROKER \
  -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=true \
  -e KAFKA_CFG_DEFAULT_REPLICATION_FACTOR=3 \
  -e KAFKA_CFG_MIN_INSYNC_REPLICAS=2 \
  -e KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR=3 \
  -e KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=3 \
  -e KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR=2 \
  -e KAFKA_CFG_NUM_PARTITIONS=3 \
  -e JMX_PORT=2020 \
  -e KAFKA_TLS_TYPE=JKS \
  -e KAFKA_CERTIFICATE_PASSWORD=changeit \
  -e KAFKA_TLS_CLIENT_AUTH=none \
  -v /var/lib/kafka/data:/bitnami/kafka/data:rw \
  -v /opt/guest-agent/etc/kafka_client.conf:/etc/kafka_client.conf:rw \
  -v /etc/kafka/certs/kafka.keystore.jks:/opt/bitnami/kafka/config/certs/kafka.keystore.jks:ro \
  -v /etc/kafka/certs/kafka.truststore.jks:/opt/bitnami/kafka/config/certs/kafka.truststore.jks:ro \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7
```

## 5.3. Server `10.60.68.32` (`kafka-2`)

```
docker run -d --name database \
  --hostname kafka-2 \
  --restart unless-stopped \
  -p 7071:7071 \
  -p 9092:9092 \
  -p 9093:9093 \
  -p 9094:9094 \
  -e KAFKA_CFG_PROCESS_ROLES=controller,broker \
  -e KAFKA_CFG_NODE_ID=2 \
  -e KAFKA_KRAFT_CLUSTER_ID=3dd86896-6318-403a-ac1c-bb34036ac82f \
  -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=0@10.60.68.211:9093,1@10.60.68.242:9093,2@10.60.68.32:9093 \
  -e KAFKA_CFG_LISTENERS=BROKER://:9092,CONTROLLER://:9093,EXTERNAL://:9094 \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=BROKER://10.60.68.32:9092,EXTERNAL://10.60.68.32:9094 \
  -e KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=BROKER:PLAINTEXT,CONTROLLER:PLAINTEXT,EXTERNAL:SSL \
  -e KAFKA_CFG_INTER_BROKER_LISTENER_NAME=BROKER \
  -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=true \
  -e KAFKA_CFG_DEFAULT_REPLICATION_FACTOR=3 \
  -e KAFKA_CFG_MIN_INSYNC_REPLICAS=2 \
  -e KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR=3 \
  -e KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=3 \
  -e KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR=2 \
  -e KAFKA_CFG_NUM_PARTITIONS=3 \
  -e JMX_PORT=2020 \
  -e KAFKA_TLS_TYPE=JKS \
  -e KAFKA_CERTIFICATE_PASSWORD=changeit \
  -e KAFKA_TLS_CLIENT_AUTH=none \
  -v /var/lib/kafka/data:/bitnami/kafka/data:rw \
  -v /opt/guest-agent/etc/kafka_client.conf:/etc/kafka_client.conf:rw \
  -v /etc/kafka/certs/kafka.keystore.jks:/opt/bitnami/kafka/config/certs/kafka.keystore.jks:ro \
  -v /etc/kafka/certs/kafka.truststore.jks:/opt/bitnami/kafka/config/certs/kafka.truststore.jks:ro \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7
```

---

# PHASE 6 — Verify sau rollout

## 6.1. Trên từng server

```
docker ps
docker logs --tail 200 database
ss -ltnp | egrep '7071|9092|9093|9094'
```

## 6.2. Kiểm tra TLS port từ bastion

```
openssl s_client -connect 10.60.68.211:9094 -servername kafka-0 </dev/null 2>/dev/null | egrep 'subject=|issuer='
openssl s_client -connect 10.60.68.242:9094 -servername kafka-1 </dev/null 2>/dev/null | egrep 'subject=|issuer='
openssl s_client -connect 10.60.68.32:9094 -servername kafka-2 </dev/null 2>/dev/null | egrep 'subject=|issuer='
```

## 6.3. Client properties để test Kafka qua SSL

```
bootstrap.servers=10.60.68.211:9094,10.60.68.242:9094,10.60.68.32:9094
security.protocol=SSL
ssl.truststore.location=/path/to/kafka.truststore.jks
ssl.truststore.password=changeit
```

---

# PHASE 7 — Rollback nếu có sự cố

Nếu một node lên lỗi, rollback trên **node đó** như sau:

```bash id="wvta93"
docker logs --tail 200 database
docker stop -t 30 database
docker rm database

OLD=$(docker ps -a --format '{{.Names}}' | grep '^database-old-' | tail -n 1)
docker rename "$OLD" database
docker start database
```

Nếu lỗi do cert/SSL mà muốn quay về cụm cũ, hãy rollback cả 3 node về container cũ để tránh cluster chạy mixed protocol.