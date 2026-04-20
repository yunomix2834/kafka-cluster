# Runbook lab Kafka KRaft (combined-mode)

Tài liệu này dành cho mô hình lab hiện tại:
- cụm Kafka gốc gồm **3 node combined-mode** (`controller,broker`)
- bài test resize trong lab là **3 -> 5** bằng cách thêm **2 broker-only node**
- client dùng `SASL_PLAINTEXT`
- tên container Docker là `database`
- thư mục data bind mount là `/var/lib/kafka/data -> /bitnami/kafka/data`
- file helper dùng xuyên suốt tài liệu là **`~/kafka_lab.sh`**

> Lưu ý quan trọng về combined mode:
> - Vì 3 node gốc đang chạy `controller,broker` trong cùng một JVM/container, ta **không thể giết riêng controller process** mà vẫn giữ nguyên broker process trên cùng node.
> - Cách mô phỏng gần đúng trong lab là:
>   - chặn `9093` thôi = mất **controller plane**, còn `9092` vẫn mở
>   - chặn `9092` thôi = mất **broker/data plane**, còn `9093` vẫn mở
>
> Điều này rất quan trọng khi đọc kết quả test, vì nhiều log ta thấy sẽ là tác động tổng hợp của cả broker lẫn controller nếu ta chặn cả `9092,9093` cùng lúc.

---

## 0. Chuẩn bị chung trước khi test

### 0.1. Chép file helper đúng tên
Trên **mỗi node gốc** của cụm 3 node:

```bash
scp -J root@bastion-host kafka_lab.sh root@ip-vm:/home/kafka_lab.sh
source ~/kafka_lab.sh
```

### 0.2. Kiểm tra nhanh cụm hiện tại
```bash
source ~/kafka_lab.sh
self_summary
k_cluster_snapshot
```

ta cần nhìn các dấu hiệu sau:
- `cluster.id` đúng
- `node.id` / `broker.id` đúng theo node đang đứng
- `bootstrap` hiển thị đủ 3 broker gốc
- `voters` hiển thị đúng 3 controller voter gốc
- `k_quorum` không báo lỗi

### 0.3. Tạo topic test
```bash
source ~/kafka_lab.sh
k_create_test_topics
k_describe_hot
k_describe_hot_p1
k_describe_backup_lab
```

### 0.4. Mở các terminal quan sát nền
Khuyến nghị tối thiểu 3 terminal.

**Terminal A - theo dõi quorum/controller**
```bash
source ~/kafka_lab.sh
w_quorum
```

**Terminal B - theo dõi hot partition**
```bash
source ~/kafka_lab.sh
w_hot_p1
```

**Terminal C - chạy producer mức vừa phải**

```bash
source ~/kafka_lab.sh
k_producer_hot_p1 300
```

Nếu muốn bắn thêm vào topic `ha-hot`:
```bash
source ~/kafka_lab.sh
k_producer_hot 500
```

**Terminal D - consumer (không bắt buộc)**
```bash
source ~/kafka_lab.sh
k_consumer_hot_p1
```

### 0.5. Xác định leader nóng trước mỗi case
Trước **mỗi kịch bản**, ta nên chạy:

```bash
source ~/kafka_lab.sh
k_partition_leader ha-hot-p1 0
k_partition_detail ha-hot-p1 0
```

Ý nghĩa:
- `k_partition_leader ha-hot-p1 0` cho biết broker nào đang giữ leader partition nóng
- `k_partition_detail` in chi tiết leader / replicas / ISR của partition đó

### 0.6. Dấu hiệu baseline khỏe mạnh
Trước khi bắt đầu từng case, nên xác nhận:
- `k_quorum` thấy đủ 3 voter
- `ha-hot-p1` ở trạng thái bình thường có ISR = 3
- producer đang ghi được
- `k_logs_controller 2m` không có election storm lặp liên tục

---

## 1. Case failover / HA - cô lập hoàn toàn 1 broker khỏi phần còn lại

### 1.1. Mục tiêu
Mô phỏng 1 node bị mất hoàn toàn kết nối với 2 node còn lại trên **cả broker plane và controller plane**.

