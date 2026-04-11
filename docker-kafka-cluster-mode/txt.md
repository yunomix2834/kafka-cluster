Được, tôi sẽ bóc tách lại theo kiểu **“mình đang làm cái gì, tại sao phải làm vậy, và nếu bỏ bước đó thì hỏng ở đâu”**.

Trước hết, bức tranh hiện tại của node bạn gửi là:

* dữ liệu Kafka đang nằm ở **host path** `/var/lib/kafka/data`, tức là dữ liệu không nằm “bên trong container” mà nằm ngoài host bind mount; vì vậy đổi container **không tự động mất data** nếu vẫn mount lại đúng thư mục này. 
* container cũ đang chạy với listener `CONTROLLER://:9093` và `SASL_PLAINTEXT://:9092`, đồng thời `advertised.listeners` cũng đang là `SASL_PLAINTEXT://10.60.68.242:9092`. Tức là hiện trạng cũ của bạn chưa có external SSL riêng.

Bây giờ tôi giải thích script hôm trước theo đúng “mạch suy nghĩ”.

---

## 1) Mục tiêu thật sự của cả bài này là gì?

Mục tiêu không phải chỉ là “thêm SSL”.

Mục tiêu là đổi từ mô hình cũ:

* nội bộ cluster dùng `SASL_PLAINTEXT`
* chưa có cổng SSL riêng cho client ngoài

sang mô hình mới:

* `BROKER://9092` dùng cho broker ↔ broker, để `PLAINTEXT`
* `CONTROLLER://9093` dùng cho KRaft controller quorum, để `PLAINTEXT`
* `EXTERNAL://9094` dùng cho client bên ngoài, để `SSL`

Nói dễ hiểu hơn:

* **bên trong cụm**: 3 broker nói chuyện với nhau bằng kênh nội bộ
* **bên ngoài cụm**: app/client kết nối vào bằng TLS/SSL

Tức là mình **không bật SSL cho mọi thứ**, mà chỉ bật cho “cửa ngoài”.

---

## 2) Vì sao tôi không cho stop container ngay từ đầu?

Vì nếu stop từ đầu, rồi mới đi tạo cert, ký cert, copy cert, convert cert… thì cluster của bạn sẽ nằm chết trong lúc mình còn đang loay hoay với giấy tờ TLS.

Nên thứ tự an toàn hơn là:

1. chuẩn bị toàn bộ cert trước
2. chép cert sang 3 server trước
3. convert xong JKS trước
4. đến đúng maintenance window mới stop container cũ và chạy container mới

Hiểu như thế này:

* cert giống như “chìa khóa và giấy tờ”
* container mới giống như “ngôi nhà mới”

Bạn không nên đập nhà cũ trước khi chìa khóa nhà mới còn chưa làm xong.

---

## 3) Vì sao phải có **1 CA** ở bastion?

CA là “người ký giấy chứng nhận”.

Nếu không có CA, mỗi broker chỉ có self-signed cert của riêng nó. Khi đó:

* broker có thể tự tin vào chính nó
* nhưng client hoặc broker khác sẽ không tin cert đó một cách chuẩn chỉnh

Nên mình tạo:

* **1 CA chung** ở bastion
* rồi dùng CA này ký cert cho `kafka-0`, `kafka-1`, `kafka-2`

Hình dung:

* CA = công an cấp CCCD
* broker cert = CCCD của từng người
* client/truststore = nơi kiểm tra “CCCD này do đúng cơ quan phát hành không?”

Nếu không có CA chung, mỗi người tự in CCCD ở nhà thì bên kia không tin.

---

## 4) Tại sao gen CA ở bastion mà không gen ở từng broker?

Vì CA là “gốc tin cậy”.

Nó nên nằm ở một chỗ quản trị tập trung hơn, tách khỏi broker runtime. Bastion hợp lý vì:

* bạn thao tác SSH qua đó
* dễ lưu trữ material gốc
* dễ ký cho nhiều node

Nói đơn giản:

* broker là “máy chạy dịch vụ”
* bastion là “máy quản trị”

Mình không muốn private key CA nằm lung tung trên 3 broker.

