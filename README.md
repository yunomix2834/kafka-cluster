# Kafka Docker KRaft Lab

## 1. Mục tiêu

Project này phục vụ cho một cụm Kafka chạy bằng Docker, dùng KRaft, với các hướng chính:

- vận hành cụm Kafka 3 node combined mode
- test failover / HA / KRaft
- backup / restore lạnh (cold backup)
- resize thêm broker (3 -> 5)
- triển khai SSL cho cụm hiện hữu
- triển khai SSL cho broker mới khi resize

## 2. Tài liệu nên đọc

Đọc: `README.md` (file hiện tại)

### Nếu muốn thêm broker mới
Đọc: `./resize-broker/README.md`

### Nếu muốn bật SSL cho 3 node hiện có
Đọc: `./ssl/README.md`