### 1.2. Chạy trên node bị cô lập
```bash
source ~/kafka_lab.sh
k_ping_all
isolate_self_all
k_ping_all
```

Giải thích:
- `k_ping_all` trước khi cô lập để kiểm tra thông suốt ban đầu
- `isolate_self_all` sẽ chặn cả `9092,9093` tới các peer
- `k_ping_all` sau đó để xác nhận đã bị chặn thật

### 1.3. Check chi tiết trong lúc lỗi
Từ một node còn sống:
```bash
source ~/kafka_lab.sh
k_quorum
k_quorum_replication
k_describe_hot_p1
k_partition_detail ha-hot-p1 0
k_logs_controller 2m
k_logs_replica 2m
```

### 1.4. Những điểm cần quan sát
- controller có election mới hay không
- node bị cô lập có rơi khỏi ISR hay không
- nếu node bị cô lập đang là leader của `ha-hot-p1-0` thì leader có chuyển sang node khác không
- producer có đứng tạm rồi hồi lại không

### 1.5. Khôi phục
Trên node đã cô lập:
```bash
source ~/kafka_lab.sh
heal_self_all
k_ping_all
```

### 1.6. Check sau khôi phục
```bash
source ~/kafka_lab.sh
k_quorum
k_quorum_replication
k_describe_hot_p1
k_partition_detail ha-hot-p1 0
k_logs_controller 5m
k_logs_replica 5m
```

### 1.7. Tiêu chí pass
- quorum hội tụ lại
- ISR phục hồi về trạng thái khỏe
- không còn election storm kéo dài sau khi heal

---

## 2. Case failover / HA - cô lập broker đang giữ leader của partition nóng

### 2.1. Mục tiêu
Buộc hot partition đổi leader trong lúc producer vẫn đang ghi dữ liệu.

### 2.2. Xác định leader nóng
Từ bất kỳ node nào:
```bash
source ~/kafka_lab.sh
k_partition_leader ha-hot-p1 0
k_partition_detail ha-hot-p1 0
```

Ghi lại broker id leader hiện tại, rồi SSH sang đúng node đó.

### 2.3. Cắt hoàn toàn traffic trên node leader nóng
```bash
source ~/kafka_lab.sh
isolate_self_all
```

### 2.4. Check trong lúc lỗi
Từ node còn sống:
```bash
source ~/kafka_lab.sh
k_quorum
k_describe_hot_p1
k_partition_detail ha-hot-p1 0
k_logs_controller 2m
k_logs_replica 2m
```

### 2.5. Điều cần xác nhận
- leader của `ha-hot-p1-0` chuyển khỏi broker cũ
- producer có tiếp tục ghi được sau khi leader mới lên
- ISR co lại lúc lỗi và nở lại sau khi khôi phục

### 2.6. Khôi phục
Trên node vừa bị cô lập:
```bash
source ~/kafka_lab.sh
heal_self_all
```

### 2.7. Kiểm tra có tranh chấp leader không
```bash
source ~/kafka_lab.sh
k_describe_hot_p1
k_partition_detail ha-hot-p1 0
k_leader_elect_preferred ha-hot-p1 0 || true
k_describe_hot_p1
k_logs_controller 5m
```

### 2.8. Tiêu chí pass
- không có hiện tượng leader flip-flop liên tục sau khi heal
- epoch có thể tăng nhưng phải dừng lại và ổn định
- partition settle về một leader rõ ràng

---

## 3. Case failover / HA - làm cụm rơi xuống dưới controller quorum

### 3.1. Mục tiêu
Chứng minh metadata quorum không hoạt động được nếu mất majority controller.

### 3.2. Cách làm
Giữ producer đang ghi, sau đó dừng **2 trong 3 node combined gốc**.

Ví dụ dừng node 1 và node 2.

**Trên node 1**
```bash
source ~/kafka_lab.sh
broker_stop
```

**Trên node 2**
```bash
source ~/kafka_lab.sh
broker_stop
```

### 3.3. Check từ node còn lại
```bash
source ~/kafka_lab.sh
k_quorum
k_logs_controller 2m
k_logs_replica 2m
```

