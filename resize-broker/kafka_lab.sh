#!/usr/bin/env bash
set -uo pipefail

export C="${C:-database}"
export BIN="${BIN:-/opt/bitnami/kafka/bin}"
export CFG="${CFG:-/etc/kafka_client.conf}"

inspect_env_lines() {
  docker inspect "$C" --format '{{range .Config.Env}}{{println .}}{{end}}'
}

env_get() {
  local key="$1"
  inspect_env_lines | awk -F= -v k="$key" '$1==k{print substr($0,index($0,"=")+1); exit}'
}

controller_voters_raw() {
  env_get KAFKA_CFG_CONTROLLER_QUORUM_VOTERS
}

all_voter_rows() {
  controller_voters_raw | tr ',' '\n'
}

all_node_ids() {
  all_voter_rows | awk -F'[@:]' '{print $1}' | sort -n
}

node_ip() {
  local id="$1"
  all_voter_rows | awk -F'[@:]' -v id="$id" '$1==id{print $2; exit}'
}

node_ctrl_port() {
  local id="$1"
  all_voter_rows | awk -F'[@:]' -v id="$id" '$1==id{print $3; exit}'
}

bootstrap_servers() {
  all_voter_rows | awk -F'[@:]' 'BEGIN{first=1} {printf "%s%s:9092", (first?"":","), $2; first=0}'
}

export BS_ALL="${BS_ALL:-$(bootstrap_servers)}"

export DATA_HOST="${DATA_HOST:-$(docker inspect "$C" --format '{{range .Mounts}}{{if eq .Destination "/bitnami/kafka/data"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || true)}"
DATA_HOST="${DATA_HOST:-/var/lib/kafka/data}"

current_node_id() { env_get KAFKA_CFG_NODE_ID; }
current_broker_id() { env_get KAFKA_CFG_BROKER_ID; }
current_cluster_id() { env_get KAFKA_KRAFT_CLUSTER_ID; }
current_adv_listener() { env_get KAFKA_CFG_ADVERTISED_LISTENERS; }

current_vm_ip() {
  local adv
  adv="$(current_adv_listener || true)"
  if [[ -n "$adv" ]]; then
    printf '%s\n' "$adv" | sed -E 's#.*://([^:]+):.*#\1#'
  else
    node_ip "$(current_node_id)"
  fi
}

peer_ips_of_self() {
  local me
  me="$(current_node_id)"
  all_voter_rows | awk -F'[@:]' -v me="$me" '$1!=me{print $2}'
}

k_current_controller_leader() {
  k_quorum 2>/dev/null | awk -F: '/LeaderId:/{gsub(/ /,"",$2); print $2; exit}'
}

k_current_controller_epoch() {
  k_quorum 2>/dev/null | awk -F: '/LeaderEpoch:/{gsub(/ /,"",$2); print $2; exit}'
}

self_summary() {
  echo "container      : $C"
  echo "cluster.id     : $(current_cluster_id)"
  echo "node.id        : $(current_node_id)"
  echo "broker.id      : $(current_broker_id)"
  echo "self ip        : $(current_vm_ip)"
  echo "advertised     : $(current_adv_listener)"
  echo "bootstrap      : $BS_ALL"
  echo "data host path : $DATA_HOST"
  echo "voters         : $(controller_voters_raw)"
  echo "peers          : $(peer_ips_of_self | xargs echo)"
}

kexec() {
  docker exec -i "$C" sh -lc "unset JMX_PORT KAFKA_JMX_OPTS; $*"
}

k_topics() { kexec "$BIN/kafka-topics.sh --bootstrap-server $BS_ALL --command-config $CFG $*"; }
k_quorum() { kexec "$BIN/kafka-metadata-quorum.sh --bootstrap-server $BS_ALL --command-config $CFG describe --status"; }
k_quorum_replication() { kexec "$BIN/kafka-metadata-quorum.sh --bootstrap-server $BS_ALL --command-config $CFG describe --replication"; }
k_groups() { kexec "$BIN/kafka-consumer-groups.sh --bootstrap-server $BS_ALL --command-config $CFG $*"; }
k_configs() { kexec "$BIN/kafka-configs.sh --bootstrap-server $BS_ALL --command-config $CFG $*"; }
k_features() { kexec "$BIN/kafka-features.sh --bootstrap-server $BS_ALL --command-config $CFG describe"; }
k_log_dirs() { kexec "$BIN/kafka-log-dirs.sh --bootstrap-server $BS_ALL --command-config $CFG --describe --broker-list $(printf '%s' "$*" | sed 's/ /,/g')"; }

leader_election_cfg_opt() {
  if kexec "$BIN/kafka-leader-election.sh --help" 2>&1 | grep -q -- '--command-config'; then
    echo "--command-config"
  else
    echo "--admin.config"
  fi
}

k_leader_elect_preferred() {
  local cfgopt scope
  cfgopt="$(leader_election_cfg_opt)"
  if [[ $# -ge 1 ]]; then
    local topic="$1"
    local partition="${2:-0}"
    scope="--topic $topic --partition $partition"
  else
    scope="--all-topic-partitions"
  fi
  kexec "$BIN/kafka-leader-election.sh --bootstrap-server $BS_ALL $cfgopt $CFG --election-type preferred $scope"
}

k_reassign_generate() {
  local topics_json="$1"
  local broker_list="$2"
  kexec "$BIN/kafka-reassign-partitions.sh --bootstrap-server $BS_ALL --command-config $CFG --topics-to-move-json-file $topics_json --broker-list '$broker_list' --generate"
}

k_reassign_execute() {
  local plan_json="$1"
  kexec "$BIN/kafka-reassign-partitions.sh --bootstrap-server $BS_ALL --command-config $CFG --reassignment-json-file $plan_json --execute"
}

k_reassign_verify() {
  local plan_json="$1"
  kexec "$BIN/kafka-reassign-partitions.sh --bootstrap-server $BS_ALL --command-config $CFG --reassignment-json-file $plan_json --verify"
}

k_cluster_snapshot() {
  echo '===== SELF ====='
  self_summary
  echo
  echo '===== QUORUM ====='
  k_quorum || true
  echo
  echo '===== QUORUM REPLICATION ====='
  k_quorum_replication || true
  echo
  echo '===== FEATURES ====='
  k_features || true
  echo
  echo '===== TOPICS ====='
  k_topics --list || true
}

k_create_test_topics() {
  k_topics "--create --if-not-exists --topic ha-hot --partitions 12 --replication-factor 3 --config min.insync.replicas=2"
  k_topics "--create --if-not-exists --topic ha-hot-p1 --partitions 1 --replication-factor 3 --config min.insync.replicas=2"
  k_topics "--create --if-not-exists --topic backup-lab --partitions 6 --replication-factor 3 --config min.insync.replicas=2"
}

k_list_topics() { k_topics --list; }
k_describe_topic() { local topic="$1"; k_topics "--describe --topic $topic"; }
k_describe_hot() { k_describe_topic ha-hot; }
k_describe_hot_p1() { k_describe_topic ha-hot-p1; }
k_describe_backup_lab() { k_describe_topic backup-lab; }

k_partition_line() {
  local topic="$1" part="$2"
  k_topics "--describe --topic $topic" | awk -v p="$part" '$0 ~ ("Partition: " p "(\t| )") {print; exit}'
}

k_partition_leader() { local topic="$1" part="$2"; k_partition_line "$topic" "$part" | sed -nE 's/.*Leader: *([0-9]+).*/\1/p'; }
k_partition_replicas() { local topic="$1" part="$2"; k_partition_line "$topic" "$part" | sed -nE 's/.*Replicas: *([^ ]+).*/\1/p'; }
k_partition_isr() { local topic="$1" part="$2"; k_partition_line "$topic" "$part" | sed -nE 's/.*Isr: *([^ ]+).*/\1/p'; }

k_partition_detail() {
  local topic="$1" part="$2"
  echo "topic      : $topic"
  echo "partition  : $part"
  echo "leader     : $(k_partition_leader "$topic" "$part")"
  echo "replicas   : $(k_partition_replicas "$topic" "$part")"
  echo "isr        : $(k_partition_isr "$topic" "$part")"
  echo "line       : $(k_partition_line "$topic" "$part")"
}

k_producer_hot() {
  kexec "awk 'BEGIN{for(i=1;;i++) print strftime(\"%s\"),i}' | $BIN/kafka-console-producer.sh --bootstrap-server $BS_ALL --producer.config $CFG --producer-property acks=all --producer-property linger.ms=10 --producer-property batch.size=65536 --topic ha-hot"
}

k_producer_hot_p1() {
  kexec "awk 'BEGIN{for(i=1;;i++) print strftime(\"%s\"),i}' | $BIN/kafka-console-producer.sh --bootstrap-server $BS_ALL --producer.config $CFG --producer-property acks=all --producer-property linger.ms=10 --producer-property batch.size=65536 --topic ha-hot-p1"
}

k_producer_backup_lab() {
  kexec "awk 'BEGIN{for(i=1;i<=100000;i++) print \"backup-lab-\" i}' | $BIN/kafka-console-producer.sh --bootstrap-server $BS_ALL --producer.config $CFG --producer-property acks=all --topic backup-lab"
}

k_consumer_hot() { kexec "$BIN/kafka-console-consumer.sh --bootstrap-server $BS_ALL --consumer.config $CFG --topic ha-hot --group ha-hot-g1 --from-beginning"; }
k_consumer_hot_p1() { kexec "$BIN/kafka-console-consumer.sh --bootstrap-server $BS_ALL --consumer.config $CFG --topic ha-hot-p1 --group ha-hot-p1-g1 --from-beginning"; }
k_group_hot() { k_groups "--describe --group ha-hot-g1"; }
k_group_hot_p1() { k_groups "--describe --group ha-hot-p1-g1"; }

w_quorum() { watch -n 1 "bash -lc 'source ~/kafka_lab.sh; k_quorum'"; }
w_hot() { watch -n 1 "bash -lc 'source ~/kafka_lab.sh; k_describe_hot'"; }
w_hot_p1() { watch -n 1 "bash -lc 'source ~/kafka_lab.sh; k_describe_hot_p1'"; }
w_group_hot() { watch -n 2 "bash -lc 'source ~/kafka_lab.sh; k_group_hot'"; }
w_group_hot_p1() { watch -n 2 "bash -lc 'source ~/kafka_lab.sh; k_group_hot_p1'"; }

k_logs_tail() { local since="${1:-2m}"; docker logs --since "$since" "$C" 2>&1 | tail -n 300; }
k_logs_controller() { local since="${1:-2m}"; docker logs --since "$since" "$C" 2>&1 | egrep -i 'quorum|raft|election|leader|follower|BrokerLifecycleManager|QuorumController|KafkaRaftClient|high.watermark|high watermark|epoch' || true; }
k_logs_replica() { local since="${1:-2m}"; docker logs --since "$since" "$C" 2>&1 | egrep -i 'ReplicaFetcherThread|isr|under-replic|leader and isr|fetch|offset moved|truncat|out of sync' || true; }
k_logs_storage() { local since="${1:-5m}"; docker logs --since "$since" "$C" 2>&1 | egrep -i 'log directory|offline|LogDirFailureChannel|disk|IOException|No space left|stalled|I/O error|bootstrap.checkpoint|meta.properties' || true; }

fw_show() { iptables -L DOCKER-USER -n -v --line-numbers; }

block_peer_ports() {
  local peer="$1" dports="$2"
  iptables -I DOCKER-USER 1 -s "$peer" -p tcp -m multiport --dports "$dports" -j DROP
  iptables -I DOCKER-USER 1 -d "$peer" -p tcp -m multiport --dports "$dports" -j DROP
}

unblock_peer_ports() {
  local peer="$1" dports="$2"
  while iptables -C DOCKER-USER -s "$peer" -p tcp -m multiport --dports "$dports" -j DROP 2>/dev/null; do
    iptables -D DOCKER-USER -s "$peer" -p tcp -m multiport --dports "$dports" -j DROP || break
  done
  while iptables -C DOCKER-USER -d "$peer" -p tcp -m multiport --dports "$dports" -j DROP 2>/dev/null; do
    iptables -D DOCKER-USER -d "$peer" -p tcp -m multiport --dports "$dports" -j DROP || break
  done
}

block_peer_all() { block_peer_ports "$1" 9092,9093; }
unblock_peer_all() { unblock_peer_ports "$1" 9092,9093; }
block_peer_ctrl_only() { block_peer_ports "$1" 9093; }
unblock_peer_ctrl_only() { unblock_peer_ports "$1" 9093; }
block_peer_broker_only() { block_peer_ports "$1" 9092; }
unblock_peer_broker_only() { unblock_peer_ports "$1" 9092; }

isolate_self_all() { local p; for p in $(peer_ips_of_self); do block_peer_all "$p"; done; fw_show; }
heal_self_all() { local p; for p in $(peer_ips_of_self); do unblock_peer_all "$p"; done; fw_show; }
isolate_self_ctrl_only() { local p; for p in $(peer_ips_of_self); do block_peer_ctrl_only "$p"; done; fw_show; }
heal_self_ctrl_only() { local p; for p in $(peer_ips_of_self); do unblock_peer_ctrl_only "$p"; done; fw_show; }
isolate_self_broker_only() { local p; for p in $(peer_ips_of_self); do block_peer_broker_only "$p"; done; fw_show; }
heal_self_broker_only() { local p; for p in $(peer_ips_of_self); do unblock_peer_broker_only "$p"; done; fw_show; }

broker_stop() { docker stop -t 60 "$C"; }
broker_kill() { docker kill "$C"; }
broker_start() { docker start "$C"; }
broker_restart() { docker restart -t 60 "$C"; }

k_ping_peer9092() {
  local ip="$1"
  docker exec -i "$C" bash -lc "timeout 2 bash -lc 'cat </dev/null >/dev/tcp/$ip/9092' && echo '$ip:9092 OK' || echo '$ip:9092 BLOCKED'"
}

k_ping_peer9093() {
  local ip="$1"
  docker exec -i "$C" bash -lc "timeout 2 bash -lc 'cat </dev/null >/dev/tcp/$ip/9093' && echo '$ip:9093 OK' || echo '$ip:9093 BLOCKED'"
}

k_ping_all() {
  local self
  self="$(current_vm_ip)"
  for ip in $(all_voter_rows | awk -F'[@:]' '{print $2}'); do
    [[ "$ip" == "$self" ]] && continue
    k_ping_peer9092 "$ip"
    k_ping_peer9093 "$ip"
  done
}

backup_meta_show() {
  if [[ -f "$DATA_HOST/meta.properties" ]]; then
    grep -E '^(cluster.id|node.id|version)=' "$DATA_HOST/meta.properties" || true
  else
    echo "meta.properties not found under $DATA_HOST"
  fi
}

disk_fill_near_full() {
  local path="${1:-$DATA_HOST}" reserve_mb="${2:-512}" avail fill
  avail=$(df -B1 --output=avail "$path" | tail -1 | tr -d ' ')
  fill=$((avail - reserve_mb*1024*1024))
  if [[ "$fill" -le 0 ]]; then
    echo "Not enough free space to run disk_fill_near_full on $path"
    df -h "$path"
    return 1
  fi
  fallocate -l "$fill" "$path/FILLER.bin"
  sync
  df -h "$path"
}

disk_unfill() {
  local path="${1:-$DATA_HOST}"
  rm -f "$path/FILLER.bin" "$path/stall.bin"
  sync
  df -h "$path"
}

disk_stall_dd() {
  local path="${1:-$DATA_HOST}"
  dd if=/dev/zero of="$path/stall.bin" bs=4M oflag=direct status=progress
}

disk_stall_fio() {
  local path="${1:-$DATA_HOST}"
  fio --name=stall --filename="$path/stall.bin" --rw=write --bs=1M --iodepth=64 --numjobs=4 --size=8G --direct=1
}

netem_route_to() {
  local target="$1"
  ip route get "$target"
}

netem_dev_to() {
  local target="$1"
  ip route get "$target" | awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i+1); exit}}'
}

