
# Kafka Toàn Tập: Kiến Trúc, Hiệu Năng, Độ Tin Cậy, Bảo Mật và Vận Hành

> **Mục tiêu tài liệu**  
> Tài liệu này hệ thống hóa lại nội dung ghi chú về Kafka theo bố cục rõ ràng, có phân cấp tiêu đề, bảng tổng hợp và các phần lưu ý quan trọng để dễ học, dễ tra cứu và dễ tái sử dụng.

---

# 1. Kafka là gì?

## 1.1. Định nghĩa

Kafka là **nền tảng lưu trữ và xử lý sự kiện phân tán** (distributed event streaming platform), được sinh ra để:

- Thu thập dữ liệu khổng lồ theo thời gian thực.
- Lưu trữ dữ liệu bền vững.
- Xử lý và truyền dữ liệu với độ trễ thấp.
- Kết nối các dịch vụ trong một hệ thống phân tán phức tạp.

### 1.1.1. Hình dung trực quan

Nếu cả hệ thống là **một dòng máu**, thì Kafka là **hệ thần kinh trung ương** giúp các dịch vụ “nói chuyện” với nhau thông qua một dòng chảy dữ liệu:

- Nhanh
- Tin cậy
- Có khả năng mở rộng rất lớn

> **Lưu ý:** Kafka không chỉ là một message queue thông thường. Kafka là một nền tảng streaming có khả năng lưu trữ lâu dài, xử lý song song và tích hợp mạnh với hệ sinh thái dữ liệu thời gian thực. fileciteturn3file0L1-L6

---

# 2. Các khái niệm cốt lõi

## 2.1. Message và Topic

### 2.1.1. Message là gì?

**Message** là đơn vị dữ liệu nhỏ nhất trong Kafka, tương tự như một bản ghi trong cơ sở dữ liệu.

Một message thường gồm:

| Thành phần | Ý nghĩa |
|---|---|
| Key | Khóa định danh, thường dùng để quyết định partition |
| Value | Nội dung chính của dữ liệu |
| Header | Thông tin bổ sung (metadata) |

> **Hình dung:** Nếu hệ thống là một dòng máu, thì message là **tế bào dữ liệu** — nhỏ bé nhưng mang thông tin sống.

### 2.1.2. Topic là gì?

**Topic** là một danh mục hoặc “thư mục” được đặt tên để tổ chức và lưu trữ các message.

Ví dụ:

- `user-events`
- `payment-transactions`
- `application-logs`

### 2.1.3. Hành trình dữ liệu cơ bản

1. Một hệ thống bên ngoài (**Producer**) tạo ra message.
2. Producer gửi message vào một **topic cụ thể**.
3. Message được lưu vào topic tương ứng, giống như lưu một tệp vào đúng thư mục.

---

## 2.2. Partition

### 2.2.1. Vì sao cần partition?

Câu hỏi quan trọng là:

**Kafka làm thế nào để xử lý hàng triệu message mà không bị “nghẹt”?**

Câu trả lời là: **Partition**.

Mỗi topic được chia thành nhiều partition để:

- Cho phép ghi song song
- Cho phép đọc song song
- Phân tán tải
- Tăng khả năng mở rộng ngang

### 2.2.2. Ý nghĩa thực tiễn của partition

| Khía cạnh | Vai trò của partition |
|---|---|
| Hiệu năng | Cho phép xử lý song song |
| Mở rộng | Dễ phân tán qua nhiều broker |
| Tính thứ tự | Kafka chỉ đảm bảo thứ tự trong **một partition** |
| Cân bằng tải | Hỗ trợ phân phối dữ liệu đều hơn |

> **Lưu ý quan trọng:** Kafka **không đảm bảo thứ tự trên toàn bộ topic** nếu topic có nhiều partition. Kafka chỉ đảm bảo thứ tự trong từng partition. fileciteturn3file0L7-L20

---

## 2.3. Producer, Consumer và Cluster

### 2.3.1. Producer

Producer là thành phần tạo ra message và gửi tới topic.

Producer có thể:

- Gộp nhiều message thành batch để giảm tải mạng
- Tự động phân phối message vào các partition
- Tối ưu hiệu năng khi gửi dữ liệu với tốc độ cao

### 2.3.2. Consumer

Consumer là thành phần đọc message từ Kafka.

Consumer thường hoạt động theo **consumer group** để:

- Chia tải việc đọc dữ liệu
- Tránh xử lý trùng lặp giữa các consumer trong cùng nhóm
- Tăng thông lượng xử lý

### 2.3.3. Cluster

Kafka cluster là một nhóm các máy chủ (**broker**) làm việc cùng nhau.

Mỗi broker giữ một phần dữ liệu. Toàn cluster phối hợp để mang lại:

- Khả năng dự phòng
- Khả năng chịu lỗi
- Khả năng mở rộng ngang

### 2.3.4. Replication trong cluster

