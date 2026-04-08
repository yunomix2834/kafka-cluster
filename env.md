Name	Description	Default value
KAFKA_CFG_NODE_ID (mode Kraft)	Id node	
KAFKA_CFG_CONTROLLER_QUORUM_VOTERS (mode Kraft)	Các cặp host:port cách nhau dấu phẩy, mỗi cặp ~ 1 controller kafka	
KAFKA_CFG_PROCESS_ROLES(mode Kraft)	Danh sách vai trò của Kafka Kraft: controller, broker , controller , broker	
KAFKA_CFG_LISTENERS (mode Kraft)	Danh sách listeners, nếu node set với controller thì listener phải đi kèm CONTROLLER	
KAFKA_CFG_ADVERTISED_LISTENERS (mode Kraft)	Địa chỉ listeners mà client sẽ connect	
KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP (mode Kraft)	Giao thức secu cho listeners	
KAFKA_CFG_CONTROLLER_LISTENER_NAMES (mode Kraft)	Tên của listeners mà controller sẽ sử dụng	
KAFKA_CFG_INTER_BROKER_LISTENER_NAME (mode Kraft)	tên của listeners mà các brokers sẽ sử dụng để giao tiếp với nhau	
KAFKA_MOUNTED_CONF_DIR	Đường dẫn đến thư mục chứa các file config Kafka muốn tùy chỉnh để mout vào container	${KAFKA_VOLUME_DIR}/config
KAFKA_INTER_BROKER_USER	Tên user được dùng để xác thực giữa các broker Kafka với nhau	user
KAFKA_INTER_BROKER_PASSWORD	Mật khẩu cho KAFKA_INTER_BROKER_USER	bitnami
KAFKA_CONTROLLER_USER	Tên user được dùng để xác thực giữa controller và các broker	controller_user
KAFKA_CONTROLLER_PASSWORD	Mật khẩu cho KAFKA_CONTROLLER_USER	bitnami
KAFKA_CERTIFICATE_PASSWORD	Mật khẩu cho Certificates	nil
KAFKA_TLS_TRUSTSTORE_FILE	Path file trustore (chứa file .cert) được dùng để xác thực TLS	nil
KAFKA_TLS_TYPE	Loại TLS: SSL / TLSv1.2	JKS
KAFKA_TLS_CLIENT_AUTH	  required / requested / none	required
KAFKA_OPTS	kafka deployment options	nil
KAFKA_CFG_SASL_ENABLED_MECHANISMS	Danh sách cơ chế SASL được kích hoạt: PLAIN, SCRAM-SHA-256, GSSAPI, ...	PLAINTEXT, SCRAM-SHA-256, SCRAM-SHA-512
KAFKA_KRAFT_CLUSTER_ID	ID cluster Kraft	nil
KAFKA_SKIP_KRAFT_STORAGE_INIT	Nếu true, Kafka bỏ qua bước khởi tạo storage.	false
KAFKA_CLIENT_LISTENER_NAME	Tên listener mà các client kết nối	nil
KAFKA_ZOOKEEPER_PROTOCOL	Giao thức để kết nối tới ZooKeeper (SASL/SSL/PLAINTEXT)	PLAINTEXT
KAFKA_ZOOKEEPER_PASSWORD	Mật khẩu để xác thực kết nối Zookeeper	nil
KAFKA_ZOOKEEPER_USER	User cho xác thực SASL kêt nối Zookeeper	nil
KAFKA_ZOOKEEPER_TLS_KEYSTORE_PASSWORD	Keystore file password và key password cho Kafka Zookeeper.	nil
KAFKA_ZOOKEEPER_TLS_TRUSTSTORE_PASSWORD	Mật khẩu trustore file cho Kafka Zookeeper
	nil
KAFKA_ZOOKEEPER_TLS_TRUSTSTORE_FILE	Path trustore file cho Kafka Zookeeper	nil
KAFKA_ZOOKEEPER_TLS_VERIFY_HOSTNAME	Xác thực cho Kafka Zookeeper hostname trong TLS certificates.	true
KAFKA_ZOOKEEPER_TLS_TYPE	Giao thức kết nối Zookeeper	JKS
KAFKA_CLIENT_USERS	Danh sách User của các client	user
KAFKA_CLIENT_PASSWORDS	Danh sách Password của KAFKA_CLIENT_USERS	bitnami
KAFKA_HEAP_OPTS	kafka heap option for Java	
Read-only Enviroment variables
KAFKA_BASE_DIR	Path cài đặt Kafka	
KAFKA_VOLUME_DIR	Path lưu trữ dữ liệu cố định của Kafka	
KAFKA_DATA_DIR	Path lưu trữ dữ liệu Kafka	
KAFKA_CONF_DIR	Path chứa các config	
KAFKA_CONF_FILE	Path file config chính của Kafka	
KAFKA_CERTS_DIR	Path chứa các file .cert của Kafka	
KAFKA_INITSCRIPTS_DIR	Path chứa các script khởi tạo chạy khi Kafka khởi động	
KAFKA_LOG_DIR	Path log	
KAFKA_HOME	Path home	
KAFKA_DAEMON_USER	Tên User của daemon Kafka (User chạy Kafka)	kafka
KAFKA_DAEMON_GROUP	Mật khẩu của KAFKA_DAEMON_USER	kafka
KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR	Đặt hệ số replication cho log trạng thái giao dịch	
KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR	số lượng bản sao nhỏ nhất cho log của trạng thái giao dịch là 1, đảm bảo tính nhất quán cho các giao dịch.	
KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR	Thiết lập hệ số replication của topic offsets	
KAFKA_CFG_SUPER_USERS	Định nghĩa người dùng admin là super user, cho phép quản trị toàn bộ Kafka.	
KAFKA_CFG_LOG_DIRS	
	
KAFKA_CFG_SECURITY_INTER_BROKER_PROTOCOL	Thiết lập giao thức bảo mật giữa các broker	
SASL enviroment variables
KAFKA_OPTS	Thêm tùy chọn Java cho Kafka để chỉ định file cấu hình JAAS (kafka_jaas.conf), chứa thông tin xác thực và cấu hình bảo mật cho SASL.	
KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL	Định nghĩa cơ chế xác thực PLAIN cho giao tiếp giữa các broker (nếu có nhiều broker).	
KAFKA_CFG_SASL_ENABLED_MECHANISMS	Kích hoạt cơ chế SASL PLAIN cho việc xác thực người dùng	



*** notes ***

    cần active port 9092 (port mặc định), 9093 (port của controller trong mode Kraft)
    với mode single-node,  chạy trên 1 broker duy nhất
    với mode cluster, chạy trên 3 broker, mỗi broker đóng vai trò controller và broker
    khi tạo mới topic với số lượng partitions và replication factor truyền theo thì số lượng replication factor phải nhỏ hơn số lượng brokers (3)
    Retention Time mặc định trong Kafka là 7 ngày