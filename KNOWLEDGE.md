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
cau hinh min.sync.replica
theo doi ban sau co bi lac hau khong
=> Kafka rat nhanh nhung toc do di kem voi rui ro neu do ben du lieu khong duoc kiem soat

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------