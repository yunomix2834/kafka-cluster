SASL (Simple Authentication and Security Layer) là một framework để thêm các cơ chế xác thực vào các giao thức mạng. SASL không phải là một giao thức cụ thể mà là một cơ chế để hỗ trợ nhiều phương thức xác thực khác nhau.
Các cơ chế SASL phổ biến:

    PLAIN: Gửi tên người dùng và mật khẩu dưới dạng plaintext (văn bản không mã hóa).
    SCRAM (Salted Challenge Response Authentication Mechanism): Sử dụng các hash để bảo vệ mật khẩu và cung cấp một mức độ bảo mật cao hơn so với PLAIN.
    GSSAPI: Sử dụng Kerberos để xác thực.
    OAuth: Sử dụng OAuth tokens để xác thực.

1. cơ chế plain:
plain mode / docker-compose.yaml
```yaml
version: '2'

services:
  kafka:
    container_name: kafka-plain
    image: 'bitnami/kafka:latest'
    environment:
      - KAFKA_CFG_NODE_ID=1
      - KAFKA_CFG_PROCESS_ROLES=broker,controller
      - KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@127.0.0.1:9093
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093,SASL_PLAINTEXT://:9094
      - KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://127.0.0.1:9092,SASL_PLAINTEXT://127.0.0.1:9094
      - KAFKA_CFG_LOG_DIRS=/opt/bitnami/kafka/logs
      - KAFKA_CFG_SASL_ENABLED_MECHANISMS=PLAIN
      - KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL=PLAIN
      - KAFKA_CFG_SECURITY_INTER_BROKER_PROTOCOL=SASL_PLAINTEXT
      - KAFKA_CFG_SUPER_USERS=User:admin
      - KAFKA_OPTS=-Djava.security.auth.login.config=/opt/bitnami/kafka/config/kafka_jaas.conf
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT,SASL_PLAINTEXT:SASL_PLAINTEXT 
      - KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR=1
      - KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR=1
      - KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1
    volumes:
      - ./kafka_jaas.conf:/opt/bitnami/kafka/config/kafka_jaas.conf
    ports:
      - '9092:9092'
      - '9093:9093'
      - '9094:9094'
```

plain mode / kafka_jaas.conf
```ini
KafkaServer {
  org.apache.kafka.common.security.plain.PlainLoginModule required
  username="admin"
  password="admin-secret"
  user_admin="admin-secret"
  user_user="user-secret";
};
```

2. cơ chế scram:
scram mode / docker-compose.yaml
```yaml
version: '2'

services:
  kafka:
    container_name: kafka-scram
    image: 'bitnami/kafka:latest'
    environment:
      - KAFKA_ENABLE_KRAFT=yes
      - KAFKA_CFG_NODE_ID=1
      - KAFKA_CFG_PROCESS_ROLES=broker,controller
      - KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@127.0.0.1:9093
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093,SASL_PLAINTEXT://:9094
      - KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://127.0.0.1:9092,SASL_PLAINTEXT://127.0.0.1:9094
      - KAFKA_CFG_LOG_DIRS=/opt/bitnami/kafka/logs
      - KAFKA_CFG_SASL_ENABLED_MECHANISMS=SCRAM-SHA-256
      - KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL=SCRAM-SHA-256 
      - KAFKA_CFG_SECURITY_INTER_BROKER_PROTOCOL=SASL_PLAINTEXT
      - KAFKA_CFG_SUPER_USERS=User:admin
      - KAFKA_OPTS=-Djava.security.auth.login.config=/opt/bitnami/kafka/config/kafka_jaas_scram.conf
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT,SASL_PLAINTEXT:SASL_PLAINTEXT
      - KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR=1
      - KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR=1
      - KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1
    volumes:
      - ./kafka_jaas_scram.conf:/opt/bitnami/kafka/config/kafka_jaas_scram.conf
    ports:
      - '9092:9092'
      - '9093:9093'
      - '9094:9094' 
```

scram mode / kafka_jaas.conf
```ini
KafkaServer {
  org.apache.kafka.common.security.scram.ScramLoginModule required
  username="admin"
  password="admin-secret";
};
```

lưu ý: với mode scram, sau khi start với config scram trong file kafka_jaas.conf, phải exec vào bash của kafka để tạo user
kafka-configs.sh --bootstrap-server localhost:9092 --alter --add-config 'SCRAM-SHA-256=[iterations=4096,password=admin-secret]' --entity-type users --entity-name admin
mà mode plain thì không cần

Trong đó env: 
KAFKA_ENABLE_KRAFT	Kích hoạt chế độ KRaft, cho phép Kafka hoạt động mà không cần ZooKeeper, sử dụng cơ chế quản lý cụm nội bộ dựa trên Raft	
KAFKA_CFG_NODE_ID	Đặt ID cho nút Kafka	
KAFKA_CFG_PROCESS_ROLES	Vai trò của Kafka, vừa là một broker (xử lý các yêu cầu client) và vừa là một controller (quản lý trạng thái của các broker khác trong cụm).	
KAFKA_CFG_CONTROLLER_LISTENER_NAMES	Kafka sử dụng chế độ Kraft vì vậy Kafka và Kraft giao tiếp với nhau qua một listener riêng	
KAFKA_CFG_CONTROLLER_QUORUM_VOTERS	Chỉ định danh sách các controller node có quyền vote trong cụm KRaft	