---

## 5) Tại sao script trên bastion lại tạo ra 3 bộ cert khác nhau?

Vì mỗi broker phải có danh tính riêng.

Cụ thể:

* `kafka-0` có cert riêng cho `10.60.68.211`
* `kafka-1` có cert riêng cho `10.60.68.242`
* `kafka-2` có cert riêng cho `10.60.68.32`

Tại sao không dùng chung một cert cho cả 3?

Vì nếu dùng chung:

* khó quản lý
* khó revoke
* không phản ánh đúng hostname/IP của từng node
* hostname verification dễ lỗi

Mỗi broker là một “server identity” riêng, nên nó phải có:

* private key riêng
* cert riêng
* SAN riêng

---

## 6) SAN là gì, tại sao tôi nhấn rất mạnh bước này?

SAN là danh sách tên/IP mà cert được phép đại diện.

Ví dụ với `kafka-1`, tôi cho:

* `IP:10.60.68.242`
* `DNS:kafka-1`

Điều đó có nghĩa:

* nếu client kết nối tới `10.60.68.242:9094`, cert hợp lệ
* nếu client kết nối tới hostname `kafka-1`, cert cũng hợp lệ

Nếu cert không chứa SAN khớp địa chỉ client đang dùng, sẽ xảy ra kiểu lỗi:

* certificate hostname mismatch
* SSL handshake fail
* client thấy cert “không phải của máy này”

Hình dung thế này:

* bạn đang gọi tới số nhà `10.60.68.242`
* nhưng CCCD trên cửa lại ghi tên khác
* hệ thống sẽ nghi ngờ

Nên SAN là bước cực quan trọng.

---

## 7) Tại sao tôi tạo `.key`, `.csr`, `.crt`, rồi còn đóng gói `.p12`?

Mỗi file có vai trò khác nhau.

### `ca.key`

Khóa bí mật của CA.
Đây là thứ quan trọng nhất của “cơ quan cấp phát”.

### `ca.crt`

Chứng chỉ công khai của CA.
Đây là thứ mình phát cho người khác để họ tin vào cert do CA ký.

### `kafka-1.key`

Private key riêng của broker `kafka-1`.

### `kafka-1.csr`

Certificate Signing Request.
Đây là “đơn xin cấp chứng chỉ”, nói rằng:

* tôi là broker này
* đây là public key của tôi
* xin CA ký giúp

### `kafka-1.crt`

Cert đã được CA ký cho broker `kafka-1`.

### `kafka-1.p12`

Đây là gói đóng chung:

* private key của broker
* cert của broker
* chain CA

Vì sao phải đóng thành `.p12`?

Vì từ bastion sang server, `.p12` rất tiện để mang đi như một “hồ sơ hoàn chỉnh” rồi mới import vào Java keystore.

---

## 8) Tại sao bastion dùng OpenSSL, còn server lại convert sang JKS?

Vì có hai thế giới ở đây:

### Thế giới OpenSSL

Trên bastion, tiện nhất là dùng OpenSSL để:

* tạo CA
* tạo key
* tạo CSR
* ký cert
* đóng gói PKCS12

### Thế giới Java/Kafka

Kafka chạy trên JVM.
Bitnami Kafka hỗ trợ JKS rất tự nhiên.

Nên flow là:

* bastion: dùng OpenSSL làm cert
* server: convert sang JKS để Kafka dùng

Nói cách khác:

* OpenSSL là xưởng làm giấy tờ
* JKS là định dạng tủ hồ sơ mà Kafka thích mở

---

## 9) Tại sao trên server tôi lại tạo **2 file**: keystore và truststore?

Đây là đoạn rất nhiều người hay nhầm.

### Keystore

Keystore là nơi broker giữ:

* private key của chính nó
* cert của chính nó

Tức là: “đây là danh tính của tôi”.

### Truststore

Truststore là nơi broker giữ:

* cert CA mà nó tin

Tức là: “tôi tin CA này”.

Hiểu đơn giản:

* keystore = ví đựng CCCD của chính mình
* truststore = danh sách cơ quan nhà nước mà mình chấp nhận

