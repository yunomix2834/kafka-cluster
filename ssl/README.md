 # Runbook triển khai Kafka SSL chi tiết (qua jump host)

Tài liệu này tổng hợp lại hướng triển khai SSL/TLS cho cụm Kafka Docker KRaft 3 node combined mode.

## 1. Bài toán và phạm vi
Runbook này áp dụng cho cụm có đặc điểm:
- 3 node combined mode: mỗi node vừa là controller vừa là broker
- container Kafka tên `database`
- bind mount dữ liệu: `/var/lib/kafka/data -> /bitnami/kafka/data`
- file auth đang có sẵn:
  - `/opt/guest-agent/etc/kafka_client.conf`
  - `/etc/kafka/config/kafka_jaas.conf`
- container chạy user `1001`
- hiện tại cụm đang dùng:
  - 9092 cho broker/internal client
  - 9093 cho controller
- mục tiêu: thêm 9094 dùng SSL để test OpenSSL và Kafka CLI, không phá logic đang chạy ở 9092/9093

## 2. Thiết kế SSL được chọn
### 2.1. Listener sau khi triển khai
- `BROKER://:9092` -> `SASL_PLAINTEXT`
- `CONTROLLER://:9093` -> `PLAINTEXT`
- `EXTERNAL://:9094` -> `SSL`

### 2.2. Vì sao chọn cách này
Cách này giúp:
- dễ test bằng `openssl s_client`
- dễ test bằng Kafka CLI với `security.protocol=SSL`
- dễ làm bài test sai SAN
- dễ rollback hơn so với việc đổi toàn bộ cluster sang SSL

### 2.3. Cấu hình logic tương ứng
```properties
listeners=BROKER://:9092,CONTROLLER://:9093,EXTERNAL://:9094
advertised.listeners=BROKER://<IP_NODE>:9092,EXTERNAL://<IP_NODE>:9094
listener.security.protocol.map=BROKER:SASL_PLAINTEXT,CONTROLLER:PLAINTEXT,EXTERNAL:SSL
inter.broker.listener.name=BROKER
controller.listener.names=CONTROLLER
```

## 3. Chuẩn bị trước khi chạy
### 3.1. Máy chạy Ansible
ta có thể chạy Ansible từ:
- bastion
- hoặc laptop / máy quản trị có thể SSH qua bastion

Máy chạy Ansible cần có:
- ansible
- openssl
- kết nối SSH tới jump host
- jump host có thể SSH tiếp vào các VM Kafka

### 3.2. Sửa inventory
File cần sửa:
- `ansible-ssl/inventory.ini`

Ví dụ:
```ini
[kafka_combined_nodes]
kafka-0 ansible_host=10.10.10.100 kafka_node_id=0 advertised_ip=10.10.10.100 ansible_user=root ansible_password=CHANGE_ME ansible_ssh_common_args='-o ProxyJump=root@bastion-host'
kafka-1 ansible_host=10.10.10.101 kafka_node_id=1 advertised_ip=10.10.10.101 ansible_user=root ansible_password=CHANGE_ME ansible_ssh_common_args='-o ProxyJump=root@bastion-host'
kafka-2 ansible_host=10.10.10.102 kafka_node_id=2 advertised_ip=10.10.10.102 ansible_user=root ansible_password=CHANGE_ME ansible_ssh_common_args='-o ProxyJump=root@bastion-host'
```

### 3.3. Sửa group_vars
Mở file:
- `ansible-ssl/group_vars/all.yml`

Kiểm tra ít nhất:
- `kafka_image`
- `kafka_cluster_id`
- `kafka_controller_quorum_voters`
- `kafka_tls_store_password`

Khuyến nghị:
- đặt `kafka_image` bằng đúng image lab đang dùng
- nếu “chỉ đổi IP và xóa registry đi thôi”, thì thay image cho đúng bản tương ứng

## 4. Bước 1 - Sinh CA và cert cho 3 broker
Playbook này chạy trên máy điều khiển / bastion, không SSH vào broker.

Chạy:
```bash
cd ansible-ssl
ansible-playbook playbooks/generate_tls_assets_local.yml
```