netem_guard_peer() {
  local peer="$1" dev self
  self="$(current_vm_ip)"
  dev="$(netem_dev_to "$peer")"

  if [[ -z "$dev" ]]; then
    echo "Cannot determine device for target $peer"
    return 1
  fi
  if [[ "$peer" == "$self" ]]; then
    echo "Target $peer is the current node address. Use a peer IP, not self."
    return 1
  fi
  if [[ "$dev" == "lo" ]]; then
    echo "Target $peer resolves to loopback on this node. Use a peer IP."
    return 1
  fi
  printf '%s\n' "$dev"
}

netem_peer_show() {
  local peer="$1" dev
  dev="$(netem_guard_peer "$peer")" || return 1
  tc -s qdisc show dev "$dev"
  tc filter show dev "$dev" parent 1: 2>/dev/null || true
}

netem_peer_delay() {
  local peer="$1" delay="${2:-200ms}" jitter="${3:-50ms}" dev
  dev="$(netem_guard_peer "$peer")" || return 1
  tc qdisc del dev "$dev" root 2>/dev/null || true
  tc qdisc add dev "$dev" root handle 1: prio bands 4
  tc qdisc add dev "$dev" parent 1:4 handle 40: netem delay "$delay" "$jitter"
  tc filter add dev "$dev" protocol ip parent 1:0 prio 4 u32 match ip dst "$peer"/32 flowid 1:4
  netem_peer_show "$peer"
}