Các partition không chỉ được phân tán mà còn được **replicate** sang các broker khác để tránh mất dữ liệu khi một broker gặp sự cố.

| Thành phần | Vai trò |
|---|---|
| Broker | Máy chủ Kafka lưu và phục vụ dữ liệu |
| Leader replica | Bản sao chính nhận ghi và phục vụ đọc |
| Follower replica | Bản sao phụ đồng bộ dữ liệu từ leader |
| ISR | Tập replica đang theo kịp leader và đủ điều kiện được bầu làm leader mới |

> **Lưu ý:** Một cluster mạnh không chỉ cần nhiều broker, mà còn cần chiến lược replication, ISR và failover hợp lý. fileciteturn3file0L21-L34

---

# 3. Vì sao Kafka rất nhanh?

## 3.1. Hai trụ cột hiệu năng

Kafka có thể xử lý khối lượng rất lớn nhờ hai cơ chế nền tảng:

1. **Sequential I/O** (ghi tuần tự)
2. **Zero Copy** (không sao chép trung gian không cần thiết)

---

## 3.2. Sequential I/O

### 3.2.1. Ghi ngẫu nhiên vs ghi tuần tự

Nếu ghi ngẫu nhiên, đầu đọc của ổ đĩa phải liên tục di chuyển để tìm vị trí ghi mới, giống như một thủ thư phải chạy khắp thư viện để cất sách.

Ngược lại, với **ghi tuần tự**, dữ liệu được ghi nối tiếp vào cuối file:

- Giảm seek time
- Tận dụng tốt phần cứng lưu trữ
- Tăng thông lượng ghi

### 3.2.2. Lợi ích

| Cách ghi | Đặc điểm | Tác động |
|---|---|---|
| Ghi ngẫu nhiên | Đầu đọc di chuyển nhiều | Chậm hơn |
| Ghi tuần tự | Ghi nối tiếp cuối file | Nhanh hơn nhiều |

---

## 3.3. Zero Copy

### 3.3.1. Vấn đề của sao chép trung gian

Khi dữ liệu phải sao chép qua nhiều vùng nhớ, CPU sẽ phải làm nhiều việc hơn và độ trễ cộng dồn sẽ tăng lên.

Mô hình truyền dữ liệu truyền thống thường có nhiều bước sao chép:

1. Từ đĩa vào bộ đệm của hệ điều hành
2. Từ bộ đệm hệ điều hành sang bộ đệm ứng dụng
3. Từ bộ đệm ứng dụng sang socket buffer
4. Từ socket buffer sang card mạng

### 3.3.2. Với Zero Copy

Hệ điều hành có thể gửi dữ liệu gần như trực tiếp từ bộ đệm đĩa đến card mạng thông qua các lệnh như `sendfile()`.

### 3.3.3. So sánh

| Tiêu chí | Không có Zero Copy | Có Zero Copy |
|---|---|---|
| Số lần sao chép | Nhiều lần (OS và Application) | Ít hơn, trực tiếp hơn |
| Tải CPU | Cao | Thấp hơn |
| Độ trễ | Lớn hơn | Nhỏ hơn |
| Hiệu năng tổng thể | Kém hơn | Tốt hơn |

> **Kết luận:** Ghi tuần tự giúp giảm chi phí I/O, còn Zero Copy giúp giảm tải CPU. Kết hợp hai yếu tố này tạo nên hiệu năng rất cao của Kafka. fileciteturn3file0L35-L52

---

# 4. Các bài toán Kafka thường giải quyết

## 4.1. Xử lý và phân tích log

Kafka thường được dùng làm lớp trung tâm để thu thập log từ nhiều microservice rồi đẩy sang các hệ thống phân tích.

Ứng dụng tiêu biểu:

- Observability
- Log streaming
- Centralized logging

## 4.2. Luồng dữ liệu gợi ý và học máy

Mỗi hành vi người dùng có thể được ghi thành một sự kiện, đẩy vào Kafka và xử lý bởi các hệ thống như Flink để phục vụ:

- Recommendation
- Machine learning features
- Real-time personalization

## 4.3. Giám sát và cảnh báo hệ thống

Các dịch vụ trong hệ thống liên tục gửi metric hoặc event vào Kafka, sau đó được phân tích để phát hiện bất thường và cảnh báo sớm.

## 4.4. CDC (Change Data Capture)

Kafka thường đóng vai trò trung gian phân phối các thay đổi dữ liệu từ database đến nhiều hệ thống đích theo thời gian thực.

## 4.5. Di chuyển và nâng cấp hệ thống

Hệ thống cũ có thể đẩy dữ liệu vào Kafka, còn hệ thống mới dần đọc dữ liệu từ Kafka để chuyển đổi từng bước mà không cần cắt chuyển đột ngột.

> **Lưu ý:** Kafka đặc biệt mạnh ở những nơi cần tách rời producer và consumer theo thời gian, không gian và tốc độ xử lý. fileciteturn3file0L53-L66

