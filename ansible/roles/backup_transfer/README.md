MariaDB Full 백업/NFS 전송/Retention 자동화 + 복구 자동화 (이슈 #55)

## 평상시 — 자동 백업 (사람 개입 불필요)

mariadb-01/02 양쪽에 cron이 매일 02:00 등록되어 있고, 스크립트가 실행 시점마다
"지금 내가 Replica인지"를 스스로 판별합니다. Master/Replica가 failover로 바뀌어도
사람이 개입할 필요 없습니다.

- 그날 데이터 변경 없으면 백업 자체를 스킵 (GTID 비교)
- 7일 지난 백업은 로컬/NFS 양쪽에서 자동 삭제

로그 확인:
```bash
maxctrl --tsv list servers   # 현재 실제 Replica 확인 (maxscale-01에서)
tail -50 /var/log/seokpan/mariadb_backup.log
tail -50 /var/log/seokpan/mariadb_backup_cron.log
```

## 지금 바로 백업하고 싶을 때 (수동 트리거)

cron 시간까지 기다리지 않고 즉시 백업하려면, **현재 Replica인 서버**에서 직접 실행:

```bash
maxctrl --tsv list servers   # 1) 현재 Replica 확인
/usr/local/sbin/seokpan_mariadb_backup.sh   # 2) 그 서버에서 실행
```

## 백업 목록 확인

```bash
ls -la /mnt/nfs-db-backup/   # NFS 마운트 — 모든 mariadb 서버에서 동일하게 보임 (권장)
```

`full_YYYYMMDD_HHMMSS` 형식으로 시점 구분. **어떤 시점으로 복구할지는 담당자가 판단.**

## 복구 (시점 선택은 사람, 이후는 자동)

```bash
ansible-playbook playbooks/mariadb_restore.yml -l <복구를_수행할_호스트> --ask-vault-pass \
  -e backup_restore_source_dir=/mnt/nfs-db-backup/full_<선택한_타임스탬프>
```

- `-l`: 격리 인스턴스를 띄울 대상 호스트 (운영 인스턴스와 별개 포트/데이터 디렉터리라 그 서버의 운영 서비스에는 영향 없음)
- `-e backup_restore_source_dir`: 복구에 쓸 백업 경로 — **여기까지만 사람이 정하고 이후는 전부 자동**(`--copy-back` → 권한 복원 → 격리 systemd 인스턴스 기동 → 표본 Row Count 비교까지 자동 수행, 마지막에 비교 결과 출력)

## 복구 후 정리 (자동화 미포함 — 의도적)

검증용 인스턴스라 계속 켜둘 필요 없으면 수동으로 정리합니다. 데이터 삭제가 포함돼
실수 방지를 위해 자동화에 넣지 않았습니다.

```bash
systemctl stop mariadb-restore
rm -rf /var/lib/mysql-restore-test /var/lib/mysql-restore-test-working
```

## 사람이 하는 일 vs 자동화가 하는 일

| 구분 | 담당자 | 자동화 |
|---|---|---|
| 백업 | 없음 (수동 트리거 시에만 스크립트 실행) | 대상 판별·백업·Checksum·NFS 전송·Retention |
| 복구 | 백업 시점 선택, 복구 호스트 선택 | copy-back·권한 복원·기동·표본 검증 |
| 복구 후 정리 | 종료·삭제 여부 판단 및 실행 | (미포함) |

## 주요 변수 (`defaults/main.yml`)

| 변수 | 기본값 | 설명 |
|---|---|---|
| `backup_transfer_retention_days` | 7 | 보관 기간(일) |
| `backup_transfer_cron_hour`/`_minute` | 2 / 0 | 매일 02:00 |
| `backup_transfer_role_stabilize_max_retries` | 6 | failover 전환 중 재확인 횟수 |
| `backup_transfer_role_stabilize_retry_interval_seconds` | 300 | 재확인 간격(초) |
| `backup_restore_target_dir` | `/var/lib/mysql-restore-test` | 격리 복구 데이터 디렉터리 |
| `backup_restore_port` | 3307 | 격리 인스턴스 포트 |
