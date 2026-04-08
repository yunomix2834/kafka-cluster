connect-console-sink.properties: Config dữ liệu từ Kafka Topic ra Console (Terminal)
```ini
name=local-console-sink
connector.class=org.apache.kafka.connect.file.FileStreamSinkConnector
tasks.max=1
topics=connect-test
```

connect-file-sink.properties: Config dữ liệu từ Kafka Topic được ghi ra file
```ini
name=local-file-sink
connector.class=FileStreamSink
tasks.max=1
file=test.sink.txt
topics=connect-test
```

connect-mirror-maker.properties: Config dữ liệu đi từ cluster Kafka nguồn đến cluster Kafka đích
```ini
clusters = A, B

A.bootstrap.servers = A_host1:9092, A_host2:9092, A_host3:9092
B.bootstrap.servers = B_host1:9092, B_host2:9092, B_host3:9092

A->B.enabled = true

A->B.topics = .*

B->A.enabled = true
B->A.topics = .*

replication.factor=1

checkpoints.topic.replication.factor=1
heartbeats.topic.replication.factor=1
offset-syncs.topic.replication.factor=1

offset.storage.replication.factor=1
status.storage.replication.factor=1
config.storage.replication.factor=1
```

kraft/broker.properties: 

kraft/controller.properties:

kraft/server.properties:

server.properties: server.properties
```ini
broker.id=0
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=/tmp/kafka-logs
num.partitions=1
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
log.retention.hours=168
#log.retention.bytes=1073741824
#log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=localhost:2181
# Timeout in ms for connecting to zookeeper
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0
```

trogdor.conf: Hệ thống test của Kafka để mô phỏng và kiểm tra các kịch bản lỗi, khả năng chịu lỗi
```ini
{
    "_comment": [
        "Licensed to the Apache Software Foundation (ASF) under one or more",
        "contributor license agreements.  See the NOTICE file distributed with",
        "this work for additional information regarding copyright ownership.",
        "The ASF licenses this file to You under the Apache License, Version 2.0",
        "(the \"License\"); you may not use this file except in compliance with",
        "the License.  You may obtain a copy of the License at",
        "",
        "http://www.apache.org/licenses/LICENSE-2.0",
        "",
        "Unless required by applicable law or agreed to in writing, software",
        "distributed under the License is distributed on an \"AS IS\" BASIS,",
        "WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.",
        "See the License for the specific language governing permissions and",
        "limitations under the License."
    ],
    "platform": "org.apache.kafka.trogdor.basic.BasicPlatform", "nodes": {
        "node0": {
            "hostname": "localhost",
            "trogdor.agent.port": 8888,
            "trogdor.coordinator.port": 8889
        }
    }
}
```

connect-console-source.properties: Config dữ liệu từ Console ghi vào Kafka Topic
```ini
name=local-console-source
connector.class=org.apache.kafka.connect.file.FileStreamSourceConnector
tasks.max=1
topic=connect-test
```

connect-file-source.properties: Config dữ liệu từ File ghi vào Kafka Topic
```ini
name=local-file-source
connector.class=FileStreamSource
tasks.max=1
file=test.txt
topic=connect-test
```

connect-standalone.properties: Sử dụng khi Kafka Connect không ở chế độ distributed
```ini
bootstrap.servers=localhost:9092

key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true

offset.storage.file.filename=/tmp/connect.offsets
offset.flush.interval.ms=10000
```

log4j.properties: Config log

server.properties.original: Tham chiếu Config ban đầu

zookeeper.properties: Config Zookeeper
```ini
dataDir=/tmp/zookeeper
clientPort=2181
maxClientCnxns=0
admin.enableServer=false
```

connect-distributed.properties: Sử dụng khi Kafka Connect chạy ở chế độ distributed

connect-log4j.properties: Config log

consumer.properties: Config các consumer

producer.properties: Config các producer

tools-log4j.properties: Config log


guest-agent config:
single-mode
```ini
mode=single_node
basic_auth=true || false
users=user1:password1,user2:password2
```

cluster-mode
```ini
mode=cluster
cluster_id=abcdefghijklmnopqrstuv
broker_id=0
node_id=0
cluster_nodes=172.29.68.182,172.29.66.105,172.29.67.28
basic_auth=true || false
users=user1:password1,user2:password2
```

với cluster_nodes là ds các IP của agent, với thứ tự (index) trong danh sách ứng với broker_id (node_id) (IP đầu tiên ứng với broker có id là 0, IP thứ 2 ứng với broker có id là 1, IP thứ 3 ứng với broker có id là 2

Action:

    Kiểm tra trạng thái agent: kafka-topics.sh --bootstrap-server localhost:9092 --list
    Kiểm tra trạng thái cluster:


