#!/bin/bash
# ============================================================================
# OpenClaw 보안 점검 스크립트
#
# 고객 시스템에서 실행하여 보안 상태를 체크합니다.
# 결과를 마크다운으로 출력 → PDF 변환 가능.
#
# 사용법:
#   bash security-audit.sh                    # 터미널 출력
#   bash security-audit.sh > report.md        # 마크다운 파일로 저장
#   bash security-audit.sh --pdf              # PDF 생성 (pandoc 필요)
#
# 등급: STANDARD (기본), DELUXE (SSH 키 포함), PREMIUM (풀 하드닝)
# ============================================================================

set -uo pipefail

TIER="${TIER:-STANDARD}"  # STANDARD | DELUXE | PREMIUM
PDF_MODE=0
if [[ "${1:-}" == "--pdf" ]]; then PDF_MODE=1; fi

# 색상 (터미널용, 마크다운에선 무시)
PASS="✅"
FAIL="❌"
WARN="⚠️"
INFO="ℹ️"

TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0

check() {
  local status="$1"
  local msg="$2"
  TOTAL=$((TOTAL + 1))
  case "$status" in
    pass) PASSED=$((PASSED + 1)); echo "$PASS  $msg" ;;
    fail) FAILED=$((FAILED + 1)); echo "$FAIL  $msg" ;;
    warn) WARNINGS=$((WARNINGS + 1)); echo "$WARN  $msg" ;;
    info) echo "$INFO  $msg" ;;
  esac
}

# ============================================================================
# 리포트 헤더
# ============================================================================
echo "# 🦞 OpenClaw 보안 점검 리포트"
echo ""
echo "- **날짜**: $(date '+%Y-%m-%d %H:%M')"
echo "- **호스트**: $(hostname)"
echo "- **OS**: $(uname -s) $(uname -r) ($(uname -m))"
echo "- **사용자**: $(whoami)"
echo "- **점검 등급**: $TIER"
echo ""
echo "---"
echo ""

# ============================================================================
# 1. 파일 권한 점검
# ============================================================================
echo "## 1. 파일 권한"
echo ""

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
if [[ -f "$CONFIG_FILE" ]]; then
  PERMS=$(stat -f "%Lp" "$CONFIG_FILE" 2>/dev/null || stat -c "%a" "$CONFIG_FILE" 2>/dev/null)
  if [[ "$PERMS" == "600" ]]; then
    check pass "openclaw.json 권한: $PERMS (올바름)"
  else
    check fail "openclaw.json 권한: $PERMS → 600이어야 합니다. \`chmod 600 $CONFIG_FILE\`"
  fi
else
  check fail "openclaw.json 파일 없음"
fi

# auth-profiles 권한
AUTH_FILES=$(find "$HOME/.openclaw" -name "auth-profiles.json" 2>/dev/null)
if [[ -n "$AUTH_FILES" ]]; then
  while IFS= read -r f; do
    PERMS=$(stat -f "%Lp" "$f" 2>/dev/null || stat -c "%a" "$f" 2>/dev/null)
    if [[ "$PERMS" == "600" ]]; then
      check pass "$(basename "$(dirname "$(dirname "$f")")")/auth-profiles.json: $PERMS"
    elif [[ "$PERMS" == "644" ]]; then
      check warn "$(basename "$(dirname "$(dirname "$f")")")/auth-profiles.json: $PERMS → 600 권장. \`chmod 600 $f\`"
    else
      check fail "$(basename "$(dirname "$(dirname "$f")")")/auth-profiles.json: $PERMS → 600 필수"
    fi
  done <<< "$AUTH_FILES"
fi

# credentials 디렉토리
CRED_DIR="$HOME/.openclaw/credentials"
if [[ -d "$CRED_DIR" ]]; then
  CRED_PERMS=$(stat -f "%Lp" "$CRED_DIR" 2>/dev/null || stat -c "%a" "$CRED_DIR" 2>/dev/null)
  if [[ "$CRED_PERMS" == "700" ]]; then
    check pass "credentials 디렉토리: $CRED_PERMS (올바름)"
  else
    check warn "credentials 디렉토리: $CRED_PERMS → 700 권장"
  fi
