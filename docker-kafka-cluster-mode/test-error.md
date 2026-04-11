## Kịch bản nên làm: sai SAN

Ý tưởng là tạo lại cert cho `kafka-1`, nhưng cố ý cho SAN **không chứa**:

* `IP:10.60.68.242`
* `DNS:kafka-1`

mà thay bằng giá trị sai, ví dụ:

* `IP:10.60.68.250`
* `DNS:broken-kafka-1`

Như vậy:

* broker vẫn start được vì cert hợp lệ và keystore vẫn đọc được
* nhưng client gọi `10.60.68.242:9094` sẽ fail verify vì endpoint không khớp cert. `ssl.endpoint.identification.algorithm` mặc định là `https`, nên đây là kiểu fail đúng bài nhất. ([Kafka][1])

## Bước 1: backup cert tốt hiện tại trên broker

Chạy trên `10.60.68.242`:

```bash
TS=$(date +%F-%H%M%S)
cp -a /etc/kafka/certs/kafka.keystore.jks /etc/kafka/certs/kafka.keystore.jks.good.$TS
echo "$TS" > /etc/kafka/certs/rollback-ts.txt
```

## Bước 2: trên bastion, gen cert sai SAN

Trên bastion:

```bash
BASE=./kafka-ca
OUT=$BASE/badcerts/kafka-1-wrong-san
PASS=changeit

mkdir -p "$OUT"

cat > "$OUT/kafka-1-wrong.cnf" <<'EOF'
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
CN = 10.60.68.242

[ req_ext ]
subjectAltName = @alt_names
extendedKeyUsage = serverAuth,clientAuth

[ alt_names ]
IP.1 = 10.60.68.250
DNS.1 = broken-kafka-1
EOF

openssl genrsa -out "$OUT/kafka-1.key" 2048

openssl req -new \
  -key "$OUT/kafka-1.key" \
  -out "$OUT/kafka-1.csr" \
  -config "$OUT/kafka-1-wrong.cnf"

openssl x509 -req \
  -in "$OUT/kafka-1.csr" \
  -CA "$BASE/ca/ca.crt" \
  -CAkey "$BASE/ca/ca.key" \
  -CAcreateserial \
  -out "$OUT/kafka-1.crt" \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile "$OUT/kafka-1-wrong.cnf"

openssl pkcs12 -export \
  -name kafka-1 \
  -inkey "$OUT/kafka-1.key" \
  -in "$OUT/kafka-1.crt" \
  -certfile "$BASE/ca/ca.crt" \
  -out "$OUT/kafka-1-wrong-san.p12" \
  -passout pass:"$PASS"
```

## Bước 3: copy file test sang broker

Từ bastion:

```bash
scp ./kafka-ca/badcerts/kafka-1-wrong-san/kafka-1-wrong-san.p12 \
  root@10.60.68.242:/etc/kafka/certs/
```

## Bước 4: convert file sai SAN thành JKS trên broker

Trên `10.60.68.242`:

```bash
docker run --rm \
  -u 0:0 \
  -v /etc/kafka/certs:/work/certs \
  --entrypoint /opt/bitnami/java/bin/keytool \
  registry2.cloud.cmctelecom.vn/rnd_db/kafka:3.7 \
  -importkeystore \
  -srckeystore /work/certs/kafka-1-wrong-san.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass changeit \
  -srcalias kafka-1 \
  -destkeystore /work/certs/kafka.keystore.jks \
  -deststoretype JKS \
  -deststorepass changeit \
  -destkeypass changeit \
  -destalias kafka-1 \
  -noprompt
```

Sửa permission để container Kafka đọc được:

```bash
chown 1001:1001 /etc/kafka/certs/kafka.keystore.jks
chmod 600 /etc/kafka/certs/kafka.keystore.jks
```

## Bước 5: restart broker để nạp cert mới

```bash
docker restart database
docker logs --tail 200 database
```

Nếu broker lên lại bình thường thì bài test đã vào đúng trạng thái mong muốn: **server sống, nhưng cert sai endpoint**.

## Bước 6: test lại bằng OpenSSL, gọi đúng host IP thật

Trên bastion:

```bash
openssl s_client \
  -connect 10.60.68.242:9094 \
  -CAfile ./kafka-ca/ca/ca.crt \
  -verify_ip 10.60.68.242 \
  </dev/null 2>&1 | egrep 'subject=|issuer=|Verify return code|Verification'
```

Kỳ vọng:

* vẫn thấy `subject=` và `issuer=`
* nhưng **không còn** `Verify return code: 0 (ok)`
* phải ra lỗi verify vì IP `10.60.68.242` không nằm trong SAN của cert mới. Việc này khớp với cách Kafka/OpenSSL kiểm tra endpoint theo certificate. ([Kafka][1])

## Bước 7: test lại bằng Kafka client

Trên broker hoặc nơi nào có Kafka CLI, giữ file client này:

```properties
security.protocol=SSL
ssl.truststore.location=/opt/bitnami/kafka/config/certs/kafka.truststore.jks
ssl.truststore.password=changeit
ssl.endpoint.identification.algorithm=https
```

Rồi chạy:

```bash
docker exec -it \
  -e JMX_PORT= \
  -e KAFKA_JMX_OPTS= \
  database /opt/bitnami/kafka/bin/kafka-topics.sh \
  --list \
  --bootstrap-server 10.60.68.242:9094 \
  --command-config /tmp/client-ssl.properties
```

Kỳ vọng:

* lệnh fail ở lớp SSL verification
* không phải fail kiểu port down
* không phải fail kiểu timeout mơ hồ

Vì `security.protocol=SSL` là đúng protocol cho client SSL, còn `ssl.endpoint.identification.algorithm=https` buộc client kiểm cert theo endpoint. ([Kafka][1])

## Rollback về cert đúng

Trên `10.60.68.242`:

```bash
TS=$(cat /etc/kafka/certs/rollback-ts.txt)
cp -a /etc/kafka/certs/kafka.keystore.jks.good.$TS /etc/kafka/certs/kafka.keystore.jks
chown 1001:1001 /etc/kafka/certs/kafka.keystore.jks
chmod 600 /etc/kafka/certs/kafka.keystore.jks
docker restart database
```

Rồi test lại:

```bash
openssl s_client \
  -connect 10.60.68.242:9094 \
  -CAfile ./kafka-ca/ca/ca.crt \
  -verify_ip 10.60.68.242 \
  </dev/null 2>&1 | egrep 'subject=|issuer=|Verify return code|Verification'
```

Lúc đó muốn thấy lại:

```text
Verification: OK
Verify return code: 0 (ok)
```