netem_peer_loss() {
  local peer="$1" loss="${2:-5%}" corr="${3:-25%}" delay="${4:-100ms}" jitter="${5:-20ms}" dev
  dev="$(netem_guard_peer "$peer")" || return 1
  tc qdisc del dev "$dev" root 2>/dev/null || true
  tc qdisc add dev "$dev" root handle 1: prio bands 4
  tc qdisc add dev "$dev" parent 1:4 handle 40: netem delay "$delay" "$jitter" loss "$loss" "$corr"
  tc filter add dev "$dev" protocol ip parent 1:0 prio 4 u32 match ip dst "$peer"/32 flowid 1:4
  netem_peer_show "$peer"
}

netem_peer_reorder() {
  local peer="$1" delay="${2:-20ms}" pct="${3:-25%}" corr="${4:-50%}" dev
  dev="$(netem_guard_peer "$peer")" || return 1
  tc qdisc del dev "$dev" root 2>/dev/null || true
  tc qdisc add dev "$dev" root handle 1: prio bands 4
  tc qdisc add dev "$dev" parent 1:4 handle 40: netem delay "$delay" reorder "$pct" "$corr"
  tc filter add dev "$dev" protocol ip parent 1:0 prio 4 u32 match ip dst "$peer"/32 flowid 1:4
  netem_peer_show "$peer"
}

netem_clear_peer() {
  local peer="$1" dev
  dev="$(netem_guard_peer "$peer")" || return 1
  tc qdisc del dev "$dev" root 2>/dev/null || true
  tc -s qdisc show dev "$dev"
}