### 3.4. Kỳ vọng
- mất majority controller quorum
- metadata operation bị stall hoặc fail
- producer có thể đứng / fail vì cụm không tiến được về metadata

### 3.5. Khôi phục
Bật lại 1 node trước, rồi node còn lại:
```bash
source ~/kafka_lab.sh
broker_start
```

### 3.6. Check sau khôi phục
```bash
source ~/kafka_lab.sh
k_quorum
k_quorum_replication
k_describe_hot_p1
k_logs_controller 5m
```

### 3.7. Tiêu chí pass
- metadata quorum hồi lại bình thường
- không còn election storm kéo dài sau khi cả 2 node quay lại

---

## 4. Case failover / HA - mất đúng controller plane nhưng broker traffic vẫn còn

### 4.1. Mục tiêu
Mô phỏng mất controller plane (`9093`) nhưng vẫn giữ broker traffic (`9092`).

### 4.2. Lưu ý
Đây là **mô phỏng gần đúng**, vì cluster gốc dùng combined mode.

### 4.3. Trên node mục tiêu
```bash
source ~/kafka_lab.sh
isolate_self_ctrl_only
```

### 4.4. Check chi tiết
```bash
source ~/kafka_lab.sh
k_ping_all
k_quorum
k_describe_hot_p1
k_partition_detail ha-hot-p1 0
k_logs_controller 2m
```

### 4.5. Điều cần quan sát
- controller election / epoch change
- partition data có thể vẫn chạy tiếp một thời gian vì `9092` còn mở
- hot partition leader không nhất thiết phải đổi chỉ vì controller leader đổi

### 4.6. Khôi phục
```bash
source ~/kafka_lab.sh
heal_self_ctrl_only
k_quorum
k_logs_controller 5m
```

### 4.7. Tiêu chí pass
- controller leadership ổn định lại
- không còn controller contention lặp mãi sau khi heal

---

## 5. Case failover / HA - mất broker traffic nhưng controller plane vẫn còn

### 5.1. Mục tiêu
Tách lỗi broker/data plane khỏi lỗi controller plane.

### 5.2. Trên node mục tiêu
```bash
source ~/kafka_lab.sh
isolate_self_broker_only
```

### 5.3. Check
```bash
source ~/kafka_lab.sh
k_ping_all
k_quorum
k_describe_hot_p1
k_partition_detail ha-hot-p1 0
k_logs_replica 2m
```

### 5.4. Điều cần quan sát
- controller quorum có thể vẫn khỏe
- node mục tiêu bị rớt khỏi ISR ở các partition liên quan
- log replication/fetcher có lỗi trong `k_logs_replica`

### 5.5. Khôi phục
```bash
source ~/kafka_lab.sh
heal_self_broker_only
k_describe_hot_p1
k_logs_replica 5m
```

### 5.6. Tiêu chí pass
- node quay lại ISR đúng kỳ vọng
- không có fetch failure loop kéo dài

---

## 6. Case disk full / disk stall trong khi process vẫn sống

### 6.1. Gần đầy disk
Trên node mục tiêu:
```bash
source ~/kafka_lab.sh
df -h "$DATA_HOST"
disk_fill_near_full "$DATA_HOST" 512
```

Ý nghĩa:
- script sẽ chừa lại khoảng 512 MB
- không đẩy đầy tuyệt đối để tránh VM bị shutdown cứng

### 6.2. Check
```bash
source ~/kafka_lab.sh
df -h "$DATA_HOST"
k_logs_storage 5m
k_describe_hot
k_describe_hot_p1
```

### 6.3. Điều cần quan sát
- `No space left` hoặc log dir failure
- ISR co lại trên broker đó
- producer bị chậm hoặc fail

### 6.4. Cleanup
```bash
source ~/kafka_lab.sh
disk_unfill "$DATA_HOST"
k_logs_storage 5m
```

---

### 6.5. Disk stall / I/O pressure
**Terminal A**
```bash
source ~/kafka_lab.sh
k_producer_hot 500
```

**Terminal B trên node mục tiêu**
```bash
source ~/kafka_lab.sh
disk_stall_dd "$DATA_HOST"
# hoặc disk_stall_fio "$DATA_HOST"
```

