# 🦞 OpenClaw 설치 완료 — DELUXE

안녕하세요! OpenClaw 클라우드 설치가 완료되었습니다.
24시간 상시 운영되는 AI 비서가 준비되었습니다.

---

## 설치 요약

| 항목 | 상태 |
|------|:---:|
| VPS 서버 세팅 (Ubuntu) | ✅ |
| OpenClaw 설치 | ✅ |
| AI 모델 연결 | ✅ |
| Telegram 봇 연동 | ✅ |
| 봇 성격 커스텀 (SOUL.md) | ✅ |
| 운영 규칙 설정 (AGENTS.md) | ✅ |
| 보안 점검 + 하드닝 | ✅ |
| 데몬 등록 (자동 시작) | ✅ |
| SSH 키 인증 전환 | ✅ |
| 방화벽 (UFW) | ✅ |
| fail2ban (브루트포스 방지) | ✅ |
| 자동 보안 업데이트 | ✅ |

---

## 서버 정보

| 항목 | 값 |
|------|-----|
| 호스팅 | Hetzner Cloud |
| 서버 타입 | CX22 (2코어, 4GB RAM) |
| OS | Ubuntu 24.04 LTS |
| 서버 IP | `<IP_ADDRESS>` |
| SSH 사용자 | `openclaw` |
| 인증 방식 | SSH 키 (비밀번호 비활성화) |
| 월 비용 | €4.51 (~₩6,500) |

> 💡 서버 비용은 Hetzner에서 등록하신 결제수단으로 자동 청구됩니다.

---

## 봇 사용법

STANDARD의 모든 기능 + 아래 추가 기능:

### 24시간 상시 운영
- 컴퓨터를 꺼도 봇이 계속 동작합니다
- 서버가 자동으로 유지되므로 별도 관리가 필요 없습니다

### 봇 관리 명령어

Telegram에서 직접:

| 명령어 | 설명 |
|--------|------|
| `/status` | 봇 상태 확인 |
| `/reasoning` | 추론 모드 토글 |

서버 접속 후 (고급):

```bash
# 서버 접속
ssh openclaw@<IP_ADDRESS>

# 봇 관리
openclaw gateway status    # 상태 확인
openclaw gateway restart   # 재시작
```

---

## 보안 설정 현황

| 항목 | 상태 | 설명 |
|------|:---:|------|
| SSH 키 인증 | ✅ | 비밀번호 로그인 비활성화 |
| Root 로그인 | 🚫 | 차단됨 |
| UFW 방화벽 | ✅ | SSH(22)만 허용 |
| fail2ban | ✅ | SSH 무차별 공격 차단 |
| 자동 보안 업데이트 | ✅ | unattended-upgrades |
| Gateway 바인드 | ✅ | loopback만 (외부 접근 차단) |

---

## 자주 묻는 질문

**Q. 서버가 다운되면 어떻게 하나요?**
→ Hetzner 콘솔(console.hetzner.cloud)에서 서버 재시작 가능합니다. 또는 저에게 연락주세요.

**Q. 서버 비용을 아끼려면?**
→ CX22(€4.51/월)가 최소 사양입니다. 이 이하로는 내리기 어렵습니다.

**Q. 서버에 다른 것도 설치할 수 있나요?**
→ 네, 본인 서버이므로 자유롭게 사용 가능합니다. 다만 OpenClaw과 충돌할 수 있으니 사전에 문의해주세요.

**Q. 봇 응답이 안 와요**
→ `ssh openclaw@<IP> -c "openclaw gateway restart"` 또는 저에게 연락주세요.

*+ STANDARD FAQ 내용도 동일하게 적용됩니다.*

---

## 사후 관리

- **기간**: 설치 완료일로부터 **2주**
- **범위**: 서버 오류, 봇 설정 변경, 보안 업데이트, 사용법 질문
- **연락**: Kmong 메시지 또는 Telegram DM
- **응답 시간**: 업무일 기준 24시간 이내
- **서버 관리**: 기간 내 서버 모니터링 포함

---

## Hetzner 관리 팁

- **서버 상태 확인**: [console.hetzner.cloud](https://console.hetzner.cloud)
- **비용 확인**: Hetzner 대시보드 → Billing
- **서버 재시작**: 대시보드 → 서버 선택 → Power → Restart
- **스냅샷 생성** (백업): 서버 선택 → Snapshots → Create Snapshot

> 💡 한 달에 한 번 정도 스냅샷을 찍어두면, 문제 발생 시 복원이 쉽습니다.

---

*문의사항이 있으시면 언제든 연락주세요. 감사합니다! 🙇‍♂️*

— Yongwon Jeon