Sau khi chạy xong, ta sẽ có:
- `generated/ca/ca.crt`
- `generated/ca/ca.key`
- `generated/brokers/kafka-0/kafka-0.p12`
- `generated/brokers/kafka-1/kafka-1.p12`
- `generated/brokers/kafka-2/kafka-2.p12`

### 4.1. Verify nhanh cert vừa sinh
Ví dụ kiểm tra broker 1:
```bash
openssl x509 -in generated/brokers/kafka-1/kafka-1.crt -noout -subject -issuer
openssl x509 -in generated/brokers/kafka-1/kafka-1.crt -noout -text | egrep -A2 'Subject Alternative Name|Extended Key Usage'
```

muốn thấy:
- SAN có IP đúng của broker
- SAN có DNS đúng theo inventory host, ví dụ `kafka-1`

## 5. Bước 2 - Deploy SSL lên 3 broker
Playbook này sẽ:
1. Tạo thư mục `/etc/kafka/certs`
2. Copy `ca.crt`
3. Copy `.p12` đúng theo từng broker
4. Convert `.p12` thành:
   - `kafka.keystore.jks`
   - `kafka.truststore.jks`
5. Chỉnh quyền để user `1001` đọc được
6. Render file `client-ssl.properties`
7. Backup `docker inspect` hiện tại ra `/root/database.inspect.before_ssl.json`
8. Render script docker run mới có 9094 SSL
9. Recreate container
10. Chờ 9092 và 9094 mở

Chạy:
```bash
cd ansible-ssl
ansible-playbook --ask-pass playbooks/deploy_ssl_combined_nodes.yml
```

Nếu đã lưu password trong inventory.ini thì có thể bỏ `--ask-pass`.

### 5.1. Nếu playbook fail
Playbook có sẵn phần `rescue` để in:
- `docker ps -a`
- trạng thái container
- `docker logs --tail 200`

Đọc ngay đoạn đó để biết lỗi thực tế.

## 6. Bước 3 - Verify broker sau rollout
Trên từng broker:
```bash
docker ps
docker logs --tail 200 database
ss -ltnp | egrep '7071|9092|9093|9094'
```

muốn thấy:
- container `database` đang `running`
- port `9094` đang LISTEN
- không có lỗi startup lặp lại

## 7. Bước 4 - Test SSL bằng OpenSSL
Đứng trên bastion / máy chạy ansible:
```bash
openssl s_client   -connect 10.10.10.101:9094   -CAfile ./generated/ca/ca.crt   -verify_ip 10.10.10.101   </dev/null 2>&1 | egrep 'subject=|issuer=|Verify return code|Verification'
```

### 7.1. Kỳ vọng khi đúng
Muốn thấy kiểu:
```text
subject=...
issuer=...
Verification: OK
Verify return code: 0 (ok)
```

### 7.2. Nếu sai
Nếu CA sai, chain sai, hoặc SAN không chứa endpoint đang gọi, sẽ không thấy `Verify return code: 0 (ok)`.

## 8. Bước 5 - Test SSL bằng Kafka CLI
### 8.1. Tạo file client SSL config trong container
```bash
docker exec -it database bash -lc 'cat > /tmp/client-ssl.properties <<EOF
security.protocol=SSL
ssl.truststore.location=/opt/bitnami/kafka/config/certs/kafka.truststore.jks
ssl.truststore.password=changeit
ssl.endpoint.identification.algorithm=https
EOF'
```

> Playbook cũng đã render sẵn file tương tự ở host:
> `/opt/guest-agent/etc/client-ssl.properties`

### 8.2. List topic qua 9094
```bash
docker exec -it   -e JMX_PORT=   -e KAFKA_JMX_OPTS=   database /opt/bitnami/kafka/bin/kafka-topics.sh   --list   --bootstrap-server 10.10.10.101:9094   --command-config /tmp/client-ssl.properties
```

### 8.3. Tạo topic test
```bash
docker exec -it   -e JMX_PORT=   -e KAFKA_JMX_OPTS=   database /opt/bitnami/kafka/bin/kafka-topics.sh   --create   --topic ssl-test   --partitions 1   --replication-factor 1   --bootstrap-server 10.10.10.101:9094   --command-config /tmp/client-ssl.properties
```