---

# 5. Kafka có thật sự không bao giờ mất message không?

## 5.1. Câu trả lời ngắn gọn

**Không có hệ thống nào “mặc định” không bao giờ mất dữ liệu.** Kafka rất mạnh, nhưng độ an toàn thực sự phụ thuộc vào cấu hình producer, broker, replication và consumer offset.

---

## 5.2. Rủi ro ở phía Producer

### 5.2.1. Hành trình của message ở producer

1. Application thread tạo message
2. Record accumulator giữ message trong hàng đợi
3. Sender thread gửi message ra broker

### 5.2.2. Rủi ro

Nếu ứng dụng chết đột ngột khi message còn nằm trong `record accumulator`, message đó có thể mất.

### 5.2.3. Cấu hình nên dùng

| Cấu hình | Mục đích |
|---|---|
| `acks=all` | Chờ tất cả replica cần thiết xác nhận |
| `retries > 0` | Tự động gửi lại khi lỗi tạm thời |
| `enable.idempotence=true` | Ngăn chặn message trùng lặp khi retry |

---

## 5.3. Rủi ro ở phía Broker

### 5.3.1. RAM nhanh nhưng có rủi ro

Kafka có thể ghi vào RAM/page cache trước rồi mới flush xuống đĩa sau. Điều này giúp nhanh, nhưng nếu sự cố xảy ra đúng lúc, dữ liệu chưa kịp bền vững có thể biến mất.

### 5.3.2. Rủi ro replication

Nếu leader chết trước khi follower kịp đồng bộ, message có thể bị mất nếu replica chưa đủ an toàn.

### 5.3.3. Cách giảm rủi ro

- Dùng **ít nhất 3 replica** cho partition quan trọng
- Cấu hình `min.insync.replicas`
- Theo dõi replica lag
- Kết hợp `acks=all`

---

## 5.4. Rủi ro ở phía Consumer

Consumer dùng **offset** như một dấu trang để biết mình đã đọc tới đâu.

### 5.4.1. Auto commit

Kafka tự động commit offset.

**Rủi ro:** offset đã tăng nhưng logic xử lý thật sự chưa xong, nếu ứng dụng chết thì message bị bỏ lỡ.

### 5.4.2. Manual commit

Chỉ commit offset khi xử lý thật sự hoàn tất.

### 5.4.3. Chiến lược thông minh

- Dùng async commit cho đường đi bình thường để tăng tốc
- Dùng sync commit trong tình huống lỗi quan trọng
- Dùng dead-letter queue cho message lỗi kéo dài

> **Lưu ý rất quan trọng:** Message có thể vẫn còn trong Kafka, nhưng **cơ hội xử lý message đó** có thể biến mất nếu quản lý offset sai. Đó cũng là một dạng mất dữ liệu ở cấp độ nghiệp vụ. fileciteturn3file0L67-L92

---

# 6. Khi một broker ngừng hoạt động thì chuyện gì xảy ra?

## 6.1. Tính sẵn sàng cao của Kafka

Kafka được xây dựng với triết lý:

- Chịu lỗi
- Tiếp tục hoạt động
- Tự phục hồi ở mức nhất định

HA không phải là tính năng gắn thêm, mà là một phần cốt lõi trong thiết kế.

---

## 6.2. Controller, Partition và ISR

### 6.2.1. Controller

Controller là thành phần điều phối các quyết định quản trị của cluster, ví dụ:

- Theo dõi broker sống/chết
- Kích hoạt bầu leader mới
- Điều phối phân vùng và metadata

### 6.2.2. ISR

**ISR (In-Sync Replicas)** là tập các replica đang đồng bộ tốt với leader và đủ điều kiện được bầu lên làm leader mới.

---

## 6.3. Failover diễn ra như thế nào?

1. Leader đang phục vụ bình thường
2. Broker chứa leader gặp sự cố
3. Controller phát hiện lỗi
4. Một follower trong ISR được bầu làm leader mới
5. Client tiếp tục làm việc với leader mới

### 6.3.1. Điều quan trọng

Không phải mọi follower đều đủ điều kiện như nhau.

Chỉ replica trong **ISR** mới được Kafka tin tưởng để lên làm leader.

---

## 6.4. KRaft và ZooKeeper

### 6.4.1. Kiến trúc cũ

Kafka trước đây dùng **ZooKeeper** bên ngoài để điều phối cluster.

### 6.4.2. Kiến trúc mới

Kafka hiện đại đang chuyển sang **KRaft**, tức là cơ chế metadata quorum tích hợp trực tiếp trong Kafka controller.

### 6.4.3. Lợi ích của KRaft

| Kiến trúc | Đặc điểm |
|---|---|
| ZooKeeper | Tách hệ điều phối ra ngoài, phức tạp hơn |
| KRaft | Tích hợp vào Kafka, đơn giản hơn và thường giảm độ trễ |

---

## 6.5. Khuyến nghị vận hành