### 6.6. Check
```bash
source ~/kafka_lab.sh
k_logs_storage 5m
k_logs_replica 5m
k_describe_hot
```

### 6.7. Cleanup
```bash
source ~/kafka_lab.sh
disk_unfill "$DATA_HOST"
```

### 6.8. Tiêu chí pass
- broker thể hiện stress đúng kỳ vọng
- cụm hồi lại sau khi dọn I/O pressure
- không còn log-dir offline kéo dài

---

## 7. Case network latency / packet loss / packet reorder

> Rất dễ nhầm IP peer với IP của chính node đang đứng. Trước khi chạy netem, luôn kiểm tra route trước.

### 7.1. Delay tới 1 peer
```bash
source ~/kafka_lab.sh
netem_route_to <peer-ip>
netem_peer_delay <peer-ip> 300ms 80ms
netem_peer_show <peer-ip>
```

### 7.2. Loss tới 1 peer
```bash
source ~/kafka_lab.sh
netem_peer_loss <peer-ip> 10% 30% 100ms 20ms
```

### 7.3. Reorder tới 1 peer
```bash
source ~/kafka_lab.sh
netem_peer_reorder <peer-ip> 20ms 25% 50%
```

### 7.4. Check
```bash
source ~/kafka_lab.sh
k_quorum
k_logs_controller 2m
k_logs_replica 2m
```

### 7.5. Cleanup
```bash
source ~/kafka_lab.sh
netem_clear_peer <peer-ip>
```

### 7.6. Tiêu chí pass
- thấy được tương quan giữa delay/loss/reorder với log quorum hoặc replication
- sau khi clear qdisc, cluster ổn định lại

---

## 8. Case rolling restart / rolling upgrade style test

### 8.1. Mục tiêu
Restart từng node một, không làm sập cả cụm.

### 8.2. Cách chạy
Với **mỗi node gốc**, lần lượt từng node:
```bash
source ~/kafka_lab.sh
broker_stop
broker_start
```

### 8.3. Giữa mỗi node, phải chờ và kiểm tra
```bash
source ~/kafka_lab.sh
k_quorum
k_quorum_replication
k_describe_hot
k_describe_hot_p1
k_logs_controller 2m
```

### 8.4. Tiêu chí pass
- cluster vẫn sống qua từng lần restart đơn lẻ
- ISR không hỏng kéo dài sau từng node

---

## 9. Runbook backup / restore (cold backup)

Phần này chỉ dùng cho **cold backup / cold restore**.
Không coi đây là hot backup.

### 9.1. Pre-check trên từng node
```bash
source ~/kafka_lab.sh
self_summary
backup_precheck
k_describe_hot_p1
k_partition_distribution_all
k_logs_controller 5m
k_logs_replica 5m
```

Những gì cần kiểm:
- `k_quorum` đủ 3 voter
- topic mục tiêu có ISR đúng kỳ vọng
- `df -h` còn đủ chỗ để tạo tar
- `meta.properties` tồn tại và có `cluster.id`, `node.id` đúng

### 9.2. Dừng traffic
Dừng tất cả producer / consumer đang mở ở các terminal tải.
Sau đó kiểm tra group:
```bash
source ~/kafka_lab.sh
k_group_hot || true
k_group_hot_p1 || true
```

### 9.3. Dừng tất cả broker gốc
Trên cả 3 VM gốc:
```bash
source ~/kafka_lab.sh
broker_stop
```

Check:
```bash
docker ps -a --filter name=database
```
Kỳ vọng: container `database` ở trạng thái exited trên cả 3 node.

### 9.4. Tạo cold backup trên từng VM
Trên từng VM:
```bash
source ~/kafka_lab.sh
backup_local_data_cold /srv/kafka-backups
```

Mỗi node sẽ in ra 2 file:
- `kafka-node<N>-TIMESTAMP.tgz`
- `kafka-node<N>-TIMESTAMP.manifest.txt`

### 9.5. Kiểm tra archive
```bash
source ~/kafka_lab.sh
backup_archive_check /srv/kafka-backups/kafka-node0-YYYY-MM-DD_HHMMSS.tgz
```