### 8.4. Describe topic test
```bash
docker exec -it   -e JMX_PORT=   -e KAFKA_JMX_OPTS=   database /opt/bitnami/kafka/bin/kafka-topics.sh   --describe   --topic ssl-test   --bootstrap-server 10.10.10.101:9094   --command-config /tmp/client-ssl.properties
```

## 9. Bước 6 - Test Producer / Consumer qua SSL
### 9.1. Producer
```bash
docker exec -it   -e JMX_PORT=   -e KAFKA_JMX_OPTS=   database /opt/bitnami/kafka/bin/kafka-console-producer.sh   --topic ssl-test   --bootstrap-server 10.10.10.101:9094   --producer.config /tmp/client-ssl.properties
```

Gõ thử:
```text
hello1
hello2
```

### 9.2. Consumer
Mở terminal khác:
```bash
docker exec -it   -e JMX_PORT=   -e KAFKA_JMX_OPTS=   database /opt/bitnami/kafka/bin/kafka-console-consumer.sh   --topic ssl-test   --from-beginning   --bootstrap-server 10.10.10.101:9094   --consumer.config /tmp/client-ssl.properties
```

Nếu thấy `hello1`, `hello2` thì SSL path hoạt động.

## 10. Test lỗi khuyến nghị - sai SAN
Xem file:
- `docs/test_wrong_san.md`

Ý nghĩa:
- broker vẫn có thể start
- port 9094 vẫn mở
- nhưng OpenSSL / Kafka client sẽ fail verify endpoint đúng bản chất SSL

## 11. Lỗi thường gặp
### 11.1. Sai quyền file cert
Container Kafka chạy user `1001`. Nếu:
- `kafka.keystore.jks`
- `kafka.truststore.jks`
không đọc được bởi user này, container có thể fail khi start.

### 11.2. SAN không chứa IP / DNS đang gọi
Nếu client gọi:
- `10.10.10.101:9094`
thì cert nên chứa ít nhất:
- `IP:10.10.10.101`
hoặc nếu client gọi bằng tên:
- `DNS:kafka-1`

### 11.3. Gọi nhầm protocol
- 9092 trong runbook này là `SASL_PLAINTEXT`
- 9094 mới là `SSL`
Đừng dùng `security.protocol=SSL` để gọi 9092.

### 11.4. Image không đúng
Nếu image trong `kafka_image` không có:
- `/opt/bitnami/java/bin/keytool`
- layout chuẩn Bitnami Kafka
thì bước convert JKS sẽ fail.

## 12. Thứ tự chạy khuyến nghị
1. Sửa `inventory.ini`
2. Sửa `group_vars/all.yml`
3. Chạy:
   ```bash
   ansible-playbook playbooks/generate_tls_assets_local.yml
   ```
4. Kiểm tra cert vừa sinh
5. Chạy:
   ```bash
   ansible-playbook --ask-pass playbooks/deploy_ssl_combined_nodes.yml
   ```
6. Kiểm tra `docker ps`, `docker logs`, `ss -ltnp`
7. Test bằng `openssl s_client`
8. Test bằng `kafka-topics.sh`
9. Test producer/consumer
10. Test wrong-SAN nếu cần

## 13. Ghi chú bảo mật
- Không commit:
  - `ca.key`
  - `.p12`
  - `.jks`
  - file password thật
- `.gitignore` trong bundle đã chặn các file bí mật phổ biến
- Nếu dùng lâu dài, nên chuyển password sang Ansible Vault

## 14. Lệnh ngắn gọn nhất
```bash
cd ansible-ssl
cp inventory.ini.example inventory.ini
# sửa inventory.ini và group_vars/all.yml
ansible-playbook playbooks/generate_tls_assets_local.yml
ansible-playbook --ask-pass playbooks/deploy_ssl_combined_nodes.yml
```

Rồi test:
```bash
openssl s_client -connect 10.10.10.101:9094 -CAfile ./generated/ca/ca.crt -verify_ip 10.10.10.101 </dev/null
```

và:
```bash
docker exec -it database /opt/bitnami/kafka/bin/kafka-topics.sh   --list   --bootstrap-server 10.10.10.101:9094   --command-config /tmp/client-ssl.properties
```
