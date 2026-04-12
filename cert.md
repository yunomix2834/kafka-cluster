Nếu bạn đang hỏi theo nghĩa **“chứng chỉ về Apache Kafka hiện nay nên thi kỳ nào”**, thì điểm cần nói rõ trước là: **bộ chứng chỉ phổ biến nhất hiện nay là của Confluent**, và **Confluent Certification không thuộc Apache Software Foundation**. Trên trang chính thức hiện tại, Confluent đang public 3 kỳ thi chứng chỉ chính: **Confluent Certified Developer for Apache Kafka (CCDAK)**, **Confluent Certified Administrator for Apache Kafka (CCAAK)**, và **Confluent Cloud Certified Operator (CCAC)**. Ngoài ra còn có các **Fundamentals accreditation** miễn phí, nhưng đó là badge/accreditation, không phải chứng chỉ nghề nghiệp chính như 3 kỳ thi bên trên. ([Confluent][1])

Về hình thức thi, trang chính thức của Confluent cho biết các bài thi chứng chỉ là **thi có giám sát từ xa**, thời lượng **90 phút**, kết quả hiện ngay sau khi làm xong, **không được dùng tài liệu tham khảo**, và chứng chỉ có hiệu lực **2 năm**. ([Confluent][1])

Tôi tóm lại từng kỳ thi như sau.

## 1) CCDAK — Confluent Certified Developer for Apache Kafka

Đây là kỳ thi dành cho **developer** và **solution architect** xây ứng dụng với Kafka. Mô tả chính thức nói rõ chứng chỉ này xác nhận năng lực để **phát triển, triển khai và duy trì** các ứng dụng streaming thời gian thực bằng các API cốt lõi của Kafka và các khả năng nền tảng liên quan. ([Confluent][1])

Muốn thi kỳ này, bạn nên nắm chắc:

* **Kafka fundamentals**: event là gì, topic, partition, broker, replication, cách Kafka lưu và nhân bản event. Khóa Kafka 101 của Confluent nhấn mạnh việc hiểu cách Kafka **store, structure, and replicate events**. ([Confluent][2])
* **Producer / Consumer**: cách ghi và đọc dữ liệu, partitioning, retries, ordering, offsets, consumer groups, delivery guarantees. Khóa kiến trúc của Confluent liệt kê rõ các chủ đề như **consumer group protocol**, **durability, availability, ordering guarantees**, và **transactions**. ([Confluent][3])
* **Kafka internals ở mức developer cần dùng được**: hiểu kiến trúc storage layer / compute layer, broker hoạt động thế nào, control plane, replication protocol. ([Confluent][4])
* **Kafka Streams**: đây là phần rất đáng học cho hướng developer, vì Confluent mô tả Kafka Streams là thư viện xử lý stream real-time xây trên producer/consumer APIs. ([Confluent][5])
* **Kafka Connect**: source connector, sink connector, SMTs, và vai trò của Connect trong pipeline dữ liệu. ([Confluent][6])
* **Schema Registry**: đăng ký schema, schema evolution, validation. ([Confluent][7])
* **Security cơ bản**: authentication, authorization, encryption, audit logs, vì nếu ứng dụng Kafka đi production thì phần này không thể bỏ qua. ([Confluent][8])

Nói dễ hiểu: **CCDAK hợp với người viết app dùng Kafka**. Bạn phải mạnh ở **producer/consumer**, **message flow**, **guarantees**, **Streams**, **Connect**, và đủ hiểu bảo mật + schema để làm hệ thống thật.

## 2) CCAAK — Confluent Certified Administrator for Apache Kafka

Đây là kỳ thi dành cho người **quản trị và vận hành cluster Kafka**. Mô tả chính thức nói nó dành cho người **configure, deploy, monitor, and support Apache Kafka clusters** để đảm bảo hiệu năng và vận hành ổn định. ([Confluent][1])

Muốn thi kỳ này, bạn nên nắm chắc:

* **Kafka fundamentals nhưng theo góc nhìn vận hành**: topics, partitions, brokers, replication, leader/follower, consumer groups. ([Confluent][3])
* **Kiến trúc cluster**: broker internals, control plane, replication protocol, durability, availability, ordering guarantees, transactions. Đây là lõi của tư duy admin. ([Confluent][4])
* **KRaft / control plane**: hiện Kafka hiện đại chuyển mạnh sang KRaft thay vì ZooKeeper, nên admin nên hiểu metadata/control plane hoạt động ra sao. Confluent có course riêng về KRaft và control plane. ([Confluent][9])
* **Security**: authentication, authorization, encryption, audit logs. Đây là phần chính thức Confluent coi là kiến thức cơ bản để đưa Kafka vào production an toàn. ([Confluent][8])
* **Monitoring và troubleshooting**: uptime, data loss risks, remediation, capacity, growth, cost. Khóa “Operating the Platform” của Confluent mô tả đúng các năng lực này. ([Confluent][10])
* **HA/DR và độ bền vận hành**: replication, cluster health, failover mindset, disaster recovery. ([Confluent][3])
* **Connect / ecosystem ở góc nhìn vận hành**: không chỉ biết dùng mà còn biết theo dõi trạng thái connector, lag, lỗi, DLQ. ([Confluent][11])

Nói ngắn gọn: **CCAAK hợp với platform engineer / SRE / admin**. Trọng tâm không phải viết app, mà là **dựng cluster, cấu hình, bảo mật, giám sát, xử lý sự cố, giữ hệ thống ổn định**.

## 3) CCAC — Confluent Cloud Certified Operator