### 6.5.1. Hạ tầng tối thiểu

| Hạng mục | Khuyến nghị | Lý do |
|---|---|---|
| Broker | Tối thiểu 3 | Đảm bảo quorum và HA |
| RAM | Đủ lớn | Tận dụng page cache |
| Mạng | Độ trễ thấp | Replication ổn định |
| Disk | Nhanh, ổn định | Bảo đảm throughput |

### 6.5.2. Chỉ số cần theo dõi

- ISR shrinkage
- Replica lag
- Controller re-election

> **Lưu ý:** Nếu ISR co lại thường xuyên, đó là dấu hiệu cluster đang gặp vấn đề về đồng bộ, I/O hoặc mạng. fileciteturn3file0L93-L120

---

# 7. Producer, Consumer, Offset và Partition

## 7.1. Producer: cân bằng giữa tốc độ và an toàn

### 7.1.1. So sánh cấu hình `acks`

| Cài đặt `acks` | Tốc độ | Rủi ro mất dữ liệu | Trường hợp sử dụng |
|---|---|---|---|
| `0` | Cao nhất | Cao | Dữ liệu không quan trọng |
| `1` | Cao | Thấp đến vừa | Logging thông lượng cao |
| `all` | Thấp hơn | Thấp nhất | Hệ thống quan trọng |

### 7.1.2. Cấu hình tăng hiệu quả

| Cấu hình | Vai trò |
|---|---|
| `linger.ms` | Chờ một chút để gom batch |
| `batch.size` | Kích thước batch |
| `compression.type` | Nén dữ liệu để giảm băng thông |

### 7.1.3. Retry và idempotence

Khi mạng không ổn định, kết hợp:

- `retries`
- `enable.idempotence=true`

sẽ giúp producer gửi lại mà không tạo message trùng lặp.

---

## 7.2. Consumer group và rebalancing

### 7.2.1. Rebalancing là gì?

Rebalancing là quá trình Kafka phân chia lại các partition của topic cho các consumer trong cùng group khi có thay đổi thành viên.

### 7.2.2. Cái giá của rebalancing

Trong quá trình rebalance:

- Toàn bộ group có thể tạm dừng xử lý
- Độ trễ tăng
- Hệ thống real-time có thể chịu ảnh hưởng

### 7.2.3. Giảm tác động với static membership

Gán `group.instance.id` cố định cho consumer để khi restart, Kafka không cần rebalance toàn diện.

---

## 7.3. Offset: dấu trang của dữ liệu

Offset giống như dấu trang trong một cuốn sách, đánh dấu vị trí consumer đã đọc tới.

### 7.3.1. Các chiến lược commit offset

| Chiến lược | Đặc điểm | Ưu điểm | Nhược điểm |
|---|---|---|---|
| Auto commit | Tự động | Đơn giản | Có thể mất hoặc trùng dữ liệu |
| Sync commit | Đồng bộ | An toàn hơn | Chậm hơn |
| Async commit | Bất đồng bộ | Nhanh | Xử lý lỗi khó hơn |
| Manual commit | Thủ công | Kiểm soát tối đa | Phức tạp hơn |

### 7.3.2. Các mức bảo đảm

| Mức bảo đảm | Ý nghĩa |
|---|---|
| At-most-once | Có thể mất dữ liệu, không trùng |
| At-least-once | Không mất dữ liệu, có thể trùng |
| Exactly-once | Không mất, không trùng, chi phí cao hơn |

---

## 7.4. Partition và thứ tự dữ liệu

Kafka chỉ đảm bảo thứ tự trong một partition.

### 7.4.1. Cách duy trì thứ tự

- Dùng key nhất quán cho các message liên quan
- Kafka sẽ đưa cùng key vào cùng partition
- Hạn chế thay đổi số lượng partition nếu thứ tự là yếu tố sống còn

> **Lưu ý:** Cấu hình partition ảnh hưởng trực tiếp đến thông lượng, độ an toàn và khả năng duy trì thứ tự của dòng dữ liệu. fileciteturn3file0L121-L153

---

# 8. Cấu trúc log nội bộ của Kafka

## 8.1. Append-Only Log

Nền tảng của Kafka là **chuỗi bản ghi tuần tự, bất biến**, tối ưu cho ghi và đọc tuần tự.

Kafka chỉ cho phép ghi vào cuối log:

- Không cập nhật giữa chừng như cơ sở dữ liệu quan hệ truyền thống
- Tối ưu cho throughput và độ bền

---

## 8.2. Tổ chức dữ liệu

Cấu trúc logic:

- **Topic**
  - **Partition**
    - **Segment**

### 8.2.1. Các file trong một segment

| File | Chức năng |
|---|---|
| `.log` | Chứa dữ liệu message |
| `.index` | Chỉ mục theo offset |
| `.timeindex` | Chỉ mục theo thời gian |

Offset đóng vai trò “sợi chỉ” kết nối tất cả các phần này lại với nhau.

