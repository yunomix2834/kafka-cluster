Kafka là gì
- là nên tảng lưu trữ, xử lý sự kiện phân tán -> sinh ra để thu thập, lưu trữ, xử lý dữ liệu khổng lồ tại thời gian thực
- hệ thống kinh trung ương phức tạp trong dịch vụ giúp các dịch vụ có thể nói chuyện được với nhau trong một hệ thống phức tạp -> thông qua dòng chảy dữ liệu nhanh, tin cậy, khả năng mở rộng gần như vô 


Message & Topic
- Message -> đơn vị nhỏ nhất trong Kafka, tương tự như một bản ghi trong cơ sở dữ liệu. Một message sẽ có 1 key để định danh, value để chứa thông tin và header để mang các thông tin
-> Nếu hệ thống là một dòng máu thì message là tế bào dữ liệu - nhỏ bé nhưng mang thông tin sống 

Topic
- Một danh mục hoặc thư mục được đặt tên để tổ chức và lưu trữ các message

Hành trình dữ liệu
- Một hệ thống bên (Producer) sẽ tạo 1 message mới -> sẽ gửi message vào Topic cụ thể (cũng giống như lưu 1 tệp vào đúng thư mục)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Partition
- Câu hỏi làm thế nào để Kafka xử lý hàng triệu message mà không bị "nghẹt" -> Partition
- Mỗi Topic được chia thành nhiều partition -> xử lý song song

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Xử lý rất nhiều producer, hỗ trợ nhiều consumer, dữ liệu được thiết kế lưu trên đĩa, thiết kế để mở rộng theo chiều ngang 

Producer: tạo các message, gộp chúng lại và gửi đến topic -> mỗi topic được chia thành nhiều partition -> partition được phân tán trên nhiều cụm máy chủ (broker)
-> gộp các tin nhắn lại -> giảm tải qua các mạng
-> tự động cân bằng tải qua các partition

Consumer: đọc tin nhắn từ Producer. Tập hợp lại thành các consumer group. Đọc tin nhắn từ 1 hoặc nhiều partition khác nhau
-> Không trùng lặp, mỗi tin nhắn được xử lý chính xác 1 lần, không xót

Cluster: một nhóm các máy chủ (broker) làm việc cùng với nhau. Mỗi broker giữ 1 hần dữ liệu -> cùng với nhau và phối hợp để cung cấp khả năng dự phòng
-> Các partition không chỉ được phân tán mà còn được replicate qua các partition khác nhau
-> Một máy chủ gặp sự cô -> hệ thống vẫn tiếp tục chạy mà không mất dữ liệu

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Vid 3

Kafka có thể xử lý hàng triệu tin nhắn mỗi giây ?
2 trụ cột hiệu năng

- Sequential I/O (ghi tuần tự)
-> với cách ghi ngẫu nhiên, đầu đọc ổ cứng sẽ liên tục di chuyên giống hệt thủ thư một thư viện chạy khắp thư viện để cất 
-> ghi tuần tự: ghi nối tiếp vào các file -> đọc đầu của ổ cứng không cần nhảy lung tung nữa -> tối ưu hóa tốc độ phần cứng

- Zero copy (Không sao chép trung gian)
-> khi mà sao chép dữ liệu từ vùng nhớ này sang vùng nhớ khác -> cpu lại phải làm việc. Và chỉ cần độ trễ vài ms mà cộng dồn lại -> lớn. dữ liệu phải liên tục qua lại 2 không gian riêng biêt: không gian của hệ điều hành (Kernel context) và không gian của Kafka (Application context). Co 4 lan sao chep khong hieu qua:
Buoc 1:  Dia sang bo dem HDH -> Buoc 2: HDH sang bo dem App -> Buoc 3: app sang bo dem socket -> Buoc 4: socket sang card mang
-> Voi zero copy: hdh gui du lieu truc tiep tu bo dem dia den thang card mang. Lenh he thong sendfile(): lenh he tho cho phep du lieu duoc chuyen truc tiep giua 2 file trong kernel, bo qua ung dung

tieu chi | khong co zero copy | co zero copy
sao chep | nhieu lan (OS & App) | Truc tiep (Dia -> Mang)
ket qua | cpu tai cao, tre lon | nhanh hon, it ganh nang