Xem manifest:
```bash
sed -n '1,120p' /srv/kafka-backups/kafka-node0-YYYY-MM-DD_HHMMSS.manifest.txt
```

### 9.6. Copy ra ngoài (không bắt buộc)
Ví dụ copy qua jump host:
```bash
scp -o ProxyJump=root@bastion-host root@NODE_IP:/srv/kafka-backups/kafka-node0-YYYY-MM-DD_HHMMSS.tgz .
```

### 9.7. Full-cluster cold restore
Trước tiên, đảm bảo cả 3 broker gốc đều đang dừng:
```bash
source ~/kafka_lab.sh
broker_stop || true
```

Restore đúng file backup tương ứng trên từng node.

**Node 0**
```bash
source ~/kafka_lab.sh
restore_local_data_cold /srv/kafka-backups/kafka-node0-YYYY-MM-DD_HHMMSS.tgz
restore_postcheck_local
```

**Node 1**
```bash
source ~/kafka_lab.sh
restore_local_data_cold /srv/kafka-backups/kafka-node1-YYYY-MM-DD_HHMMSS.tgz
restore_postcheck_local
```

**Node 2**
```bash
source ~/kafka_lab.sh
restore_local_data_cold /srv/kafka-backups/kafka-node2-YYYY-MM-DD_HHMMSS.tgz
restore_postcheck_local
```

### 9.8. Khởi động lại cả 3 broker
Trên từng node:
```bash
source ~/kafka_lab.sh
broker_start
```

### 9.9. Post-check sau restore
Chờ 20–60 giây, rồi từ một node:
```bash
source ~/kafka_lab.sh
k_quorum
k_quorum_replication
k_describe_hot_p1
k_partition_distribution_all
k_logs_controller 5m
k_logs_replica 5m
k_log_dirs 0 1 2
```

Dấu hiệu khỏe:
- `k_quorum` đủ voters
- metadata quorum replication bắt kịp
- partition có replicas và ISR đúng
- không có election storm kéo dài
- không có truncation / fetch failure storm kéo dài

### 9.10. Lưu ý restore 1 node
Trong lab này, nên ưu tiên **full-cluster cold restore**.
Không nên restore 1 node bằng dữ liệu cũ trong khi các node khác đã chạy vượt xa rồi.

---

## 10. Resize test - thêm 2 broker (3 -> 5)

### 10.1. Thiết kế dùng trong lab này
- giữ nguyên KRaft controller quorum của cụm gốc là **0,1,2**
- thêm **2 broker-only node** với `node.id=3` và `node.id=4`
- **không** thêm 3,4 vào `controller.quorum.voters`

### 10.2. Vì sao làm vậy
Mục tiêu của bài này là **mở rộng capacity**, không phải bài toán đổi controller membership.

### 10.3. Cài Docker trên 2 VM mới
```bash
cd ../ansible-resize-broker
cp inventory.ini.example inventory.ini
# sửa IP và password của 2 VM mới
ansible-playbook playbooks/install_docker_official.yml
```

### 10.4. Deploy broker-only node 3 và 4
```bash
ansible-playbook playbooks/deploy_kafka_broker_only_3to5.yml
```

### 10.5. Verify node mới
Trên từng VM mới:
```bash
docker ps
ss -ltnp | egrep ':7071|:9092'
docker logs --tail 100 database
```

Trên 1 node gốc:
```bash
source ~/kafka_lab.sh
k_topics --list
k_describe_hot
k_describe_hot_p1
```

### 10.6. Tạo file scope của reassignment
ta có 2 cách.

#### Cách A - tạo file ở trong container `database`
Dùng cách này nếu helper `k_reassign_*` của ta đang chạy bằng `docker exec` trong container.

```bash
docker exec -i database sh -lc 'cat >/tmp/topics-to-move.json <<JSON
{"version":1,"topics":[{"topic":"ha-hot"},{"topic":"ha-hot-p1"},{"topic":"backup-lab"}]}
JSON'
```

