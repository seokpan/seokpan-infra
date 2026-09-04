MariaDB Full+Incremental 체이닝 백업/NFS 전송/Retention 자동화 + 복구 자동화
(이슈 #55/#114/#128/#129, PR #117/#125/#130/#131)

> 이 role은 처음에 단일 Full 백업(#55)으로 시작해, Full+Incremental 체이닝(#114)으로
> 확장되었고, 이후 레거시 단일 Full 경로는 완전히 제거(#128)되었습니다. 현재는
> 체이닝 방식 하나만 존재하며, Full 스킵 시 Incremental이 자동 승격되는 로직(#129)이
> 추가된 최신 상태입니다. 이 문서는 그 최종 상태만 설명합니다.

## 평상시 — 자동 백업 (사람 개입 불필요)

mariadb-01/02 양쪽에 cron이 등록되어 있고, 스크립트가 실행 시점마다 "지금 내가
Replica인지"를 스스로 판별합니다. Master/Replica가 failover로 바뀌어도 사람이
개입할 필요 없습니다.

- **Full**: 매주 일요일 02:00
- **Incremental**: 그 외 요일 02:00

동일 스크립트(`backup_chain.sh.j2`)를 `--mode full|incr` 인자로만 구분해 cron 2건으로
등록되어 있습니다.

- 그날 데이터 변경 없으면(GTID 비교) 백업 자체를 스킵
- **Incremental 실행 시점에 이번 주 유효한 체인이 없으면, 스킵하지 않고 그 시점을
  새 체인의 Full로 자동 승격**합니다(#129). 예정된 일요일 Full이 GTID 미변경으로
  스킵됐더라도, 이후 평일에 실제 데이터 변경이 생기면 그 시점에 즉시 캡처되어 RPO
  공백이 최대 1주일까지 벌어지는 문제를 방지합니다.
- 체인 단위로 7일 지난 백업은 로컬/NFS 양쪽에서 자동 삭제 (진행 중인 이번 주 체인은
  보호 대상에서 제외되지 않도록 별도 판정)

로그 확인:
```bash
maxctrl --tsv list servers   # 현재 실제 Replica 확인 (maxscale-01에서)
tail -50 /var/log/seokpan/mariadb_backup.log
```

승격이 발생하면 로그에 아래 문구가 남습니다(정상 스킵과 구분되는 NOTICE):
```
NOTICE: 예정된 Full 부재로 이번 Incremental 요청을 Full로 승격 처리
```

## 지금 바로 백업하고 싶을 때 (수동 트리거)

cron 시간까지 기다리지 않고 즉시 백업하려면, **현재 Replica인 서버**에서 직접 실행:

```bash
maxctrl --tsv list servers                        # 1) 현재 Replica 확인
/usr/local/sbin/seokpan_mariadb_backup_chain.sh full   # 2) Full 백업
/usr/local/sbin/seokpan_mariadb_backup_chain.sh incr   # 또는 Incremental 백업
```

## 백업 목록 확인

```bash
ls -la /mnt/nfs-db-backup/            # NFS 마운트 — 모든 mariadb 서버에서 동일하게 보임 (권장)
cat /srv/nfs/db-backup/.backup_chain_state.json   # 현재 진행 중인 체인 상태 확인
```

**디렉터리/파일 명명 규칙 (#129 기준)**:
- 체인: `chain_<YYYYMMDD>` — 그 체인의 Full이 실제로 만들어진 날짜
- Full: `chain_<날짜>/full_<YYYYMMDD_HHMMSS>` — 체인당 1개
- Incremental: `chain_<날짜>/incr_<NN>_<YYYYMMDD_HHMMSS>` — `NN`은 체인 시작 시
  `01`부터 시작하는 2자리 순번

상태 파일(`​.backup_chain_state.json`) 필드:

| 필드 | 의미 |
|---|---|
| `chain_dir` | 진행 중인 체인 디렉터리명 |
| `last_backup_dir` | 가장 최근 백업 경로(다음 Incremental의 `--incremental-basedir`로 사용) |
| `last_gtid` | 마지막 백업 시점 GTID (변경 없으면 스킵 판단 기준, Full/Incremental 공통) |
| `incr_seq` | 현재 체인 내 Incremental 순번 카운터 (새 체인 시작 시 0으로 리셋) |
| `chain_origin` | `scheduled`(정규 일요일 Full) 또는 `promoted`(#129 승격으로 생성된 Full) — 감사 추적용 |

**어떤 시점으로 복구할지는 담당자가 판단합니다.**

## 복구 (시점 선택은 사람, 이후는 자동)

체인(Full+Incremental) 전체를 롤포워드 병합해서 복구합니다. 복구할 체인 디렉터리명만
지정하면 됩니다 — Full 하나만 있는 체인(구성요소 1개)도 정상 처리됩니다.

```bash
ansible-playbook playbooks/mariadb_restore_chain.yml -l <복구를_수행할_호스트> --ask-vault-pass \
  -e backup_restore_chain_dir=chain_<선택한_날짜>
```

- `-l`: **반드시 정확히 1개 호스트를 지정해야 합니다.** 누락 시 Play 맨 앞의 Guard
  (`ansible_play_hosts_all | length == 1`)에서 다른 태스크 실행 전에 즉시 실패합니다
  — mariadb-01/02 양쪽에서 동시에 복구가 실행되는 사고를 막기 위한 안전장치입니다.
- `-e backup_restore_chain_dir`: 복구할 체인 디렉터리명 — **여기까지만 사람이 정하고
  이후는 전부 자동**:
  1. NFS 백업 경로에서 체인 전체를 작업 디렉터리로 워킹 카피(원본 보존)
  2. 체인 구성요소(`full_*`, `incr_*`)를 이름 순으로 자동 탐색·정렬
     (`full_` → `incr_01` → `incr_02` … 순, Full이 반드시 1개 있는지 확인)
  3. **각 구성요소별 `SHA256SUMS` 무결성 검증** (롤포워드 이전 raw 기준) — 하나라도
     불일치하면 여기서 즉시 실패
  4. **롤포워드**: Full 단독 `--prepare` 후 각 Incremental을 순서대로
     `--incremental-dir`로 반복 `--prepare` (MariaDB 10.2+ 공식 절차 —
     `--apply-log-only`는 10.1 전용 옵션으로 10.2+에서 제거되어 사용하지 않음)
  5. `--copy-back` → 데이터 디렉터리 권한 복원
  6. 격리 systemd 인스턴스(`mariadb-restore`) 기동 — 운영 인스턴스와 별개 데이터
     디렉터리/소켓 사용, **`--skip-networking`으로 TCP 리스너 자체가 없고 소켓
     접속만 가능**(운영 서비스에 영향 없음, 불필요한 네트워크 노출 차단)
  7. **표본 검증 3단 Gate** — 하나라도 불일치하면 그 지점에서 Play가 실패
     (`debug` 출력이 아니라 `assert`로 구현)
     - **Count**: `SELECT COUNT(*)` 비교
     - **PK**: `CHECKSUM TABLE` 비교 (단순 개수가 아니라 행 내용 전체 비교 —
       유실/중복/변조까지 탐지)
     - **FK**: `stone_game_schema_v1.sql` 기준 실제 FK 관계 7건(member_stats→member,
       game_participant→game/member, move→game, game_result→game,
       rating_history→member/game)의 고아 행 존재 여부 확인

## 복구 후 정리 (자동화 미포함 — 의도적)

검증용 인스턴스라 계속 켜둘 필요 없으면 수동으로 정리합니다. 데이터 삭제가 포함돼
실수 방지를 위해 자동화에 넣지 않았습니다.

```bash
# [isolated] 격리 인스턴스 자체를 정리하는 경우
systemctl stop mariadb-restore
rm -rf /var/lib/mysql-restore-test

# 체인 롤포워드 워킹 카피 — isolated/production 모드 공통으로 항상 생성됨(이슈 #119).
# --prepare가 이 디렉터리 안에서 파일을 직접 변형시키므로 재사용 불가한 일회성 데이터.
# --copy-back으로 필요한 내용은 이미 대상 datadir로 옮겨진 뒤이므로 항상 안전하게 삭제 가능.
rm -rf /var/lib/mysql-restore-chain-working
```

> production 모드(이슈 #119, [4])로 실행한 경우 `/var/lib/mysql-restore-test`는
> 애초에 생성되지 않으므로, 위 중 체인 워킹 카피 삭제 한 줄만 해당됩니다.

## 사람이 하는 일 vs 자동화가 하는 일

| 구분 | 담당자 | 자동화 |
|---|---|---|
| 백업 | 없음 (수동 트리거 시에만 스크립트 실행) | 대상 판별·Full/Incremental 구분·승격 판단·Checksum·NFS 전송·체인 단위 Retention |
| 복구 | 복구할 체인 선택, 복구 호스트(`-l`) 선택 | 구성요소 탐색·무결성 검증·롤포워드·copy-back·권한 복원·기동·Count/PK/FK 3단 Gate |
| 복구 후 정리 | 종료·삭제 여부 판단 및 실행 | (미포함) |

## 스코프 경계 (중요)

이 role의 복구는 **"백업본이 온전한지 검증"까지가 스코프**입니다. 검증된 백업본으로
실제 운영 서비스를 재개시키는 절차(TCP 개방, MaxScale `MariaDB-Monitor` 편입, 복제
토폴로지 재구성, `read_only` 재설정)는 이 role의 범위 밖이며, 별도 이슈(#119)로
분리되어 있습니다.

## 명명 구조는 임시입니다 (#129)

현재 디렉터리 구조(체인 하나에 `full_*`/`incr_*`를 평면으로 나열)는 초기 운영 단계용
임시 구조입니다. Incremental 누적 크기가 Full 크기의 20~30%를 반복적으로 넘어서거나
백업 유형별 용량을 정식으로 모니터링해야 하는 요구가 생기면, `chain_<날짜>/full/`,
`chain_<날짜>/incremental/`처럼 타입별 폴더로 분리하는 구조로 전환을 검토합니다
(전환 시 `restore_chain.yml`의 탐색 로직 재작성 필요 — 별도 이슈로 분리 예정).

## 주요 변수 (`defaults/main.yml`)

| 변수 | 기본값 | 설명 |
|---|---|---|
| `backup_transfer_retention_days` | 7 | 보관 기간(일), 체인 단위로 적용 |
| `backup_transfer_full_cron_weekday`/`_hour`/`_minute` | 0(일요일) / 2 / 0 | Full 백업 cron |
| `backup_transfer_incr_cron_weekday`/`_hour`/`_minute` | 1-6(월~토) / 2 / 0 | Incremental 백업 cron |
| `backup_transfer_chain_script_path` | `/usr/local/sbin/seokpan_mariadb_backup_chain.sh` | 배포되는 백업 스크립트 경로 |
| `backup_transfer_state_file` | `{{ backup_transfer_local_base_dir }}/.backup_chain_state.json` | 체인 상태 JSON |
| `backup_transfer_role_stabilize_max_retries` | 6 | failover 전환 중 재확인 횟수 |
| `backup_transfer_role_stabilize_retry_interval_seconds` | 300 | 재확인 간격(초) |
| `backup_restore_chain_dir` | `""` (필수 extra-vars) | 복구할 체인 디렉터리명, 예: `chain_20260907` |
| `backup_restore_chain_working_dir` | `/var/lib/mysql-restore-chain-working` | 체인 복구 워킹 디렉터리 |
| `backup_restore_target_dir` | `/var/lib/mysql-restore-test` | 격리 복구 데이터 디렉터리 |
| `backup_restore_validation_tables` | 7개 테이블 | 표본 검증 대상 (member, member_stats, game, game_participant, move, game_result, rating_history) |
| `backup_restore_fk_checks` | 7개 관계 | FK 무결성 Gate 대상 (`stone_game_schema_v1.sql` 기준) |
| `backup_restore_port` | 3307 | (참고용, 현재 `--skip-networking`으로 미사용 — 향후 TCP 필요 시 대비해 유지) |
| `backup_restore_preserve_corrupted_datadir` | `false` | 기존 datadir 보존 여부. F-5(실 서비스 오픈 전 정리) 완료 후 `true`로 전환 필수 |
| `mariadb_monitor_name` | `MariaDB-Monitor` | `maxctrl call command mariadbmon failover` 대상 모니터명 |
| `dr_failsafe_read_only_cnf_path` | `/etc/my.cnf.d/zz-dr-failsafe-read-only.cnf` | Split-brain 방지 임시 안전장치 파일 경로 |

## 변경 이력 요약

| 이슈/PR | 내용 |
|---|---|
| #55 / PR #117 | 최초: 단일 Full 백업/복구 자동화 |
| #114 / PR #125 | Full+Incremental 체이닝 방식으로 확장 |
| #128 / PR #130 | 레거시 단일 Full 백업/복구 코드 완전 제거 (체이닝으로 단일화) |
| #129 / PR #131 | Incremental→Full 자동 승격, `chain_<날짜>`/`incr_<NN>_<타임스탬프>` 명명 규칙 도입 |

## DR 복구본 운영 재개 반자동화 (이슈 #119, 신규)

> ⚠️ **주의**: 위 "복구" 섹션은 여전히 `mariadb_restore.yml`/단일 Full 백업 시절 설명이
> 남아있어 실제 코드(`restore_chain.yml`, 체인 기반)와 어긋나 있습니다. 이 문서 전체
> 최신화는 별도로 진행 필요 — 이 섹션은 신규 추가분만 우선 반영합니다.

위 "복구"(`mariadb_restore_chain.yml`, `restore_chain.yml`)는 **"백업본이 온전한지
검증"**까지만 다룹니다(격리 인스턴스, `--skip-networking`). 실제로 서버가 죽어서
그 백업으로 서비스를 되살려야 하는 상황에서는 `mariadb_dr_recovery.yml`을 사용합니다.

**절대 한 번에 전부 실행되지 않습니다.** 4단계(Checkpoint)로 나뉘어 있고, `--tags`로
한 단계씩만 실행됩니다. 각 단계 결과를 사람이 직접 확인한 뒤 다음 단계를 실행하세요.

```bash
# [4] 운영 datadir 복구 (완전 자동) — ⚠️ 대상 호스트의 /var/lib/mysql을 삭제 후 교체합니다
ansible-playbook playbooks/mariadb_dr_recovery.yml -l <복구할_호스트> --ask-vault-pass \
  --tags restore \
  -e backup_restore_mode=production \
  -e backup_restore_chain_dir=chain_<선택한_체인_타임스탬프>

# [5] 복제 재구성 (반자동 — Master/Replica 역할은 사람이 판단해 지정)
ansible-playbook playbooks/mariadb_dr_recovery.yml -l <복구할_호스트> --ask-vault-pass \
  --tags replication \
  -e backup_restore_role=replica
  # Master 자동 판별 실패(양쪽 다 유실) 시에만 아래 추가:
  # -e backup_restore_master_host=<살아있는_반대쪽_호스트_IP>

# [6] MaxScale 재편입 확인 (확인만 자동, 신규 등록 아님)
ansible-playbook playbooks/mariadb_dr_recovery.yml -l <복구할_호스트> --ask-vault-pass \
  --tags maxscale_verify \
  -e backup_restore_role=replica

# [7] 서비스 재개 전 최종 체크리스트 출력 (자동 체크리스트, 서비스 재개 승인은 사람이 직접)
ansible-playbook playbooks/mariadb_dr_recovery.yml -l <복구할_호스트> --ask-vault-pass \
  --tags checklist \
  -e backup_restore_role=replica
```

### [4]에서 격리 검증과 달라지는 점 (`backup_restore_mode: production`)

| 항목 | isolated(기존, 기본값) | production(신규) |
|---|---|---|
| 대상 디렉터리 | `/var/lib/mysql-restore-test` | 실제 운영 `/var/lib/mysql` |
| 기존 데이터 처리 | 삭제 후 재생성 | `backup_restore_preserve_corrupted_datadir` 변수로 제어(기본 `false`=즉시 삭제, `true`=`.corrupted.<timestamp>` 보존 후 교체). **실 서비스 데이터가 쌓이는 시점(F-5 정리 이후)에는 반드시 `true`로 전환** |
| 기동 서비스 | 임시 `mariadb-restore.service`(포트 3307, `--skip-networking`) | 정식 `mariadb.service` |
| Count/PK/FK Gate | `assert`(불일치 시 Play 실패) | **정보성 리포트로 전환**(지난 백업 시점과 현재 운영 Master 사이의 정상적 데이터 간극 때문 — [5]가 이후 따라잡음). SHA256SUMS 무결성 검증은 두 모드 모두 하드 Gate 유지 |

### [7] R/W 헬스체크가 영구 테이블을 쓰지 않는 이유

`stone_game`의 테이블 스키마는 Backend Alembic Migration이 유일한 기준으로 이미
확정되어 있습니다(이슈 #89 코멘트). 이 헬스체크는 영구 테이블을 신설하는 대신
**`CREATE TEMPORARY TABLE`**을 사용해 커넥션 종료 시 자동 삭제되도록 했습니다 —
Alembic 관리 스키마와 완전히 무관하며 별도 정리도 필요 없습니다. 전용 계정
(`dr_healthcheck_svc`)은 `CREATE TEMPORARY TABLES` 권한만 가지고 있습니다.

**신규 Vault 변수 추가 필요**: `dr_healthcheck_svc_password` — 다른 5개 계정과
동일한 방식으로 `ansible-vault edit group_vars/all/vault.yml`에 추가할 것.

### 신규 계정 안내

`dr_healthcheck_svc` 계정을 이 이슈에서 신설했습니다(영구 테이블 접근 권한 없음,
`CREATE TEMPORARY TABLES`만 보유).

### Master 0개(양쪽 다 유실) 시나리오 (PR #133 리뷰 반영, 2026-09-04)

두 서버가 동시에 유실되어 살아있는 Master가 하나도 없는 최악의 시나리오도 지원합니다.

- [4] 실행 시 `detect_master`가 실패하면(Master 0개), production 모드에서는
  Play를 죽이지 않고 `mariadb_master_detected=false`로 기록한 뒤 계속 진행합니다
  (isolated 모드는 기존처럼 하드 실패 — 격리 검증은 항상 살아있는 비교 대상이
  있다는 전제이므로).
- 이 경우 Count/CHECKSUM 비교는 "N/A(Master 미검출로 비교 대상 없음)" 정보성
  안내로 대체되고, SHA256SUMS 무결성/FK Gate는 그대로 하드 Gate로 통과해야 합니다.
- [5]에서는 반드시 `-e backup_restore_role=master`로 지정하세요(`replica` 아님 —
  붙을 살아있는 Master가 없으므로 이 서버 자신이 새 Master가 되어야 합니다).
- [6]에서 이 서버가 아직 MaxScale에 Master로 인식되지 않았다면, 코드가 자동으로
  `maxctrl call command mariadbmon failover MariaDB-Monitor`를 실행해 실제 승격을
  강제합니다(이미 인식된 상태라면 이 명령은 실행되지 않고 확인만 하고 넘어갑니다).

**실측(2026-09-04, mariadb-01/02 양쪽 실제 정지로 재현)**: [4]→[5]→[6]→[7] 전체
End-to-End 통과 확인. 다만 이 환경에서는 복제 미설정 상태의 고립 서버를 MaxScale이
`auto_failover` 설정과 무관하게 즉시 Master로 판정하는 것으로 확인되어, 위 failover
강제 트리거가 실제로 발동하는 상황은 이번 실측에서는 재현되지 않았습니다(방어 코드로
유지).

### Split-brain 방지 안전장치 (PR #133 리뷰 반영, 2026-09-04)

위 시나리오 실측 중 다음 위험을 발견했습니다: 복제 설정이 없고 `read_only`도 아닌
서버는 `auto_failover` 설정과 무관하게 MaxScale이 즉시 "고립된 Master"로 판정합니다.
따라서 양쪽 다 유실된 상태에서 한쪽이 새 Master로 확립된 뒤, **나머지 한쪽이 복제
재구성 없이 그냥 기동되면 그 쪽도 독립적으로 Master로 오판정되어 Split-brain이
발생할 수 있습니다.**

이를 막기 위해 [6]에서 role=master로 확립되는 즉시, 같은 `mariadbs` 그룹의 나머지
호스트에 `/etc/my.cnf.d/zz-dr-failsafe-read-only.cnf`(`read_only=1`)를 자동
배포합니다(서비스 재기동 없이 파일만 배치 — 다음 기동을 대비하는 것). 이 파일이
배치된 호스트는 **반드시 이 playbook([5] `role=replica`)으로 정식 재편입해야
안전장치가 자동 해제**됩니다 — 수동으로 그냥 `systemctl start mariadb`로 켜지 마세요.
정상 재편입이 확인되면 `replication_setup.yml`이 자동으로 파일을 제거하고, 이후엔
기존 정책(이슈 #50)대로 MaxScale이 read_only를 런타임 관리합니다.

대상 호스트가 도달 불가(하드웨어 장애 등 진짜 유실) 상태라 배치 자체가 실패해도
문제없습니다 — 나중에 그 서버를 이 playbook으로 되살릴 때 자연히 정상 상태가 됩니다.

> ⚠️ 이 안전장치 코드는 `--syntax-check` 통과까지 확인했으며, 실제 재현 검증(세
> 번째 서버 다운/재기동 테스트)은 다음 DR 훈련으로 이월되었습니다.