-> it hon la nhieu hon
ghi tuan tu (giam thoi gian tim kiem cua dia) -> struyen du lieu truc tiep (giam tai cho CPU) --> cuc ky hieu qua

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Vid 4 

1. xu ly & phan tich log: ung dung nen tang -> Log tu cac microservice duoc tap trung qua Kafka de phan tich
Observability, Log streaming, centralized logging
2. luong du lieu goi y: Moi hanh vi cua nguoi dung -> tat ca deu dc ghi lai thanh 1 luong su kien -> do vao kafka -> duoc xu ly nhu Flink -> mom cho cac du lieu hoc may
3. giam sat, canh bao he thong: moi dich vu trong he thong se lien tuc bao cao cac chi so va hieu nang cho Kafka -> day sang Flink de phan tich -> neu co bat thuong thi canh bao som
4. bat thay doi du lieu: Change Data Capture
-> thay doi o nguon: moi thay doi xay ra trong co so du lieu nguon -> kafka bat su kien: kafka bat thay doi nay tu transaction log -> truyen di: su kien thay doi duoc truyen den nhieu he thong dich -> cap nhat tuc thi: tat ca cac he thong duoc cap nhat theo thoi gian thuc
-> dam bao moi thay doi duoc dong bo tren toan he sinh thai
5. di chuyen he thong: nang cap an toan: he thong cu co the gui toan bo du lieu vao kafka -> he thong moi cu tu tu lay du lieu tu trong kafka ra. Ca 2 co the chay song song va khong giam chan len nhau ->


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Vid 5

- Kafka co that su khong bao gio mat message khong ?
- Shaky cluster -> Fortied cluster

- Hanh trinh message: Tu producer, qua Broker, den Consumer va rui ro tiem an

Rui ro 1:
- Producer: giai doan 1: application thread tao message -> giai doan 2: record accumulator (hang doi) giu message -> giai doan 3: sender thread gui message
- Rui ro nam trong record accumulator: ung dung dot ngot bi dung khi o trong hang cho -> mat luon message

producer -> cau hinh| muc dich                                               -> consumer
                        acks=all | cho xac nhan tu tat ca cac replica
                        retires > 0 | tu dong gui lai khi co loi
                        idempotent | ngan chan cac message trung lap


Rui ro 2: 
- Ghi du lieu vao RAM truoc (sieu nhanh) -> roi moi tu tu ghi xuong dia -> rui ro nam o day
-> RAM gap su co -> du lieu boc hoi
-> rui ro con nam o viec sao chep du lieu: leader gap su co truoc khi cac follower kip replica thi message mat
-> giai phap: co it nhat 3 ban sao cho 1 partition du lieu
cau hinh min.in-sync.replica
theo doi ban sau co bi lac hau khong
=> Kafka rat nhanh nhung toc do di kem voi rui ro neu do ben du lieu khong duoc kiem soat
-> rủi ro thứ 3: dien ra o consumer. O consumer thi co 1 cai de danh dau la offset de biet no da doc den dau roi: auto commit (Kafka se tu dong doi bookmark di khong can biet logic xu ly da xong hay chua) -> rui ro neu ung dung sap ngay sau bookmark da duoc gui di nhung chua xu ly -> message se bi bo lo mai mai, manual commit (toan kiem quyen soat, chi doi bookmark khi nao cong viec hoan thanh). Chien luoc thong minh: ket hop async commit, khi co loi xay ra thi dung sync, con voi nhung message ma bi loi mai thi gui vao hang cho rieng la dead-letter queue

-> Message co the khong bi xoa, nhung co hoi xu ly no co the bien mat -> do cung la mot dang mat du lieu


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Vid 6
Chuyen gi se xay ra khi 1 broker ngung hoat dong-

Cum Kafka & tinh san sang cao

- Kafka dc sinh ra vs triet ly cot loi: chiu loi va hoat dong lien tuc. HA khong phai la tinh nang dc them vao sau nay ma la nen tang Kafka
- Cum dc tao thanh nhieu Broker. Dung dau chi huy tat ca la Controller, du lieu chi nho thanh cac partition -> xu ly song song va sao chep hieu qua nhat
Ngay xua kien truc cu Kafka dung Zookeeper ben ngoai de dieu phoi, ha tang phuc tap hon con bay gio thi dung KRaft (mot kien truc moi) tich hop thang vao Controller, don gian va nhanh hon -> lam cho he thong don gian hon, nhanh hon, do tre giam di dang ke
-> Kafka dang dan loai bo he thong ben ngoai de tro thanh he thong dang tin cay hon

