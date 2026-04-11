Test bằng OpenSSL
Đưng ở trên bastion host
```shell
openssl s_client \
  -connect 10.60.68.242:9094 \
  -CAfile ./kafka-ca/ca/ca.crt \
  -verify_ip 10.60.68.242 \
  </dev/null 2>&1 | egrep 'subject=|issuer=|Verify return code|Verification'
```

Đứng ở trên broker kafka

```shell
docker exec -it database bash -lc 'cat > /tmp/client-ssl.properties <<EOF
security.protocol=SSL
ssl.truststore.location=/opt/bitnami/kafka/config/certs/kafka.truststore.jks
ssl.truststore.password=changeit
ssl.endpoint.identification.algorithm=https
EOF'
```

```shell
docker exec -it \
  -e JMX_PORT= \
  -e KAFKA_JMX_OPTS= \
  database /opt/bitnami/kafka/bin/kafka-topics.sh \
  --list \
  --bootstrap-server 10.60.68.242:9094 \
  --command-config /tmp/client-ssl.properties
```
  
```shell
docker exec -it \
  -e JMX_PORT= \
  -e KAFKA_JMX_OPTS= \
  database /opt/bitnami/kafka/bin/kafka-topics.sh \
  --create \
  --topic ssl-test \
  --partitions 1 \
  --replication-factor 1 \
  --bootstrap-server 10.60.68.242:9094 \
  --command-config /tmp/client-ssl.properties
```
  
```shell
docker exec -it \
  -e JMX_PORT= \
  -e KAFKA_JMX_OPTS= \
  database /opt/bitnami/kafka/bin/kafka-topics.sh \
  --describe \
  --topic ssl-test \
  --bootstrap-server 10.60.68.242:9094 \
  --command-config /tmp/client-ssl.properties
```
  
  
------------------------------Test Producer/ Consumer--------------

```shell
docker exec -it \
  -e JMX_PORT= \
  -e KAFKA_JMX_OPTS= \
  database /opt/bitnami/kafka/bin/kafka-console-producer.sh \
  --topic ssl-test \
  --bootstrap-server 10.60.68.242:9094 \
  --producer.config /tmp/client-ssl.properties
```

Gõ vài dòng như:

```shell
hello1
hello2
```

Mở terminal khác và chạy

```shell
docker exec -it \
  -e JMX_PORT= \
  -e KAFKA_JMX_OPTS= \
  database /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
  --topic ssl-test \
  --from-beginning \
  --bootstrap-server 10.60.68.242:9094 \
  --consumer.config /tmp/client-ssl.properties
```