Đây là kỳ thi thiên về **Confluent Cloud** hơn là self-managed Kafka. Mô tả chính thức nói nó xác nhận khả năng quản lý kiến trúc Kafka trên môi trường cloud/multi-cloud/global, dùng các tính năng như **Cluster Linking, Stream Governance, fully managed connectors, stream processing**. ([Confluent][1])

Muốn thi kỳ này, bạn nên nắm chắc:

* **Confluent Cloud fundamentals**: environment, cluster, service account, API key, managed services. ([Confluent][12])
* **Cloud security**: SSO, API keys, OAuth, service accounts, RBAC, ACLs, audit logs, rotation key. Trang course chính thức của Confluent nêu rất rõ các thực hành như dùng **service-account API keys** cho production và **rotate API keys regularly**. ([Confluent][12])
* **Cloud networking**: các cách kết nối mạng giữa app của bạn với Confluent Cloud, cùng các trade-off về **security, privacy, cost**. ([Confluent][13])
* **Monitoring / auditing trên cloud**: theo dõi các thay đổi với cluster, user, service account, connector, SSO, API keys qua audit logs. ([Confluent][14])
* **Managed connectors và stream governance**: fully managed connectors, Schema Registry, governance/data quality. ([Confluent][1])
* **HA / DR trên cloud**: đặc biệt là **Cluster Linking** cho disaster recovery. ([Confluent][1])

Nói dễ hiểu: **CCAC hợp với người vận hành Kafka trên Confluent Cloud**, không thiên về “tự cài broker từ đầu” như admin self-managed.

## Chọn kỳ thi nào cho đúng hướng

Nếu bạn đang đi theo hướng **developer/backend/data engineer viết ứng dụng dùng Kafka**, hãy đi **CCDAK** trước. ([Confluent][1])

Nếu bạn đi theo hướng **SRE/platform/infra**, phải dựng và chăm cluster Kafka, thì đi **CCAAK** trước. ([Confluent][1])

Nếu công ty bạn dùng **Confluent Cloud** nhiều và công việc thiên về account, networking, security, governance, managed connectors, multi-cloud, thì **CCAC** phù hợp hơn. ([Confluent][1])

## Lộ trình học thực tế tôi khuyên

Nếu bạn mới bắt đầu, thứ tự hợp lý là:

1. **Kafka fundamentals**: topics, partitions, brokers, offsets, consumer groups, replication. ([Confluent][2])
2. **Producer/Consumer thật chắc**: partitioning, retries, ordering, delivery guarantees, transactions. ([Confluent][15])
3. Sau đó rẽ nhánh:

   * **Developer path**: Streams, Connect, Schema Registry, security. ([Confluent][5])
   * **Administrator path**: architecture, KRaft, security, monitoring, HA/DR. ([Confluent][4])
   * **Cloud Operator path**: Confluent Cloud networking, auth/RBAC/ACL, audit logs, managed connectors, cluster linking. ([Confluent][13])

Tóm lại, hiện tại bạn có thể hiểu **“chứng chỉ Kafka”** chủ yếu là 3 hướng chính:

* **CCDAK**: viết ứng dụng với Kafka
* **CCAAK**: quản trị/vận hành cluster Kafka
* **CCAC**: vận hành Kafka trên Confluent Cloud ([Confluent][1])

Nếu bạn muốn, tôi có thể làm tiếp cho bạn một bảng **so sánh CCDAK vs CCAAK vs CCAC** và kèm **roadmap học 6–8 tuần** theo đúng hướng công việc của bạn.

[1]: https://www.confluent.io/certification/ "Confluent Certification for Apache Kafka | Confluent"
[2]: https://developer.confluent.io/courses/apache-kafka/events/ "What You'll Learn in This Apache Kafka® 101 Course"
[3]: https://developer.confluent.io/courses/architecture/data-replication/ "Kafka Data Replication Protocol: A Complete Guide"
[4]: https://developer.confluent.io/courses/architecture/get-started/ "Apache Kafka Architecture Deep Dive"
[5]: https://developer.confluent.io/courses/kafka-streams/get-started/?utm_source=chatgpt.com "Kafka Streams: Basic Concepts, Architecture, and Examples"
[6]: https://developer.confluent.io/courses/apache-kafka/kafka-connect/ "How Kafka Connect Integrates External Systems"
[7]: https://developer.confluent.io/courses/governing-data-streams/schema-registry/ "Schema Registry: Maintain Data Quality Across Data Streams"
[8]: https://developer.confluent.io/courses/security/intro/ "Kafka Security Basics, A Complete Checklist"
[9]: https://developer.confluent.io/learn/kraft/?utm_source=chatgpt.com "KRaft - Apache Kafka Without ZooKeeper"
[10]: https://developer.confluent.io/courses/data-streaming-systems/operating-the-platform/ "Operating the Platform"
[11]: https://developer.confluent.io/courses/kafka-connect/monitoring-kafka-connect/?utm_source=chatgpt.com "Monitoring Kafka Connect"
[12]: https://developer.confluent.io/courses/cloud-security/authentication/ "Apache Kafka Authentication with Confluent Cloud"
[13]: https://developer.confluent.io/courses/confluent-cloud-networking/intro/ "Confluent Cloud Networking Basics and Apache Kafka Connectivity"
[14]: https://developer.confluent.io/courses/cloud-security/auditing-and-monitoring/ "Audit and Monitor Kafka Clusters Using Confluent Cloud"
[15]: https://developer.confluent.io/courses/apache-kafka/producers/?utm_source=chatgpt.com "Kafka Producers: Writing Data Into Your Event Pipeline"