---

## 8.3. Khi segment đầy thì sao?

Khi một segment đạt ngưỡng:

- Kafka đóng segment hiện tại
- Mở một segment mới để ghi tiếp

Sự bất biến này là nền tảng cho tính ổn định của hệ thống.

> **Lưu ý:** Trong Kafka không có lệnh `UPDATE` theo nghĩa truyền thống. Thực tế là **WRITE** và **DELETE** theo cơ chế retention/compaction.  

---

## 8.4. Retention policies

### 8.4.1. Giữ theo thời gian

Giữ dữ liệu trong một khoảng thời gian xác định, ví dụ 7 ngày.

### 8.4.2. Giữ theo dung lượng

Giới hạn tổng dung lượng log của một partition, khi vượt ngưỡng Kafka sẽ xóa dữ liệu cũ nhất.

### 8.4.3. Log compaction

Giữ lại giá trị cuối cùng cho mỗi key, rất phù hợp cho:

- Dữ liệu trạng thái
- Cache rebuild
- Event-sourced state

---

## 8.5. Tối ưu chi phí lưu trữ

| Cấu hình | Ưu điểm | Nhược điểm |
|---|---|---|
| Giữ lâu | Dễ replay, dễ phân tích | Tốn chi phí |
| Giữ ngắn | Tiết kiệm dung lượng | Rủi ro thiếu dữ liệu để xử lý lại |
| Segment lớn | Thông lượng tốt | Dọn dẹp kém linh hoạt |
| Segment nhỏ | Xóa nhanh, linh hoạt | Tăng chi phí quản lý |

> **Khuyến nghị khởi đầu:** Segment size khoảng **1 GB** thường là điểm cân bằng tốt giữa hiệu năng và quản trị. fileciteturn3file0L154-L177

---

# 9. Kafka Streams và xử lý dữ liệu thời gian thực

## 9.1. Tư duy cốt lõi

Nếu database là nơi dữ liệu “nằm yên”, thì **Kafka Streams** là nơi dữ liệu “sống” và được xử lý ngay khi xuất hiện.

---

## 9.2. Kafka Streams API

Kafka Streams cho phép:

- Filtering
- Mapping
- Joining
- Aggregation
- Windowing

### 9.2.1. Stream và Table

| Khái niệm | Ý nghĩa |
|---|---|
| Stream | Dòng sự kiện liên tục |
| Table | Trạng thái hiện tại rút ra từ stream |

---

## 9.3. ksqlDB

`ksqlDB` giúp truy vấn và xử lý dữ liệu real-time bằng cú pháp gần giống SQL, giúp nhiều bài toán streaming trở nên dễ tiếp cận hơn.

---

## 9.4. Ứng dụng tiêu biểu

- Data enrichment
- Real-time analytics
- Aggregation theo thời gian

> **Lưu ý:** Kafka không chỉ để lưu dữ liệu. Với Kafka Streams và ksqlDB, dữ liệu có thể được biến đổi và khai thác ngay trong lúc đang chảy. fileciteturn3file0L178-L189

---

# 10. Exactly-Once và Transactional Messaging

## 10.1. Bài toán toàn vẹn dữ liệu

| Mức bảo đảm | Ưu điểm | Nhược điểm |
|---|---|---|
| At-most-once | Nhanh, không trùng | Có thể mất dữ liệu |
| At-least-once | Không mất dữ liệu | Có thể trùng |
| Exactly-once | Không mất, không trùng | Độ trễ và chi phí cao hơn |

Kafka từ phiên bản 0.11 trở đi hỗ trợ cơ chế giúp đạt **Exactly-Once Semantics (EOS)** trong một số kịch bản.

---

## 10.2. Giao dịch Kafka

Kafka có thể hoạt động theo kiểu gần giống transaction của database.

### 10.2.1. Vòng đời transaction

1. `beginTransaction()`
2. `send(message)`
3. `commitTransaction()`
4. `abortTransaction()` nếu lỗi

---

## 10.3. Cấu hình Exactly-Once

### 10.3.1. Ở producer

| Cấu hình | Vai trò |
|---|---|
| `enable.idempotence=true` | Chống gửi trùng khi retry |
| `transactional.id` | Định danh giao dịch |

### 10.3.2. Ở consumer

| Cấu hình | Vai trò |
|---|---|
| `isolation.level=read_committed` | Chỉ đọc dữ liệu từ transaction đã commit |

---

## 10.4. Cái giá phải trả

Exactly-once không miễn phí:

- Tăng độ trễ
- Tăng tải xử lý ở broker
- Phát sinh thêm metadata giao dịch
- Tăng độ phức tạp vận hành

> **Khuyến nghị:**  
> - Nên dùng EOS khi độ chính xác là ưu tiên số một, ví dụ tài chính, ngân hàng.  
> - Không nhất thiết dùng EOS cho logging hoặc analytics nếu dữ liệu trùng lặp vẫn chấp nhận được. fileciteturn3file0L190-L215