ISR: tap hop cac ban sao da dong bo hoan toan voi leader, san sang de duoc bau chon lam leader
He so sao chep vang la 3: 

Failover: tu phuc hoi
Buoc 1: Hoat dong: leader phuc vu yeu cau. ISR dong bo hoa -> Buoc 2: Loi xay ra: Broker leader dang hoat dong bi sap -> Buoc 3: Bau chon: Controller phat hien loi va khoi tao bau chon. Buoc 4: Leader moi: Mot follower tu tap hop ISR duoc thang cap

-> Khong phai moi ban sau deu binh dang - chi ISR moi duoc Kafka tin tuong
Khi mot broker moi dc them vao hay 1 broker cu nghi huu thi Kafka se tu dong phan cong lai cong viec, hay cac partition khong bi qua tai

Van hanh toi uu
- Luon co toi thieu 3 broker -> du toi thieu quorum -> tranh duoc tinh trang Split Brain
- phan cung toi uu
hang muc | khuyen nghi | ly do chinh
dia | du RAM | tan dung bo dem hdh
mang | do tre thap | sao chep khong bi tre

- Chi so giam sat chinh: ISR Shrinkage: tuc la nhom ISR dang bi co lai -> cac ban sao dang gap kho khan trong dong bo, Replica Lag, Controller Re-election


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Vid 8 
- 1 Producer: toc do va an toan
- 2 Consumer group: phoi hop
- 3 offset: dau chan du lieu
- 4 partition: dung thu tu

1 Producer
can bang giua toc do va an toan

cai dat acks | toc do | rui ro mat du lieu | truong hop su dung
acks = 0 | cao nhat | cao | du lieu khong quan trong
acks = 1 | cao | thap | ghi log thong luong cao
acks = all | an toan nhat | rat thap | he thong quan trong

linger.ms: cau hinh nay bao doi 1 chut de kafka gom message thanh 1 nhom -> gui hieu qua hon
batch.size: kich thuoc cua nhom du lieu ben tren
compression.type: nen du lieu -> giam tai bang thong mang

- Dieu gi xay ra khi mang truc trac co van de: ket hop retries + idempotence -> dam bao du co gui lai bao nhieu lan thi cung khong bi trung lap message


2 Consumer
- Khai niem trung tam Rebalancing: qua trinh phan chia lai cac partition cua topic co cac consumer trong nhom khi co thay doi thanh vien
- Cai gia phai tra an sau qua trinh rebalancing ?: Toan bo group se phai tam dung xu ly -> tang vot do tre -> ap luc khi xu ly real time. Giai phap: Static group membership: bang cach gan cho moi group 1 id co dinh laf group.instance.id Neu co khoi dong lai thi Kafka khong can phai rebalancing toan dien nua (vi nho mat group do :))

3 Offset: bookmark trong 1 quyen sach, danh dau chinh sach vi tri ma consumer da doc toi -> dam bao du lieu khong bi bo sot va xu ly 1 cach sai lam

Chien luoc Commit Offset
Tu dong - auto commit: don gian nhung rui ro mat hoac trung lap du lieu
Dong bo - sync commit: an toan nhung chan cho den khi commit thanh cong
Bat dong bo - async commit: nhanh nhung viec xu ly loi khi gui lai phuc tap
Thu cong - manual commit: kiem soat hoan toan cho logic xu ly phuc tap

Viec chon chien luoc commit -> quyet dinh su dam bao xu ly du lieu
At least one: dam bao khong mat du lieu nhung du lieu co the bi trung lap
Exacly one: khong mat khong trung , can su dung cac producer transaction -> tinh nang nang cao cho phep gui khoi cong viec du lieu dam bao tinh nguyen tu 

4 Patition: dam bao dung thu tu
- Thu tu message dam bao trong 1 partition duy nhat, Kafka khong dam bao thu tu cua no tren toan topic neu no co nhieu partition
Duy tri thu tu: su dung key nhat quan cho toan message lien quan. Kafka dam bao cac message co cung Key se di cung vao cung partition. Hay han che thay doi so luong partition ma thu tu la yeu to song con