backup_precheck() {
  echo '===== SELF ====='
  self_summary
  echo
  echo '===== QUORUM ====='
  k_quorum || true
  echo
  echo '===== TOPICS ====='
  k_topics --list || true
  echo
  echo '===== LOG DIRS ====='
  k_log_dirs $(all_node_ids | xargs echo) || true
  echo
  echo '===== DATA DIR ====='
  df -h "$DATA_HOST"
  du -sh "$DATA_HOST" 2>/dev/null || true
  backup_meta_show
}

backup_local_data_cold() {
  local out_dir="${1:-/tmp}" ts out_file manifest_file
  ts="$(date +%F_%H%M%S)"
  mkdir -p "$out_dir"
  out_file="$out_dir/kafka-node$(current_node_id)-$ts.tgz"
  manifest_file="$out_dir/kafka-node$(current_node_id)-$ts.manifest.txt"

  tar -C "$(dirname "$DATA_HOST")" -czf "$out_file" "$(basename "$DATA_HOST")"
  {
    echo "created_at=$ts"
    echo "cluster.id=$(current_cluster_id)"
    echo "node.id=$(current_node_id)"
    echo "broker.id=$(current_broker_id)"
    echo "self.ip=$(current_vm_ip)"
    echo "container=$C"
    echo "data_host=$DATA_HOST"
    echo "controller.quorum.voters=$(controller_voters_raw)"
    echo "sha256=$(sha256sum "$out_file" | awk '{print $1}')"
    echo '--- meta.properties ---'
    backup_meta_show
  } > "$manifest_file"

  echo "$out_file"
  echo "$manifest_file"
}

backup_archive_check() {
  local archive="$1"
  ls -lh "$archive"
  sha256sum "$archive"
  tar -tzf "$archive" | sed -n '1,40p'
}

restore_local_data_cold() {
  local archive="$1" ts parent base save_dir
  if [[ ! -f "$archive" ]]; then
    echo "Archive not found: $archive"
    return 1
  fi

  ts="$(date +%F_%H%M%S)"
  parent="$(dirname "$DATA_HOST")"
  base="$(basename "$DATA_HOST")"
  save_dir="$parent/${base}.pre_restore_$ts"

  echo "Stopping broker/container before restore..."
  broker_stop || true

  if [[ -d "$DATA_HOST" ]]; then
    mv "$DATA_HOST" "$save_dir"
  fi
  mkdir -p "$parent"
  tar -C "$parent" -xzf "$archive"
  sync

  echo "restore_current_dir=$DATA_HOST"
  echo "restore_previous_saved_as=$save_dir"
  ls -la "$DATA_HOST" | sed -n '1,40p'
  backup_meta_show
}

restore_postcheck_local() {
  echo '===== DATA DIR ====='
  df -h "$DATA_HOST"
  du -sh "$DATA_HOST" 2>/dev/null || true
  echo
  echo '===== META.PROPERTIES ====='
  backup_meta_show
  echo
  echo '===== TOP LEVEL FILES ====='
  find "$DATA_HOST" -maxdepth 2 -mindepth 1 | sed -n '1,80p'
}

k_partition_distribution() {
  local topic="$1"
  k_topics "--describe --topic $topic" | awk '/Partition:/{print}'
}

k_partition_distribution_all() {
  local t
  for t in $(k_topics --list); do
    echo "===== $t ====="
    k_partition_distribution "$t"
  done
}

help_kafka_lab() {
  cat <<'TXT'
Suggested quick flow:
  1) source ~/kafka_lab.sh
  2) self_summary
  3) k_create_test_topics
  4) w_quorum            # terminal A
  5) w_hot_p1            # terminal B
  6) k_producer_hot_p1   # terminal C
  7) run chaos on leader node of ha-hot-p1 partition 0

Useful commands:
  k_partition_leader ha-hot-p1 0
  k_partition_detail ha-hot-p1 0
  k_logs_controller 2m
  k_logs_replica 2m
  k_logs_storage 5m
  k_ping_all
  fw_show
  backup_precheck
  netem_route_to <peer-ip>
  netem_peer_delay <peer-ip> 300ms 80ms
TXT
}