---

# 11. CDC và Event Sourcing

## 11.1. Hai triết lý khác nhau

### 11.1.1. CDC

CDC giống như một người quan sát, ghi nhận sự thay đổi **sau khi** dữ liệu đã được ghi vào database.

### 11.1.2. Event Sourcing

Event Sourcing ghi lại **ý định và hành động** ngay tại thời điểm nó phát sinh.

---

## 11.2. CDC với Debezium

Debezium đọc trực tiếp transaction log của database rồi đẩy thay đổi vào Kafka.

### 11.2.1. Luồng dữ liệu

1. Database ghi thay đổi vào transaction log
2. Debezium đọc transaction log
3. Debezium publish sự kiện thay đổi vào Kafka topic
4. Consumer khác tiếp nhận và xử lý

### 11.2.2. Ưu điểm và hạn chế

| Tiêu chí | CDC |
|---|---|
| Ưu điểm | Không xâm lấn, hợp với hệ thống legacy |
| Hạn chế | Chỉ thấy kết quả sau commit, không phản ánh đầy đủ ý định nghiệp vụ |

---

## 11.3. Event Sourcing

Trong Event Sourcing, trạng thái ứng dụng được xác định bằng một chuỗi các sự kiện theo thời gian.

### 11.3.1. Kafka như Event Store

Kafka phù hợp để làm event store vì:

- Topic là log bất biến
- Có thể replay
- Có thể tái dựng trạng thái từ lịch sử sự kiện

### 11.3.2. Đánh đổi

Event Sourcing rất mạnh nhưng phức tạp hơn nhiều về thiết kế ứng dụng, mô hình hóa dữ liệu và cách suy nghĩ.

---

## 11.4. So sánh CDC và Event Sourcing

| Tiêu chí | CDC | Event Sourcing |
|---|---|---|
| Điểm bắt đầu | Sau khi DB ghi xong | Ngay khi hành động xảy ra |
| Dữ liệu lưu | Delta thay đổi | Toàn bộ sự kiện |
| Công cụ thường dùng | Debezium + Kafka | Kafka như Event Store |
| Thách thức | Phụ thuộc DB | Phức tạp trong thiết kế |

> **Kết luận:** CDC giúp hệ thống biết **khi nào dữ liệu thay đổi**; Event Sourcing giúp hệ thống hiểu **vì sao dữ liệu thay đổi**. fileciteturn3file0L216-L245

---

# 12. Bảo mật toàn diện trong Kafka

## 12.1. Ba trụ cột bảo mật

| Trụ cột | Câu hỏi trả lời |
|---|---|
| Xác thực | Bạn là ai? |
| Phân quyền | Bạn được làm gì? |
| Mã hóa | Dữ liệu có được bảo vệ không? |

---

## 12.2. Xác thực và phân quyền

### 12.2.1. Các cơ chế xác thực phổ biến

| Cơ chế | Mô tả |
|---|---|
| SSL/TLS với X.509 | Client và broker xác thực lẫn nhau |
| SASL/PLAIN | Đơn giản, thường nên kết hợp với TLS |
| SASL/SCRAM | An toàn hơn PLAIN |
| SASL/GSSAPI | Thường dùng với Kerberos trong môi trường doanh nghiệp |

### 12.2.2. ACLs

ACL định nghĩa quyền cụ thể cho user hoặc principal sau khi xác thực thành công, ví dụ:

- Read
- Write
- Create
- Delete
- Alter
- Describe

> **Lưu ý:** Không ai nên có quyền quản trị nếu họ không thực sự cần. Nguyên tắc **least privilege** rất quan trọng trong Kafka.  

---

## 12.3. Mã hóa toàn diện

### 12.3.1. In-transit encryption

Dùng SSL/TLS để bảo vệ dữ liệu trên đường truyền.

### 12.3.2. At-rest encryption

Mã hóa dữ liệu khi lưu trên đĩa để giảm rủi ro khi thiết bị lưu trữ bị lộ.

---

## 12.4. Checklist thực hành

1. Bật TLS để mã hóa traffic
2. Dùng cơ chế xác thực an toàn như SCRAM hoặc Kerberos khi phù hợp
3. Áp ACL nghiêm ngặt
4. Mã hóa dữ liệu lưu trữ khi cần
5. Xoay vòng chứng chỉ định kỳ

> **Kết luận:** Bảo mật không phải là một tham số cấu hình đơn lẻ. Đó là một **văn hóa vận hành an toàn**. fileciteturn3file0L246-L263

---

# 13. Scaling và Performance Tuning

## 13.1. Partition: chìa khóa xử lý song song

Partition là đơn vị song song cơ bản của topic Kafka.

### 13.1.1. Gợi ý khởi đầu

- Có thể bắt đầu với quy tắc thực dụng: **1 partition cho mỗi ~1 MB/s thông lượng**
- Tăng dần khi consumer bị trễ hoặc broker quá tải