-> Cac cau hinh cua Partition se dam bao toc do va su an toan cua dong du lieu khi duoc gui di
-> Cac cau hinh cua Consumer se dam bao do tin cay va nhat quan khi du lieu do duoc doc

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Vid 7:

1 Cau truc Log: nen tang cua Kafka: chuoi ban ghi thu tu, bat bien, duoc toi uu hoa cho viec ghi va doc tuan tu (chi cho phep ghi vao cuoi)

To chuc log:
Topic -> Partitions -> Segments: du lieu duoc to chuc theo cac cap bac tu lon den nho de de dang quan ly 

2. 
Ben trong 1 segment
- .log
- .index: hoat dong nhu 1 muc luc cua cuon sach giup Kafka nhay thang den 1 message ma khong can quet toan bo
- .timeindex: cho phep tim kiem dua tren thoi gian
-> thu ma ket noi tat ca thu nay lai voi nhau la offset: moi message trong 1 partition co 1 ma dinh danh khac nhau

Append-Only Log: ghi tuan tu -> tan dung duoc toc do cao nhat cua o cung, giam phan manh dia, va cho phep hdh luu tru du lieu vao page cache -> tang toc do doc du lieu 

Khi mot tep segment trong kafka day thi sao -> Kafka chi don gian la dong no lai va mo ra 1 tep segment moi de ghi tiep, su bat bien -> chia khoa cho su on dinh he thong
-> Khong co lenh UPDATE trong Kafka - chi co WRITE va DELETE mot cach thong minh

3 Vong doi du lieu: Retention policies
- Giu lai theo thoi gian: giu du lieu trong mot khoang thoi gian cu the (vi du: 7 ngay): Ly tuong cho logs va phan tich
- Giu lai theo kich thuoc: gioi han tong kich thuoc log cho 1 partition (khi partition vuot qua 1 muc gioi han dung luong nao do. Kafka se tu dong xoa cac ban ghi cu nhat di). Tot nhat khi dung luong luu tru co han
- Nen log (Compaction): Co che nay se don dep ngay ben trong segment, dam bao giu lai gia tri cuoi cung cho moi key, hoan hao cho viec luu tru trang thai

4 Toi uu hoa chi phi 

cau hinh | Uu diem | Nhuoc diem
giu lai lau | de xu ly lai | chi phi cao
giu lai ngan | chi phi thap | rui ro mat du lieu
segment lon | thong luong cao | xoa kem linh hoat
segment nho | don dep nhanh | chi phi quan ly

Con so khoi dau cho cac segment: dat kich thuoc cac segment la 1 GB -> con so vang can bang giua ghi va quan ly du lieu

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Vid 9 Kafka streams
- Neu database la noi du lieu ngu yen thi Kafka Streams la noi du lieu song va hanh dong
1 Ghi du lieu
2 Kafka Streams
3 ksqlDB
4 Ung Dung

1 Ghi du lieu: tu du lieu sang dong chay
- Kafka Streams API, ksqlDB
Kafka Streams: Stream: la dong su kien lien tuc va Table: la trang thai hien tai duoc rut ra tu chinh stream do
-> co the filtering: lap do du lieu khong can thiet, mapping: bien doi cau truc cua no, join: ket hop nhieu dong data khasc nhau, windowing: phan tich du lieu theo tung cua so thoi gian
-> Thay vi cho du lieu, ban xu ly no ngay khi no xuat hien

3. ksqlDB
-> phan tich du lieu real time tro nen don gian nhu chay 1 truy van sql

4. Ung dung
- Data enrichment
- Real-time Analytics
- Aggregation

Kafka streams -noi du lieu khong chi duoc luu -> ma thuc su song

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Vid 10:
Semantic Exactly - Once & Transactional messaging

Kafka noi tieng vi toc do. Nhung neu moi message phai xuat hien mot lan duy nhat, he thong co con nhanh?

1 Van de toan ven data
2 Giai phap: giao dich kafka
3 Cau hinh Exactly-Once
4 Danh doi: Toc do va tin cay

1 Van de toan ven du lieu
Dam bao | Uu diem | Nhuoc diem
At-most-once | Nhanh, khong trung lap | Co the mat data
At-least-once | Khong mat du lieu | co the trung lap
Exactly-once | Khong mat, khong trung | Do tre / chi phi cao hon

Truoc day thi kafka chi ho tro at-least-once thoi nhung tu phien ban 0.11 -> dat duoc eos