fi
echo ""

# ============================================================================
# 2. API 키 노출 점검
# ============================================================================
echo "## 2. API 키 노출 점검"
echo ""

if [[ -f "$CONFIG_FILE" ]]; then
  # config에 평문 키가 있는지 마스킹 확인
  KEY_COUNT=$(node -e '
    const c = JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
    let count = 0;
    // botToken, gatewayToken 등 정상 운영 필드는 제외
    const SAFE_KEYS = new Set(["botToken","gatewayToken","webhookSecret"]);
    const scan = (obj) => {
      for (const [k,v] of Object.entries(obj||{})) {
        if (SAFE_KEYS.has(k)) continue;
        if (/apiKey|api_key|secret|password/i.test(k) && typeof v === "string" && v.length > 10) count++;
        else if (typeof v === "object" && v !== null) scan(v);
      }
    };
    scan(c);
    console.log(count);
  ' "$CONFIG_FILE" 2>/dev/null || echo "0")

  if [[ "$KEY_COUNT" -gt 0 ]]; then
    check warn "config에 민감 API 키 ${KEY_COUNT}개 발견 — 환경변수 또는 Keychain 이전 권장"
  else
    check pass "config에 평문 API 키 없음"
  fi
fi

# 환경변수에 키 노출
ENV_KEYS=$(env | grep -iE "ANTHROPIC_API|OPENAI_API|GEMINI_API|BOT_TOKEN" | wc -l | tr -d ' ')
if [[ "$ENV_KEYS" -gt 0 ]]; then
  check warn "환경변수에 API 키 ${ENV_KEYS}개 노출 (세션 종료 후 사라짐)"
else
  check pass "환경변수에 API 키 노출 없음"
fi

# shell history에 키 유출
HIST_KEYS=0
for hf in "$HOME/.bash_history" "$HOME/.zsh_history"; do
  if [[ -f "$hf" ]]; then
    HK=$(grep -ciE "sk-ant-|sk-proj-|AIzaSy" "$hf" 2>/dev/null || echo "0")
    HIST_KEYS=$((HIST_KEYS + HK))
  fi
done
if [[ "$HIST_KEYS" -gt 0 ]]; then
  check fail "셸 히스토리에 API 키 패턴 ${HIST_KEYS}건 발견! 삭제 권장"
else
  check pass "셸 히스토리에 API 키 없음"
fi
echo ""

# ============================================================================
# 3. 네트워크 보안
# ============================================================================
echo "## 3. 네트워크 보안"
echo ""

# Gateway 바인딩 확인
if [[ -f "$CONFIG_FILE" ]]; then
  GW_BIND=$(node -e '
    const c = JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
    console.log(c.gateway?.bind || c.gatewayBind || "unknown");
  ' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
  
  if [[ "$GW_BIND" == "loopback" || "$GW_BIND" == "127.0.0.1" ]]; then
    check pass "Gateway 바인딩: $GW_BIND (로컬만 접근 가능)"
  elif [[ "$GW_BIND" == "0.0.0.0" || "$GW_BIND" == "all" ]]; then
    check fail "Gateway 바인딩: $GW_BIND → 외부 노출! loopback으로 변경 필수"
  else
    check info "Gateway 바인딩: $GW_BIND"
  fi
fi

# macOS 방화벽
if [[ "$(uname -s)" == "Darwin" ]]; then
  if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -qi "enabled"; then
    check pass "macOS 방화벽: 활성화됨"
  else
    check warn "macOS 방화벽: 비활성화 → 시스템 설정에서 활성화 권장"
  fi
fi

# SSH 상태
if [[ "$(uname -s)" == "Darwin" ]]; then
  SSH_ON=$(systemsetup -getremotelogin 2>/dev/null | grep -ci "on" || true)
else
  SSH_ON=$(systemctl is-active sshd 2>/dev/null | grep -c "active" || systemctl is-active ssh 2>/dev/null | grep -c "active" || true)
fi

if [[ "${SSH_ON:-0}" -gt 0 ]]; then
  check info "SSH: 활성화됨 (DELUXE+ 고객은 키 인증 전환 확인)"
else
  check pass "SSH: 비활성화됨"
fi

# 열린 포트 확인
echo ""
echo "### 열린 포트 (LISTEN)"
echo '```'
if [[ "$(uname -s)" == "Darwin" ]]; then
  lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR>1{print $1, $9}' | sort -u | head -20 || \
  netstat -an 2>/dev/null | grep LISTEN | head -20 || \
  echo "(포트 목록 조회 실패 — sudo 권한 필요할 수 있음)"
else
  ss -tlnp 2>/dev/null | tail -n +2 | awk '{print $4}' | head -20
fi
echo '```'
echo ""

# ============================================================================
# 4. Gateway 상태
# ============================================================================
echo "## 4. Gateway 상태"
echo ""

if command -v openclaw &>/dev/null; then
  GW_STATUS=$(openclaw gateway status 2>/dev/null || echo "확인 불가")
  if echo "$GW_STATUS" | grep -qi "running"; then
    check pass "Gateway 실행 중"
  else
    check warn "Gateway 미실행: \`openclaw gateway start\`"
  fi
  
  # 버전
  OC_VER=$(openclaw --version 2>/dev/null || echo "?")
  check info "OpenClaw 버전: $OC_VER"
else
  check fail "OpenClaw 미설치"
fi

# Daemon 설정
if [[ "$(uname -s)" == "Darwin" ]]; then
  DAEMON_PLIST="$HOME/Library/LaunchAgents/com.openclaw.gateway.plist"
  if [[ -f "$DAEMON_PLIST" ]]; then
    check pass "LaunchAgent 데몬 설정됨 (재부팅 시 자동시작)"
  else
    check warn "LaunchAgent 없음 → 재부팅 시 수동 시작 필요"
  fi
else
  if systemctl --user is-enabled openclaw-gateway 2>/dev/null | grep -q "enabled"; then
    check pass "systemd user unit 활성화됨"
  else
    check warn "systemd unit 미등록 → 재부팅 시 수동 시작 필요"
  fi
fi
echo ""

# ============================================================================
# 5. DELUXE+ 전용: SSH 키 인증 점검
# ============================================================================
if [[ "$TIER" == "DELUXE" || "$TIER" == "PREMIUM" ]]; then
  echo "## 5. SSH 키 인증 (DELUXE+)"
  echo ""
  
  AUTH_KEYS="$HOME/.ssh/authorized_keys"
  if [[ -f "$AUTH_KEYS" ]]; then
    KEY_COUNT=$(wc -l < "$AUTH_KEYS" | tr -d ' ')
    check pass "authorized_keys: ${KEY_COUNT}개 등록됨"
    
    AK_PERMS=$(stat -f "%Lp" "$AUTH_KEYS" 2>/dev/null || stat -c "%a" "$AUTH_KEYS" 2>/dev/null)
    if [[ "$AK_PERMS" == "600" ]]; then
      check pass "authorized_keys 권한: $AK_PERMS"
    else
      check fail "authorized_keys 권한: $AK_PERMS → 600 필수"
    fi
  else
    check warn "authorized_keys 없음 → SSH 키 등록 필요"
  fi
  
  # 비밀번호 인증 비활성화 여부
  if [[ "$(uname -s)" != "Darwin" ]]; then
    PW_AUTH=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    if [[ "$PW_AUTH" == "no" ]]; then
      check pass "SSH 비밀번호 인증: 비활성화 (키 인증만 허용)"
    else
      check warn "SSH 비밀번호 인증: 활성화 → \`PasswordAuthentication no\` 설정 권장"
    fi
  fi
  echo ""
fi

# ============================================================================
# 6. PREMIUM 전용: 고급 하드닝 점검
# ============================================================================
if [[ "$TIER" == "PREMIUM" ]]; then
  echo "## 6. 고급 보안 하드닝 (PREMIUM)"
  echo ""
  
  # 자동 업데이트
  if [[ "$(uname -s)" == "Darwin" ]]; then
    AUTO_UPDATE=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo "0")
    if [[ "$AUTO_UPDATE" == "1" ]]; then
      check pass "macOS 자동 업데이트: 활성화됨"
    else
      check warn "macOS 자동 업데이트: 비활성화 → 시스템 설정에서 활성화 권장"
    fi
  else
    if systemctl is-active unattended-upgrades 2>/dev/null | grep -q "active"; then
      check pass "unattended-upgrades: 활성화됨"
    else
      check warn "자동 보안 업데이트 미설정"
    fi
  fi
  
  # FileVault / 디스크 암호화
  if [[ "$(uname -s)" == "Darwin" ]]; then
    FV_STATUS=$(fdesetup status 2>/dev/null || echo "unknown")
    if echo "$FV_STATUS" | grep -qi "on"; then
      check pass "FileVault: 활성화됨 (디스크 암호화)"
    else
      check warn "FileVault: 비활성화 → 활성화 강력 권장"
    fi
  fi
  
  # Gatekeeper
  if [[ "$(uname -s)" == "Darwin" ]]; then
    GK_STATUS=$(spctl --status 2>/dev/null || echo "unknown")
    if echo "$GK_STATUS" | grep -qi "enabled"; then
      check pass "Gatekeeper: 활성화됨"
    else
      check warn "Gatekeeper: 비활성화"
    fi
  fi
  echo ""
fi

# ============================================================================
# 종합 결과
# ============================================================================
echo "---"
echo ""
echo "## 종합 결과"
echo ""
echo "| 항목 | 수 |"
echo "|------|-----|"
echo "| 검사 항목 | $TOTAL |"
echo "| $PASS 통과 | $PASSED |"
echo "| $FAIL 실패 | $FAILED |"
echo "| $WARN 경고 | $WARNINGS |"
echo ""

if [[ $FAILED -eq 0 ]]; then
  echo "### 🟢 보안 상태: 양호"
elif [[ $FAILED -le 2 ]]; then
  echo "### 🟡 보안 상태: 개선 필요"
else
  echo "### 🔴 보안 상태: 즉시 조치 필요"
fi
echo ""
echo "---"
echo "*리포트 생성: $(date '+%Y-%m-%d %H:%M') | OpenClaw Security Audit v1.0*"

# ============================================================================
# PDF 변환 (--pdf 모드)
# ============================================================================
if [[ "$PDF_MODE" == "1" ]]; then
  REPORT_MD="/tmp/openclaw-security-report.md"
  REPORT_PDF="$HOME/Desktop/OpenClaw-보안점검-$(date +%Y%m%d).pdf"
  
  # 자기 자신을 다시 실행해서 마크다운 캡처
  TIER="$TIER" bash "$0" > "$REPORT_MD"
  
  if command -v pandoc &>/dev/null; then
    pandoc "$REPORT_MD" -o "$REPORT_PDF" --pdf-engine=wkhtmltopdf 2>/dev/null || \
    pandoc "$REPORT_MD" -o "$REPORT_PDF" 2>/dev/null
    
    if [[ -f "$REPORT_PDF" ]]; then
      echo "" >&2
      echo "📄 PDF 저장: $REPORT_PDF" >&2
    else
      echo "❌ PDF 변환 실패 — pandoc 설정을 확인하세요." >&2
      echo "📄 마크다운: $REPORT_MD" >&2
    fi
  else
    echo "" >&2
    echo "pandoc이 없어서 PDF 변환을 건너뜁니다." >&2
    echo "  설치: brew install pandoc" >&2
    echo "📄 마크다운: $REPORT_MD" >&2
  fi
fi
