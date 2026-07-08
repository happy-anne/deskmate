# DeskMate

안내 데스크 근무표를 실시간으로 관리하고 사용자끼리 직접 교환하는 PWA.
"최종본"이라는 개념이 없으며, **지금 화면이 항상 최신 근무표**입니다.

- **Nuxt 4** (compatibility mode) · Vue 3 · Tailwind CSS
- **Supabase** (PostgreSQL · Auth · Realtime · RLS)
- **PWA** (Manifest · Service Worker · 설치 · 오프라인 셸)
- **FCM** 웹 푸시 (선택)
- 디자인: Toss(TDS) 디자인 시스템 기반 — Blue `#3182f6`, 단일 컬럼 모바일 퍼스트

---

## 1. 빠른 시작

```bash
npm install
cp .env.example .env      # SUPABASE_URL / SUPABASE_KEY 채우기
npm run dev               # http://localhost:3000
```

### 필수 환경변수

| 변수 | 설명 |
|------|------|
| `SUPABASE_URL` | 프로젝트 URL (Settings → API) |
| `SUPABASE_KEY` | anon public key |

FCM 관련 `NUXT_PUBLIC_FCM_*` 값은 선택이며, 비워두면 푸시 없이 인앱 알림센터만 동작합니다.

---

## 2. 데이터베이스 설정

Supabase SQL Editor에서 `supabase/migrations/`의 파일을 순서대로 실행하세요.

```
0001_schema.sql      -- 테이블
0002_functions.sql   -- current_user_id/is_admin, 교환 로직(accept/approve/promote)
0003_rls.sql         -- 트리거(알림) + Row Level Security
0004_seed.sql        -- (선택) 8월 데모 근무표 + 임시 사용자
```

Supabase CLI를 쓴다면:

```bash
supabase link --project-ref <ref>
supabase db push        # 또는 각 SQL을 psql로 실행
```

### 관리자 지정

가입 후 본인 계정을 관리자로 승격:

```sql
update public.users set role = 'admin' where name = '내이름';
```

### Realtime

Supabase 대시보드 → Database → Replication에서 `schedules`,
`swap_requests`, `recruit_applications`, `notifications` 테이블의 Realtime을
켜면 모든 기기에 즉시 반영됩니다.

---

## 3. 아키텍처

```
app/
  assets/css/main.css     디자인 토큰 · 컴포넌트 클래스(.btn/.field/.card/.badge)
  components/             AppHeader · BottomNav · BottomSheet · PinLock ·
                         ScheduleCard · AppIcon(인라인 SVG) · ToastHost
  composables/
    useDb                 타입이 적용된 Supabase 클라이언트
    useProfile            현재 사용자 프로필 + 앱 설정 + 온보딩
    useSchedule           월별 근무표 로드 → "주/타임/담당자" 뷰모델 + Realtime
    useSwap               지정 교환 · 교환 모집 · 수락/거절/승인(RPC)
    useRequests           보낸/받은/모집 요청 조인 로드 + Realtime
    useNotifications      인앱 알림센터 + Realtime 배지
    usePinLock            기기 저장 4자리 PIN · 15분 유휴 잠금
    usePush               FCM 웹 푸시(지연 로드, 키 없으면 no-op)
  middleware/
    onboarding.global     로그인 후 이름/휴대폰 미입력 → /onboarding
    admin                 /admin/* 관리자 가드
  pages/                  schedule · requests · history · notifications · me · admin/*
  types/                  db.ts(행 타입) · database.ts(Supabase Database 제네릭)
supabase/migrations/      스키마 · 함수 · RLS · 시드
public/                   아이콘 · firebase-messaging-sw.js
scripts/gen-icons.mjs     PWA 아이콘 생성기(의존성 없음)
```

### 핵심 설계

- **교환은 원자적으로**: 근무 맞교환은 DB 함수(`accept_swap`,
  `approve_recruit`)에서 `SECURITY DEFINER` + row lock으로 실행되어 두
  사람의 근무가 항상 일관되게 바뀌고 `swap_history`가 함께 기록됩니다.
- **모두 같은 최신본**: 근무 셀은 `schedules` Realtime을 구독하므로 교환
  즉시 전 기기에 반영됩니다.
- **임시 사용자**: 로그인 없이 이름만으로 배정 가능. 동일 이름 가입 시
  `promote_placeholder`로 근무/교환/이력을 그대로 승계합니다.
- **PIN은 서버에 없음**: 4자리 PIN은 기기(localStorage)에만 저장하며 15분
  유휴 후 잠금 화면으로 전환합니다.

---

## 4. 사용자 플로우

- **지정 교환**: 근무표에서 상대 셀 탭 → "이 근무와 교환하기" → 내 근무
  선택 → 상대에게 요청(+푸시) → 상대가 표 확인 후 수락 → 즉시 반영.
- **교환 모집**: 내 셀 탭 → "교환 모집 등록" → 누구든 지원 → 작성자 승인 → 완료.
- **변경 이력**: 교환된 셀에 "변경됨" 배지, 변경내역 탭에서 원담당자→현담당자 확인.

---

## 5. 배포 (Vercel)

1. 저장소를 Vercel에 임포트 (Nuxt 자동 감지)
2. Environment Variables에 `SUPABASE_URL`, `SUPABASE_KEY` (+선택 `NUXT_PUBLIC_FCM_*`) 추가
3. Supabase Auth → URL Configuration에 배포 도메인과 `…/confirm` 리디렉트 등록

```bash
npm run build     # .output/ 생성 (Nitro)
```

---

## 6. 스크립트

```bash
npm run dev         # 개발 서버
npm run build       # 프로덕션 빌드
npm run preview     # 빌드 미리보기
npm run typecheck   # 타입 검사 (vue-tsc)
node scripts/gen-icons.mjs   # PWA 아이콘 재생성
```