2. Giai phap: giao dich Kafka
Kafka hoat dong nhu DB

Giao dich tin nhan: cho phep producer gui 1 nhom message nhu mot don vi nguyen tu. Tat ca thanh cong, hoac khong gi ca

Vong doi transaction:
beginTxn(): Bat dau giao dich
send(message): Gui tin nhan
commitTxn(): Xac nhan thanh cong
abortTxn(): Huy bo neu loi

3. Cau hinh Exactly-Once

producer: 
- enable idempotence: phải được bật thành true -> kich hoat che do producer khong gui tin nhan trung lap khi ma no gui lap (Cap cho tung producer 1 cai ID duy nhat va danh so thu tu cho tung message)
- transaction id: hoat dong nhu 1 cccd cua transaction

consumer:
- isolation level: read commited: dam bao consumer chi doc cac giao dich da thanh cong hay thoi

4. Danh doi: toc do vs tin cay

- phu thuoc rat nhieu vao bai toan cu the
- Nen dung eos khi do tin cay duoc dat len hang dau: tai chinh, ngan hang
- Khong nen dung eos khi hieu nang duoc dat len hang dau, khi du lieu trung lap cung khong sau: analytics, logging

Cai gia cua su chinh xac
- Do tre tang len: dieu phoi cac transaction
- Cac broker chiu tai xu ly tang
- He thong phai quan ly them cac metadata cua cac transaction

-> Do chinh xac tuyet doi khong mien phi - do la su danh doi giua toc do va do tin cay

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Vid 11: CDC & Event Sourcing

1 Du lieu la mot cau chuyen
2 Ghi lai voi CDC
3 Ke chuyen Event Sourcing
4 So sanh 2 cach tiep can
5 Chon huong di

1. Du lieu la mot cau chuyen
2 triet ly khac nhau

CDC: nhu nguoi quan sat ghi nhan su thay doi sau khi no da dien ra va xac nhan trong database
Event Sourcing: nguoi ke chuyen, ghi lai y dinh, hanh dong ngay tai thoi diem no phat sinh

2 Ghi lai voi CDC
Change Data Capture: Ky thuat theo doi thay doi (INSERT, UPDATE, DELETE) trong DB va bien chung thanh luong su kien
Trien khai voi debezium: khong phai la kieu di hoi database lien tuc co gi moi khong. Doc truc tiep tu transaction log cua database hieu qua ma khong lam phien den he thong nguon -> bien doi thanh cac su kien va day thang vao kafka

Database: thay doi duoc ghi vao trasaction log -> Debezium: Doc transaction log -> Kafka Topic: Debezium publish su kien thay doi -> Consumers: cac ung dung khac tiep thu su kien

Uu diem: lich su, khong xam lan, co the gan vao 1 ung dung legacy ma khong can thay doi du chi 1 dong code
Han che: chi ghi lai ket qua cuoi cung sau khi da commit -> khong biet duoc logic nghiep vu hay y dinh dang sau su thay doi do la gi

3 Ke chuyen Event Sourcing: 
Trang thai cua ung dung duoc xac dinh bang 1 chuoi cac su kien theo trinh tu thoi gian
Kafka as an Event Store: moi hd tro thanh 1 su kien va duoc ghi vao topic cua Kafka. Ma topic cua Kafka thi bat bien -> xay ra 1 tinh nang ao dieu la replay lai su kien.
Cai gia phai tra la su phuc tap trong cach tu duy xay dung ung dung

-> Event Sourcing ke lai cau chuyen vi sao du lieu thay doi, khong chi la cai gi da thay doi

4 So sanh 2 cach tiep can

Tieu chi | CDC | Event Sourcing
Diem bat dau | Sau khi DB ghi xong | Ngay khi hanh dong xay ra
Du lieu luu | Thay doi (delta) | Toan bo su kien (log)
Cong cu | Debezium + Kafka | Kafka (Event Store)
Thach thuc | Phu thuoc vao DB | Phuc tap trong thiet ke

-> CDC giup he thong biet khi nao du lieu thay doi; Event Sourcing giup he thong hieu tai sao

5 Chon huong di
Legacy System -> CDC -> modern Architecture

Bat dau tren trang giay trang dac biet voi cac he thong quan trong -> Event Store

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Vid 12: Bao mat toan dien Kafka

