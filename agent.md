# 프로젝트 개요
- **앱 이름**: Stellai
- **목표**: 북미·남미·일본을 주요 시장으로 한 타로 모바일 앱 정식 출시
- **핵심 가치**: 신뢰 가능한 리딩 콘텐츠, 프리미엄 해석 및 커뮤니티 확장

# 시장 및 규제 체크리스트
- **스토어 계정**: Google Play Console, Apple Developer Program 가입 및 세금/은행 정보 최신 유지
- **지역별 규제**
  - 미국/캐나다: COPPA, CCPA, 광고 표기 규정 점검
  - 브라질/멕시코: LGPD, 광고 자율규제 확인, 신규 디지털세 반영
  - 일본: 개인정보보호법, 구글/애플 심사 가이드라인 번역 확인
- **광고 정책**: Google AdMob/애플 광고 가이드 준수, 나이 제한 및 정치성 광고 금지 대응

# 제품 기능 로드맵
1. **MVP (1단계)**
   - 구글/애플 로그인, 기본 카드 리딩, 광고 기반 무료 리딩
2. **수익화 확장 (2단계)**
   - 인앱결제 프리미엄 리딩, 광고 제거 옵션, 멤버십/구독
3. **고급 기능 (3단계)**
   - 사용자 맞춤 리딩 기록, 친구 공유, 라이브 이벤트, 추가 컨텐츠 DLC

# 기술 스택 제안
- **클라이언트**: Flutter (단일 코드베이스, Android 우선 개발 후 iOS 확장)
- **인증**: Firebase Authentication (Google Sign-In + Apple Sign In)
- **데이터베이스**: Firestore (사용자 프로필, 리딩 기록, 결제 영수증, 동의 상태)
- **서버리스**: Firebase Cloud Functions / Cloud Run (영수증 검증, 통계 집계)
- **CI/CD**: GitHub Actions (Gradle Play Publisher + Apple Transporter/ASC API 기반 스토어 업로드 자동화)
- **로깅/분석**: Firebase Crashlytics, Analytics, Remote Config

# Flutter 아키텍처 & 화면 구성
- **프로젝트 구조**: feature-first + core/common 모듈로 분리하여 LLM·결제·광고 로직을 캡슐화

        lib/
          main.dart
          app/
            app.dart                // MaterialApp 및 라우팅 정의
            router.dart             // GoRouter 혹은 Route 정보
          core/
            config/                 // env, 상수, flavor
            services/               // Firebase, LLM, 결제, 광고 클라이언트
            models/                 // 공통 데이터 모델 및 DTO
            localization/           // 다국어 JSON 로더, intl 헬퍼
            theme/                  // 컬러, 타이포그래피
          features/
            onboarding/             // 온보딩, 로그인
            dashboard/              // 홈/모드 선택
            question/               // 카테고리 선택, 커스텀 질문 입력
            reading/                // 카드 선택, 애니메이션, 광고 게이트
            result/                 // LLM 응답 표시, 공유/저장
            history/                // 리딩 기록 및 재확인
          shared/
            widgets/                // 공용 UI 컴포넌트
            utils/                  // 헬퍼 함수
        assets/
          cards/                   // 기존 카드 이미지
          translations/            // 다국어 JSON 묶음

- **핵심 패키지 제안**: go_router(내비게이션), riverpod(상태관리), dio(API), intl(다국어), firebase_core/auth/firestore, google_mobile_ads, in_app_purchase, shared_preferences
- **화면 플로우**:
  1. 스플래시 → 구글 로그인 → 온보딩(프리미엄/무료 소개)
  2. 홈(모드 선택)
     - 빠른 한 장: 하루 1회 무료, 광고 없이 즉시 결과
     - 3장 스프레드: 과거/현재/미래, 30초 광고 1회 또는 결제
     - 10장 스프레드: 종합 리딩, 30초 광고 2회(연속/분할) 또는 결제
  3. 카테고리 선택(직업, 애정, 재물 등) + 기본 질문 추천 리스트
  4. 직접 질문 입력(옵션) 및 언어 선택 확인
  5. 카드 선택 화면 → 광고 시청(필요 시) 동안 백그라운드에서 LLM 프롬프트 구성
  6. 리딩 결과 화면: LLM 응답(요약/상세), 카드별 해석, 공유/저장, 프리미엄 CTA
  7. 프리미엄 허브: 광고 면제, 추가 스프레드/히스토리 기능, 정기 결제 안내