Nếu chỉ có keystore mà không có truststore, broker/client có thể không biết nên tin CA nào.

---

## 10) Tại sao tôi copy `ca.crt` sang cả 3 server?

Vì cả 3 server đều phải biết:

* “CA nào là CA mà cụm này tin”

`ca.crt` chính là gốc niềm tin chung.

Nó được import vào truststore để:

* broker tin cert do CA này ký
* client cũng có thể tin broker nếu client import cùng CA đó

---

## 11) Tại sao trong script convert sang JKS, tôi dùng `keytool -importkeystore` từ `.p12`?

Vì `.p12` là định dạng trung gian rất tiện để đem đi giữa môi trường OpenSSL và Java.

Script đó thực chất đang nói:

* “hãy mở cái gói PKCS12 này”
* “lấy key + cert bên trong”
* “đổ vào Java keystore JKS”

Nó không tạo danh tính mới.
Nó chỉ **chuyển định dạng**.

---

## 12) Tại sao sau đó tôi lại import `ca.crt` vào truststore?

Vì keystore và truststore phục vụ hai mục tiêu khác nhau.

Bước đó nghĩa là:

* broker sẽ tin mọi cert được CA này ký

Nếu sau này external client cũng dùng cùng CA, chuyện verify sẽ rất mượt.

---

## 13) Tại sao tôi kiểm tra keystore sau khi tạo?

Vì “script chạy xong” chưa chắc đã đúng.

Ví dụ có thể gặp:

* alias sai
* file tạo ra rỗng
* import nhầm cert
* truststore chưa có CA
* SAN thiếu

Nên bước `keytool -list` là để kiểm tra:

* file có thật không
* alias có đúng không
* cert có nằm trong keystore không

Giống như sau khi in hồ sơ xong, mình mở ra xem có đóng dấu chưa.

---

## 14) Tại sao đến lúc cutover tôi mới stop container?

Vì trước đó mình mới chỉ chuẩn bị vật liệu.

Đến phase cutover, lúc này mình đã có:

* CA xong
* cert cho cả 3 broker xong
* file `.p12` xong
* `kafka.keystore.jks` và `kafka.truststore.jks` trên từng server xong

Lúc đó stop mới an toàn, vì khoảng downtime ngắn hơn rất nhiều.

---

## 15) Tại sao tôi bảo backup trước khi rename và stop?

Trong script cutover, phần backup có 2 thứ:

### `docker inspect database > ...`

Mục đích là giữ lại:

* env cũ
* mount cũ
* port cũ
* image cũ

Nếu rollback hoặc đối chiếu, file inspect này cực kỳ giá trị.

### `cp -a /var/lib/kafka/data ...`

Mục đích là giữ snapshot data tại thời điểm dừng.

Cần phân biệt:

* dữ liệu chính vẫn đang ở `/var/lib/kafka/data`
* bản `cp -a` là một **bản sao an toàn**

Tại sao làm sau khi `docker stop`?

Vì như vậy data ổn định hơn, tránh copy lúc Kafka vẫn đang ghi.

---

## 16) Tại sao tôi dùng `docker rename` container cũ thay vì xóa ngay?

Vì rename cho bạn rollback cực nhanh.

Ví dụ:

* container cũ tên `database`
* sau rename thành `database-old-...`

lúc đó bạn có:

* container cũ vẫn còn nguyên metadata
* data host path vẫn còn nguyên
* có thể dựng container mới cùng tên `database`

Nếu container mới fail:

* stop container mới
* xóa container mới
* rename container cũ lại về `database`
* start lên

Rất nhanh.

Nếu rm ngay từ đầu, rollback mệt hơn nhiều.

---

## 17) Tại sao tôi nói phải rollout **cả 3 node cùng một maintenance window**?

Vì hiện trạng cũ của bạn đang là:

* `SASL_PLAINTEXT` cho nội bộ cluster
* JAAS đang được mount vào container cũ
* inter-broker protocol hiện tại cũng là `SASL_PLAINTEXT`

Còn cấu hình mới tôi đưa là:

* `BROKER` = `PLAINTEXT`
* `CONTROLLER` = `PLAINTEXT`
* `EXTERNAL` = `SSL`

Tức là bạn đang đổi **không chỉ external**, mà còn đổi luôn **cách broker nói chuyện nội bộ**.

Nếu chỉ đổi 1 node trước:

* node mới nói kiểu A
* 2 node cũ nói kiểu B

rất dễ không join cluster đúng.

Nên phải đổi cả 3 gần như cùng lúc.

---

## 18) Tại sao container mới lại mount lại `/var/lib/kafka/data`?

Vì đó là thư mục dữ liệu cũ của Kafka trên host.

Khi container mới mount lại đúng path đó, nó sẽ nhìn thấy:

* log segment cũ
* metadata cũ
* state cũ

Nói dễ hiểu:

* container là “vỏ chạy”
* `/var/lib/kafka/data` mới là “kho hàng thật”

Đổi vỏ nhưng giữ nguyên kho.

---

## 19) Tại sao container mới không còn mount JAAS cũ?

Vì cấu hình mới của tôi đang đi theo hướng:

* external = `SSL`
* không còn dùng `SASL_PLAINTEXT` nội bộ nữa

Nghĩa là logic auth kiểu JAAS/SASL cũ không còn là trọng tâm trong bản cutover đó.

Nhưng chỗ này có một nuance rất quan trọng:

* `SSL` chỉ lo **mã hóa**
* `SASL` lo **xác thực bằng user/password**

Nếu bạn vẫn cần client ngoài cluster login bằng username/password, thì external đúng ra nên là:

* `SASL_SSL`

chứ không phải `SSL` thuần.

Đây là lý do tôi đã nói trước đó: script hiện tại đang đổi external sang “TLS-only”, không phải “TLS + user/pass”.

---

## 20) Tại sao trong `docker run` mới lại có các biến listener mới?

Đây là phần lõi nhất.

### `KAFKA_CFG_LISTENERS=BROKER://:9092,CONTROLLER://:9093,EXTERNAL://:9094`

Câu này nghĩa là broker mở 3 cổng logic:

* 9092 cho broker nội bộ
* 9093 cho controller quorum
* 9094 cho client ngoài

### `KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=BROKER:PLAINTEXT,CONTROLLER:PLAINTEXT,EXTERNAL:SSL`

Câu này nghĩa là:

* listener tên `BROKER` dùng protocol `PLAINTEXT`
* listener tên `CONTROLLER` dùng protocol `PLAINTEXT`
* listener tên `EXTERNAL` dùng protocol `SSL`

### `KAFKA_CFG_INTER_BROKER_LISTENER_NAME=BROKER`

Câu này nghĩa là:
“khi broker trong cluster nói chuyện với nhau, dùng listener tên `BROKER`”

### `KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER`

Câu này nghĩa là:
“khi controller quorum hoạt động, dùng listener tên `CONTROLLER`”

### `KAFKA_CFG_ADVERTISED_LISTENERS=...`

Câu này là địa chỉ mà broker công bố cho nơi khác biết để kết nối tới nó.

Nói dễ hiểu:

* `listeners` = mở cửa trong nhà
* `advertised.listeners` = ghi địa chỉ nhà gửi cho người khác

Nếu ghi sai advertised listeners, client sẽ nhận “địa chỉ giả” rồi connect fail.

---

## 21) Tại sao external listener dùng port 9094 mà không dùng 9092 luôn?

Vì tách riêng ra thì:

* dễ hiểu
* dễ firewall
* dễ debug
* dễ biết cổng nào là internal, cổng nào là external
* tránh đụng với cổng nội bộ đang dùng

Nó cũng phản ánh đúng ý đồ kiến trúc:

* 9092 = chuyện trong nhà
* 9094 = cửa tiếp khách

---

## 22) Tại sao verify sau rollout lại có nhiều bước?

Vì rollout xong chưa có nghĩa là mọi thứ ổn.

Tôi kiểm tra theo 3 lớp:

### Lớp 1: process/container

* `docker ps`
* `docker logs`

để biết container có chạy không, có lỗi syntax/env không