### 13.1.2. Thực hành tốt

- Dùng partition key như `user_id` để duy trì thứ tự
- Có thể dùng custom partitioner để phân phối đều hơn

> **Lưu ý:** Một partition là đơn vị tạo tốc độ, nhưng cũng có thể là đơn vị tạo hỗn loạn nếu không được thiết kế cẩn thận.

---

## 13.2. Tối ưu Producer

| Cấu hình | Mục đích | Giá trị đề xuất ban đầu |
|---|---|---|
| `batch.size` | Kích thước lô dữ liệu | 32 KB – 64 KB |
| `linger.ms` | Chờ gom batch | 5 – 20 ms |
| `compression.type` | Giảm kích thước dữ liệu | `lz4` hoặc `zstd` |
| `acks` | Độ tin cậy ghi | `1` hoặc `all` |
| `max.in.flight.requests.per.connection` | Số request song song | 5 – 10 |

### 13.2.1. Mẹo cho producer

- Bật idempotence để tránh trùng lặp khi retry
- Dùng gửi bất đồng bộ `send()`
- Theo dõi `RecordSendRate` và `RequestLatencyAvg`

---

## 13.3. Tăng tốc Consumer

### 13.3.1. Quy tắc cơ bản

Số lượng consumer hữu ích trong một group **không nên vượt quá số partition**, vì consumer dư sẽ không có partition nào để đọc.

### 13.3.2. Cách tăng thông lượng

1. Tăng số partition
2. Tăng số lượng consumer trong cùng group
3. Tách logic xử lý nặng ra luồng hoặc hệ xử lý riêng

---

## 13.4. Nền tảng hạ tầng

| Hạng mục | Khuyến nghị |
|---|---|
| Broker | Bắt đầu với 3 broker để có HA |
| Disk | SSD hoặc NVMe |
| Mạng | 10–25 Gbps cho cluster lớn |
| Replication | Factor = 3 là điểm cân bằng tốt |
| Giám sát | Theo dõi `UnderReplicatedPartitions`, `RequestLatency` |

> **Lưu ý:** Khi tuning Kafka, hãy tối ưu theo **nút thắt cổ chai thực sự**: producer, consumer, broker, disk hay network. Không nên tối ưu theo cảm tính. fileciteturn3file0L264-L289

---

# 14. Vận hành Kafka trong thực tế

## 14.1. Mô hình triển khai

| Mô hình | Ưu điểm | Nhược điểm |
|---|---|---|
| Bare-metal / on-prem | Kiểm soát cao | Quản trị phức tạp |
| Cloud managed | Dễ mở rộng, nhanh đưa vào sử dụng | Chi phí có thể cao hơn |

> **Mục tiêu thực tế:** Nếu sản phẩm cần ra thị trường nhanh, dịch vụ managed thường là lựa chọn tốt hơn.

---

## 14.2. Nâng cấp không gián đoạn

### 14.2.1. Rolling Upgrade

1. Dừng một broker
2. Nâng cấp binary hoặc config
3. Khởi động lại broker và kiểm tra
4. Lặp lại cho các broker còn lại

> **Lưu ý quan trọng:** Nâng cấp cuốn chiếu là cách giữ hệ thống “sống” trong khi vẫn thay đổi dần.

---

## 14.3. Phục hồi sau thảm họa

### 14.3.1. Geo-replication

Sao chép dữ liệu giữa các cluster ở những vị trí địa lý khác nhau để tăng khả năng phục hồi thảm họa.

### 14.3.2. Công cụ phổ biến

| Công cụ | Loại | Use case |
|---|---|---|
| MirrorMaker 2.0 | Apache Kafka | Replicate topic |
| Confluent Replicator | Enterprise | DR nâng cao, đồng bộ ACL |

---

## 14.4. Backup và di chuyển dữ liệu

Các chiến lược thường thấy:

- Sao lưu log ra đĩa hoặc object storage như S3
- Snapshot metadata
- Lập kế hoạch restore định kỳ
- Tập dượt migration

---

## 14.5. Quy tắc vận hành vàng

1. Theo dõi các chỉ số quan trọng
2. Kiểm tra compatibility trước khi upgrade
3. Có ít nhất một phương án DR
4. Tự động hóa deployment
5. Diễn tập failover định kỳ

> **Lưu ý:** Điều khiến một cụm Kafka mạnh không chỉ là cấu hình đẹp, mà là khả năng được kiểm chứng qua các buổi diễn tập lỗi thật. fileciteturn3file0L290-L312

---

# 15. Kafka trong kiến trúc microservices

## 15.1. Đồng bộ vs bất đồng bộ

### 15.1.1. Giao tiếp đồng bộ

Ví dụ: Service A gọi HTTP sang Service B và phải chờ trả lời.

Ưu điểm:

- Dễ hiểu
- Dễ debug ban đầu

Nhược điểm:

- Phụ thuộc chặt
- Dễ gây nghẽn chuỗi gọi
- Khó mở rộng

### 15.1.2. Giao tiếp bất đồng bộ với Kafka

Service A phát event vào Kafka, các service khác sẽ xử lý khi sẵn sàng.

Ưu điểm:

- Linh hoạt hơn
- Tách rời hơn
- Dễ mở rộng hơn

---

## 15.2. Event-driven architecture

Các service giao tiếp bằng cách phát và tiêu thụ sự kiện mà không cần biết trực tiếp về nhau.

---

## 15.3. Saga pattern

Kafka rất phù hợp để hiện thực Saga trong hệ thống phân tán.

### 15.3.1. Hai mô hình chính

| Mô hình | Cách hoạt động | Ưu điểm | Nhược điểm |
|---|---|---|---|
| Choreography | Service phát event kích hoạt service kế tiếp | Đơn giản, không có điều phối viên | Khó theo dõi luồng phức tạp |
| Orchestration | Có điều phối viên trung tâm ra lệnh | Dễ quản lý, logic rõ ràng | Phụ thuộc vào điều phối viên |

Nếu một bước thất bại, hệ thống có thể phát sự kiện bù hoàn để đảo ngược các bước trước đó.

---

## 15.4. Schema: hợp đồng dữ liệu

Schema không chỉ là cấu trúc dữ liệu, mà là hợp đồng tin cậy giữa các đội.

### 15.4.1. Vai trò của Schema Registry

Schema Registry giống như một “thủ thư quản lý phiên bản”, giúp:

- Kiểm soát tương thích dữ liệu
- Hỗ trợ tiến hóa schema
- Giảm rủi ro service cũ không hiểu message mới

---

## 15.5. Thiết kế message an toàn

### 15.5.1. Sự kiện và lệnh

| Loại | Đặc điểm |
|---|---|
| Event | Mô tả điều gì đó đã xảy ra |
| Command | Yêu cầu điều gì đó nên được làm |

### 15.5.2. Idempotency

Idempotency là khả năng xử lý lặp lại nhiều lần mà không làm thay đổi kết quả cuối cùng.

Một kỹ thuật phổ biến là:

- Lưu lại `event_id`
- Trước khi xử lý event mới, kiểm tra xem ID đó đã được xử lý chưa
- Nếu đã xử lý rồi thì bỏ qua

> **Lưu ý quan trọng:** Trong microservices, Kafka giúp tách rời hệ thống, nhưng chính idempotency, schema compatibility và saga design mới quyết định hệ thống có thực sự an toàn hay không. fileciteturn3file0L313-L332

---

# 16. Tóm tắt nhanh các nguyên tắc vàng

## 16.1. Nguyên tắc kiến trúc

- Dùng partition để mở rộng song song
- Dùng replication để tăng độ bền
- Dùng consumer group để chia tải
- Dùng key nhất quán để giữ thứ tự trong phạm vi cần thiết

## 16.2. Nguyên tắc an toàn dữ liệu

- `acks=all`
- `min.insync.replicas` hợp lý
- `enable.idempotence=true`
- Manual commit hoặc commit có kiểm soát
- Dùng dead-letter queue khi cần

## 16.3. Nguyên tắc hiệu năng

- Tận dụng batch
- Dùng nén
- Theo dõi disk I/O và network
- Dùng SSD/NVMe cho workload nặng
- Chỉ tăng partition khi thật sự cần

## 16.4. Nguyên tắc vận hành

- Tối thiểu 3 broker cho HA
- Theo dõi ISR, replica lag, latency
- Diễn tập failover định kỳ
- Chuẩn bị DR và backup
- Nâng cấp theo rolling upgrade

## 16.5. Nguyên tắc bảo mật

- Bật TLS khi cần bảo vệ traffic
- Xác thực bằng SASL/SCRAM hoặc cơ chế phù hợp
- Áp ACL theo nguyên tắc ít quyền nhất
- Quản lý chứng chỉ và bí mật nghiêm ngặt

---

# 17. Kết luận

Kafka mạnh vì nó kết hợp được nhiều yếu tố tưởng như mâu thuẫn:

- Nhanh nhưng vẫn bền
- Linh hoạt nhưng vẫn có cấu trúc
- Mở rộng lớn nhưng vẫn kiểm soát được
- Phù hợp cả hạ tầng dữ liệu lẫn microservices

Tuy nhiên, Kafka **không tự động an toàn chỉ vì được cài lên**.  
Giá trị thật của Kafka chỉ xuất hiện khi người vận hành hiểu rõ:

- Cơ chế log
- Replication
- Offset
- Partition
- Bảo mật
- Tuning
- Failover
- Quy trình vận hành thực chiến

> **Thông điệp cuối:** Kafka không chỉ là công cụ truyền message. Kafka là một **nền tảng dữ liệu thời gian thực** và là một **triết lý thiết kế hệ thống phân tán**.