1 3 tru cot bao mat
Xac thuc: ban la ai
Phan quyen: ban co the lam gi
Ma hoa: giu bi mat du lieu

2 Xac thuc & Phan quyen
2 co che: SSL: X509, client va broker chung minh danh tinh cho nhau, SASL 
SASL
co che | mo ta
username, password | phai dung voi ssl
SCRAM | xac thuc hoi-dap an toan hon
GSSAPI | Cap doan nghiep (Kerberos)

3 ACLs: dinh nghia cac quyen cu the (doc, ghi) cho nguoi dung sau khi da xac thuc thanh cong

-> khong ai nen co quyen quan tri neu ho khong thuc su can den

3 Ma hoa toan dien: bao ve chinh du lieu
Ma hoa in-transit (SSL/TLS): bao ve du lieu tren truyen
Ma hoa at-rest: bao ve du lieu duoc luu tren dia

-> Du lieu phai duoc khoa khong chi o cong ma o moi noi, moi luc

4. Thuc hanh
Kiem tra thiet yeu
1. Bat xac thuc SSL/TLS ma hoa data dang truyen -> 2. xac thuc SCRAM, Kerberos -> 3. Thuc hien xac thuc quyen ACLs nghiem ngat, ma hoa du lieu luu tren dia -> 4. Xoay vong cac chung chi bao mat dinh ky
-> Bao mat khong phai la 1 cau hinh, do la 1 van hoa an toan

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

VID 13: Scaling & Performance Tuning

Phan vung thong minh -> tinh chinh producer & consumer -> toi uu hoa cluster & ha tang

1. Chia khoa xu ly song song: Partition: don vi song song co ban trong 1 topic Kafka, Nhieu partition hon cho phep xu ly dong thoi nhieu hon

Thuc hanh:
    - Bat dau voi co so: 1 partition cho moi 1MB/giay thong luong
    - Mo rong dan khi consumer bi tre hoac broker qua tai
    - Su dung khoa phan vung (vi du: user_id) de duy tri thu tu.
    - Trien khai paritioner tuy chinh de phan hpoi du lieu deu

-> Mot partition la mot don vi toc do nhung cung la mot don vi hon loan neu khong duoc kiem soat

2. Toi uu hoa Producer: Gui du lieu nhanh hon

Cau hinh | Muc dich | Gia tri de xuat
batch.size | kich thuoc lo du lieu | 32KB-64KB
linger.ms | Thoi gian cho de lap day lo | 5-20ms
compression.type | Giam kich thuoc du lieu | 1z4 hoac zstd
acks | Do tin cay ghi du lieu | 1 (toc do), all (an toan)
max.in.flight.requests.per.connection | Yeu cau song song | 5-10

meo cho producer
- Bat idempotence de tranh trung lap du lieu khi gui lai
- Su dung gui bat dong bo (send()) de toi da hoa hieu qua mang
- Theo doi RecordSendRate va RequestLatencyAvg de tinh chinh


3. Tang toc Consumer: doc du lieu song song
- Nguyen tac bat di bat dich khi mo rong consumer: co the co so luong consumer = so luong partition nhung ngay khi so luong consumer vuot qua so luong partition -> nhung consumer thua ra hoan toan vo dung

Buoc 1: Nhieu partition: tao topic voi nhieu partition de cho phep mo rong ngang -> Buoc 2: Them Consumer: Tang so luong consumer instance trong cung mot nhom -> Buoc 3: Tach xu ly: Tach xu ly phuc tap ra motj luong nen hoac bo xu ly rieng

-> Cang nhieu consumer, thong luong cang cao - nhung chi khi co du partition de chia se

4. Nen tang vung chac: ha dong & dinh co
Checklists ha tang
- Brokers: Bat dau voi 3 de co tinh san sang cao (HA).
- Disk I/O: Su dung SSD hoac NVMe; tranh luu tru qua mang.
- Mang: Huong toi 10-25 Gbps cho cac cum lon
- Replication: He so 3 can bang giua do ben va hieu suat
- Giam sat: Theo doi UnderReplicatedPartitions, RequestLatency

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Vid 15: Kafka: Van hanh he thong
1 Trien khai: May/ Tai cho
2 Nang cao khong gian doan
3 Phuc hoi sau tham hoa
4 Sao luu & Di chuyen
5 Quy tac van hanh vang