### Lớp 2: port/network

* `ss -ltnp`

để biết host có đang listen đúng `9092/9093/9094` không

### Lớp 3: TLS

* `openssl s_client -connect ...:9094`

để biết external SSL có thật sự lên không, cert trình ra là cert nào, issuer là ai

Nếu chỉ nhìn `docker ps` mà không nhìn `openssl s_client`, bạn có thể tưởng SSL đã lên nhưng thật ra external port chưa đúng.

---

## 23) Rollback hoạt động như thế nào?

Rollback logic rất đơn giản:

* container mới lỗi
* stop container mới
* rm container mới
* rename container cũ lại
* start container cũ lại

Điểm làm rollback nhanh chính là vì:

* container cũ chưa bị xóa
* data path cũ vẫn còn
* inspect backup vẫn còn

Tức là mình luôn chừa đường lui.

---

## 24) Tóm tắt cả câu chuyện bằng hình ảnh rất đời thường

Hãy tưởng tượng bạn đang sửa một tòa nhà 3 cửa:

* cửa nội bộ nhân viên
* cửa ban quản lý
* cửa tiếp khách

Hệ thống cũ của bạn là:

* nhân viên đi cửa A
* quản lý đi cửa B
* khách ngoài vẫn đi kiểu cũ chưa có bảo vệ SSL

Việc script làm là:

### Giai đoạn chuẩn bị giấy tờ

* bastion tạo “cơ quan cấp giấy”
* cấp giấy riêng cho từng cửa hàng/broker
* đóng gói giấy tờ đem sang từng nơi

### Giai đoạn lắp khóa

* trên từng server, đổi giấy tờ sang định dạng Kafka đọc được
* chuẩn bị xong hết nhưng chưa đổi cửa

### Giai đoạn cắt chuyển

* dừng hoạt động ngắn
* giữ lại nhà cũ để rollback
* dựng nhà mới với:

  * cửa nội bộ giữ đơn giản
  * cửa ngoài có ổ khóa SSL

### Giai đoạn nghiệm thu

* xem nhà mới có mở đúng cửa không
* xem khách vào cửa SSL có thấy đúng giấy tờ không
* nếu lỗi thì quay lại nhà cũ

---

## 25) Nếu nói cực ngắn, 6 bước chính của script là gì?

1. **Đọc hiện trạng** để biết data đang ở đâu, listener cũ là gì. Node bạn gửi đang dùng `/var/lib/kafka/data`, `CONTROLLER://:9093`, `SASL_PLAINTEXT://:9092`.
2. **Tạo CA trên bastion** để có một nguồn tin cậy chung.
3. **Tạo cert riêng cho từng broker** vì mỗi node phải có danh tính riêng.
4. **Copy cert sang từng server và convert thành JKS** vì Kafka/Bitnami dùng JKS rất thuận.
5. **Cutover an toàn**: backup, rename container cũ, stop, rồi chạy container mới mount lại đúng data cũ.
6. **Verify và rollback nếu cần**.

---

## 26) Chỗ nào là khó hiểu nhất với đa số mọi người?

Thường là 4 chỗ này:

### “Tại sao đổi container mà không mất data?”

Vì data nằm ở host path `/var/lib/kafka/data`, không nằm trong container. 

### “Tại sao phải có cả keystore lẫn truststore?”

Keystore là “tôi là ai”. Truststore là “tôi tin ai”.

### “Tại sao phải làm trên cả 3 node?”

Vì bạn đang đổi protocol nội bộ cluster, không chỉ đổi external.

### “Tại sao phải tạo CA rồi mới tạo cert broker?”

Vì broker cert phải được một nguồn tin cậy chung ký.

---

Nếu bạn muốn, lượt tiếp theo tôi sẽ làm tiếp một việc rất thực dụng: tôi sẽ **vẽ lại toàn bộ luồng này dưới dạng sơ đồ ASCII từng bước**, kiểu:

`bastion -> tạo CA -> tạo cert kafka-0 -> copy sang node-0 -> convert JKS -> cutover`

để bạn nhìn một phát là hiểu ngay.