#### Cách B - tạo ở host rồi copy vào container
```bash
cat >/tmp/topics-to-move.json <<JSON
{"version":1,"topics":[{"topic":"ha-hot"},{"topic":"ha-hot-p1"},{"topic":"backup-lab"}]}
JSON

docker cp /tmp/topics-to-move.json database:/tmp/topics-to-move.json
```

### 10.7. Generate reassignment plan
```bash
source ~/kafka_lab.sh
k_reassign_generate /tmp/topics-to-move.json "0,1,2,3,4"
```

Lệnh này sẽ in ra 2 phần:
- `Current partition replica assignment`
- `Proposed partition reassignment configuration`

### 10.8. Lưu proposed plan thành file JSON
ta **phải** lưu phần `Proposed partition reassignment configuration` thành một file JSON để dùng cho bước execute / verify.

Ví dụ, lưu thành file `/tmp/expand-cluster-reassignment.json` **ở trong container**:

```bash
docker exec -i database sh -lc 'cat >/tmp/expand-cluster-reassignment.json <<JSON
{"version":1,"partitions":[
  {"topic":"backup-lab","partition":0,"replicas":[2,3,4],"log_dirs":["any","any","any"]},
  {"topic":"backup-lab","partition":1,"replicas":[3,4,0],"log_dirs":["any","any","any"]}
  /* dán tiếp toàn bộ phần Proposed partition reassignment configuration vào đây */
]}
JSON'
```

Nếu ta muốn làm ở host trước rồi copy vào container:

```bash
cat >/tmp/expand-cluster-reassignment.json <<JSON
{"version":1,"partitions":[
  {"topic":"backup-lab","partition":0,"replicas":[2,3,4],"log_dirs":["any","any","any"]},
  {"topic":"backup-lab","partition":1,"replicas":[3,4,0],"log_dirs":["any","any","any"]}
  /* dán tiếp toàn bộ plan */
]}
JSON

docker cp /tmp/expand-cluster-reassignment.json database:/tmp/expand-cluster-reassignment.json
```

> Lưu ý rất quan trọng:
> - file JSON dùng cho `k_reassign_execute` phải là **toàn bộ** phần plan được generate
> - không được thiếu partition
> - không được thêm comment thật vào JSON. Dòng `/* ... */` ở ví dụ trên chỉ là chỗ nhắc ta dán tiếp, không được giữ lại khi chạy thật.

### 10.9. Execute reassignment
```bash
source ~/kafka_lab.sh
k_reassign_execute /tmp/expand-cluster-reassignment.json
```

### 10.10. Verify reassignment nhiều lần
```bash
source ~/kafka_lab.sh
k_reassign_verify /tmp/expand-cluster-reassignment.json
k_partition_distribution_all
```

Nếu muốn xem riêng các topic chính:
```bash
source ~/kafka_lab.sh
k_describe_hot
k_describe_hot_p1
k_describe_backup_lab
```

### 10.11. Điều cần kiểm sau reassignment
- một số partition phải có replica nằm trên broker 3 và 4
- ISR phải hội tụ về đúng replica set mới
- không có under-replication kéo dài trong `k_logs_replica 5m`

### 10.12. Tiêu chí pass cho resize
- broker 3 và 4 chạy ổn định
- reassignment hoàn tất thành công
- partition phân tán sang 0,1,2,3,4 đúng kế hoạch
- cluster vẫn khỏe sau reassignment

---

## 11. Bộ lệnh kiểm tra nhanh

### A. Check control plane
```bash
source ~/kafka_lab.sh
k_quorum
k_quorum_replication
k_logs_controller 5m
```

### B. Check data plane
```bash
source ~/kafka_lab.sh
k_describe_hot_p1
k_partition_distribution_all
k_logs_replica 5m
k_log_dirs 0 1 2
```

### C. Check trạng thái container
```bash
docker ps -a --filter name=database
docker inspect database | sed -n '1,120p'
```

### D. Check thư mục data và metadata
```bash
source ~/kafka_lab.sh
df -h "$DATA_HOST"
du -sh "$DATA_HOST"
find "$DATA_HOST" -maxdepth 2 -mindepth 1 | sed -n '1,80p'
grep -E '^(cluster.id|node.id|version)=' "$DATA_HOST/meta.properties"
```