- **데이터 흐름**: UI → ViewModel(Riverpod) → 서비스(Firebase/LLM) → Firestore 저장 → 상태 업데이트 → 다국어 변환 적용
- **LLM 통합**: Cloud Functions/Run에서 { userId, locale, spreadType, category, question, cardIds } JSON 수신 → LLM 호출 → 응답 저장 후 앱으로 반환
- **광고/결제 UX**: 카드 선택 직후 전면/보상형 광고 노출, 광고 시청 완료 시 결과 화면 활성화; 결제 사용자/프리미엄 구독자는 광고 스킵 후 즉시 응답 표시


# 데이터 및 보안
- 사용자 데이터 수집 최소화, 지역별 동의 배너 구성
- 인앱결제 영수증은 서버에서 검증 후 Firestore에 저장
- 민감 데이터는 Cloud Secret Manager 사용, 접근 로그 감사

# 수익화 전략
- **광고**: 30초 보상형/전면 광고는 리딩 결과 후로 제한, 빈도 캡 설정
- **인앱결제**: 프리미엄 스프레드, 광고 제거, 구독형 리딩 패스
- **가격 정책**: 스토어 수수료(기본 15~30%) 및 국가별 세율 반영, 환율 모니터링

# 출시 절차
1. Firebase 프로젝트 및 Android 앱 등록(앱명: Stellai) → 구성 파일 반영
2. 안드로이드 내부 테스트 트랙으로 MVP 실행 검증, Crashlytics 모니터링
3. 지역별 현지화 번들 확인(한국어/영어/스페인어/일본어 우선)
4. 구글 플레이 심사 제출 및 단계적 롤아웃 → 성능 안정 후 iOS 전환 준비
5. iOS 빌드 파이프라인 정비 후 애플 심사 제출, 전 지역 런칭

# MCP 및 자동화 도구 계획
- **Firebase CLI**: 배포, 인증/DB 규칙 관리
- **Google Cloud SDK (gcloud)**: Cloud Run, Secret Manager, IAM 설정
- **스토어 자동화 도구**: Gradle Play Publisher, Apple Transporter CLI, App Store Connect API 스크립트
- **Play Console API**: 빌드 업로드 및 인앱결제 동기화
- **App Store Connect API**: TestFlight, 메타데이터 자동화
- **GitHub CLI**: 릴리스 태깅, CI 워크플로 트리거
- **설치 전략**: npm/pip 기반 스크립트로 firebase-tools, gcloud CLI, Gradle Play Publisher 세팅, Apple Transporter CLI 등을 자동 설치(네트워크 승인 후 실행)

# Task Master
- [x] Flutter 프로젝트 구조 정의 및 저장소 초기 세팅(Android 패키지명, 모듈 구성)
- [ ] Firebase 프로젝트 생성, Android 앱 등록, google-services.json 연동
- [ ] 카드 데이터 다국어 JSON 스키마 설계 및 기본 번역 입력
- [ ] LLM 리딩 API 초안(Cloud Functions/Run) 설계, 프런트엔드 스텁 연결
- [ ] 광고·인앱결제 요구사항 정리 후 Flutter 플러그인 조사 및 선정
- [ ] Flutter 상태관리/DI 패턴 결정(예: Provider, Riverpod) 및 핵심 화면 목업
- [ ] 로컬라이제이션 워크플로 도구 선정(예: arb/json), 검수 프로세스 정의
- [ ] GitHub Actions 기반 빌드/테스트 파이프라인 초안 작성
- [ ] QA/테스트 플랜 수립(내부 테스트 트랙, 크래시 모니터링, 사용자 피드백 루프)
- [ ] MCP 설치 자동화 스크립트 작성(firebase-tools, gcloud, Gradle Play Publisher, Apple Transporter CLI 등)