1 Trien khai: May/ Tai cho
Bare-metal: toan quyen kiem soat, nhung quan tri phuc tap
Cloud Managed: De mo rong, nhung chi phi co the cao hon

Muc tieu: 
-> neu san pham can dua ra thi truong nhanh -> managed service

2. Nang cap khong gian doan: Duy tri he thong song
Quy trinh Rolling Upgrade
Buoc 1: Stop mot broker -> Buoc 2: Upgrade binary / config -> Buoc 3: Restart broker & verify -> Buoc 4 Lap lai cho cac broker khac

Luu y quan trong:
-> Replication factor > 3: moi mau du lieu phai co 3 ban sao du lieu o cac broker khac nhau
-> Rolling upgrade la bai kiem tra su kien nhan - nang cap tung buoc nho de giu he thong song

3. Phuc hoi sau tham hoa: khi su co la chac chan
- Geo-replication: Sao chep du lieu Kafka giua cac cluster o cac vi tri dia ly khac nhau de phuc hoi tham hoa -> xay dung he thong da vung giup giam do tre cho nguoi dung toan cau, cong cu di chuyen du lieu 1 cach lien mach len dam may

 | Mirror Maker 2.0 | Confluent Replicator
Loai | Apache Kafka | enterprise
Use Case | Replicate topics | Enterprise DR, Sync ACL
Setup | Thu cong | Don gian hoa

4. Sao luu di chuyen du lieu
Chien luoc Backup: Sao luu du lieu log (disk, S3), snapshot metadata
Restore, Migration

7 quy tac van hanh
1 theo doi: cac chi so quan trong -> 2 tuong thich: kiem tra compatibility truoc upgrade -> 3 du phong co it nhat 1 cluster dr -> 4 tu dong hoa deployment -> 5 dien tap: test failover dinh ky

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Vid 16: Kafka trong microservices

2 cach chinh
dong bo: kieu goi api thong qua http. service A goi service B va phai ngoi cho cau tra loi -> don gian nhung tao ra su phu thuoc chat che de gay tac nghen
bat dong bo dung kafka: service A phat 1 event toi Kafka, cac service khac lang nghe va co the xu ly bat ky luc nao ma chung san sang -> he thong linh hoat va de mo rong hon rat nhieu
1 giao tiep huong su kien
2 saga pattern
3 schema: hop dong du lieu
4 thiet ke tin nhan sao cho an toan

1 giao tiep huong su kien
Kien truc huong su kien: Mo hinh noi cac dich vu giao tiep bang cach san xuat va tieu thu su kien, ma khong can biet ve nhau

2 saga pattern
Lam sao dam bao giao dich an toan trong he thong phan tan

Mo hinh | Cach hoat dong | Uu diem | Nhuoc diem
Choreography | Dich vu xuat ban su kien kich hoat dich vu tiep theo | Don gian, khong co dieu phoi vien | Kho theo doi luong phuc tap
Orchestration | Mot dieu phoi vien trung tam gui lenh | De quan ly, logic ro rang | Phu thuoc vao dieu phoi vien

-> kafka la 1 nen tang hoan hao cho 2 mo hinh saga nay, neu 1 buoc nao do that bai, he thong xuat ban 1 su kien boi hoan de cac service truoc do dao nguoc lai -> he thong co kha nang tu chua lanh

3 Schema: hop dong du lieu

- Schema khong chi la cau truc du lieu - no la 1 hop dong ve su tin tuong giua cac doi -> vai tro cua schema registry: giong nhu 1 nguoi thu thu quan ly phien ban, dam bao rang tat ca cac phien ban deu tuan thu theo cung 1 nguyen tac tuong thich, de cac service cu hieu cac message tu cac service moi va nguoc lai

4 Thiet ke tin nhan an toan
Loai | Dac diem
Su kien | Mo ta dieu gi do da xay ra
Lenh | Yeu cau dieu gi do nen duoc lam

Idempotency: thuoc tinh cua 1 hoat dong co the duoc ap dung nhieu lan ma khong lam thay doi ket qua ban dau
Cach dat duoc idempotency: co nhieu ky thuat: don gian nhat la luu lai id cua 1 su kien, truoc khi xu ly 1 su kien moi, ta kiem tra xem id cua su kien ay da duoc xu ly hay chua, neu roi thi thoi, bo qua

