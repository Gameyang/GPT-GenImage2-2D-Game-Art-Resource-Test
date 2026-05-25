
# GPT GenImage2 2D Game Art Resource Test - Private Development Repository

이 저장소는 **GPT GenImage2를 활용해 2D 게임 아트 리소스를 어디까지 제작할 수 있는지 검증하기 위한 비공개 개발용 repository**입니다.

본 repository에서는 프롬프트 실험, 생성 결과 관리, 리소스 평가, 정적 샘플 페이지 제작을 진행합니다.  
최종적으로 공개 가능한 결과물만 별도의 공개 GitHub Pages repository로 배포하는 것을 목표로 합니다.

---

## Project Overview

이번 프로젝트는 GPT GenImage2의 이미지 생성 능력을 2D 게임 제작 관점에서 테스트하는 것을 목적으로 합니다.

단순 이미지 생성이 아니라, 실제 2D 게임 개발에 필요한 다양한 아트 리소스를 카테고리별로 생성하고, 게임 리소스로서의 사용 가능성과 한계를 검증합니다.

주요 테스트 대상은 다음과 같습니다.

- 캐릭터 리소스
- 스프라이트 애니메이션 리소스
- 배경 리소스
- 타일셋 / 맵 리소스
- 아이템 / 아이콘 리소스
- UI 리소스
- VFX 리소스
- 키비주얼 / 프로모션 리소스

---

## Repository Purpose

이 repository는 **비공개 개발 및 검증용**입니다.

따라서 아래와 같은 자료가 포함될 수 있습니다.

- 프롬프트 실험 기록
- 실패한 이미지 생성 결과
- 내부 테스트 노트
- 원본 이미지 / 중간 산출물
- 평가 기준 및 결과
- 공개 전 검수용 샘플 페이지
- GitHub Pages 공개 repo로 전달할 정적 파일

공개 가능한 결과물은 별도 폴더에 정리한 뒤, 추후 공개 repository로 동기화합니다.

---

## Public Release Strategy

최종 공개 구조는 아래와 같이 분리합니다.

```text
private-dev-repo
  비공개 개발 repository
  원본 작업 파일, 실험 로그, 프롬프트, 평가 데이터 관리

public-pages-repo
  공개 GitHub Pages repository
  최종 정리된 샘플 페이지와 공개 가능한 이미지 리소스만 포함
````

공개 배포 대상은 `public/` 폴더에 정리합니다.

```text
private-dev-repo/
├── public/
│   ├── index.html
│   ├── README.md
│   ├── assets/
│   ├── data/
│   └── css/
├── prompts/
├── raw/
├── experiments/
├── internal-notes/
└── .github/
```

추후 `publish` 브랜치에 push하면 GitHub Actions를 통해 `public/` 폴더만 별도 공개 repository로 업데이트하는 구성을 사용할 예정입니다.

---

## Project Goals

이 프로젝트의 주요 목표는 다음과 같습니다.

1. GPT GenImage2로 2D 게임 아트 리소스를 생성할 수 있는 범위 확인
2. 카테고리별 생성 품질 비교
3. 프롬프트 제어 가능성 검증
4. 캐릭터 / 배경 / UI / 이펙트 등 리소스 일관성 테스트
5. 실제 2D 게임 제작 파이프라인 적용 가능성 평가
6. GitHub Pages 기반 정적 샘플 페이지 제작
7. 공개 가능한 결과물과 내부 개발 자료 분리

---

## Test Categories

### 1. Character Assets

플레이어 캐릭터, NPC, 적 몬스터, 보스, 직업별 캐릭터, 포즈 변형, 표정 변형 등을 테스트합니다.

검증 포인트:

* 캐릭터 실루엣
* 스타일 일관성
* 포즈 변형 가능성
* 얼굴 / 손 / 장비 디테일
* 투명 배경 리소스로 사용 가능한지 여부

---

### 2. Sprite Animation Assets

Idle, Walk, Run, Attack, Hit, Death 등 2D 게임의 기본 애니메이션 리소스를 테스트합니다.

검증 포인트:

* 프레임 간 캐릭터 일관성
* 애니메이션 연결 가능성
* 스프라이트 시트 구성 가능성
* 포즈 가독성
* 후처리 필요 정도

---

### 3. Background Assets

숲, 마을, 던전, 실내, 전투 배경, 월드맵 등 게임 화면에 사용할 배경 리소스를 테스트합니다.

검증 포인트:

* 게임 화면으로 사용 가능한 구도
* 캐릭터 / UI와의 시각적 분리
* 깊이감과 분위기
* 반복 사용 가능성
* 해상도 확장 가능성

---

### 4. Tileset / Map Assets

바닥, 벽, 잔디, 물, 길, 절벽, 오브젝트 배치용 타일 등을 테스트합니다.

검증 포인트:

* 타일 반복 가능성
* 경계선 자연스러움
* 실제 맵 제작 가능성
* 타일 간 스타일 통일성
* 후처리 난이도

---

### 5. Item / Icon Assets

무기, 방어구, 포션, 재료, 퀘스트 아이템, 스킬 아이콘, 버프 / 디버프 아이콘 등을 테스트합니다.

검증 포인트:

* 작은 크기에서의 가독성
* 아이콘 스타일 통일성
* 게임 UI 적용 가능성
* 배경 제거 가능성
* 카테고리별 구분성

---

### 6. UI Assets

버튼, 패널, 인벤토리 슬롯, 체력바, 대화창, 툴팁, 미니맵 프레임 등을 테스트합니다.

검증 포인트:

* 실제 인터페이스 적용 가능성
* 텍스트 영역 확보
* 해상도 대응 가능성
* UI 컴포넌트 간 스타일 일관성
* 게임 장르별 분위기 적합성

---

### 7. VFX Assets

폭발, 마법, 히트 이펙트, 오라, 연기, 파티클 텍스처, 스킬 이펙트 등을 테스트합니다.

검증 포인트:

* 배경과 분리되는지 여부
* 투명 배경 처리 가능성
* 애니메이션화 가능성
* 타격감 / 연출력
* 후처리 필요 정도

---

### 8. Key Visual / Promotional Assets

게임 콘셉트 아트, 캐릭터 포스터, 배너, 썸네일, 스토어 이미지 mockup 등을 테스트합니다.

검증 포인트:

* 완성도
* 상업용 비주얼로서의 품질
* 캐릭터 / 세계관 전달력
* 마케팅 이미지로의 활용 가능성
* 스타일 일관성

---

## Evaluation Criteria

각 생성 결과물은 아래 기준으로 평가합니다.

| Criteria       | Description             | Score |
| -------------- | ----------------------- | ----- |
| Visual Quality | 이미지 자체의 완성도             | 1 - 5 |
| Consistency    | 스타일 및 캐릭터 일관성           | 1 - 5 |
| Game Usability | 실제 게임 리소스로 사용 가능한지      | 1 - 5 |
| Editability    | 후처리 및 수정이 쉬운지           | 1 - 5 |
| Prompt Control | 프롬프트로 원하는 결과를 제어할 수 있는지 | 1 - 5 |

---

## Recommended Repository Structure

```text
/
├── README.md
├── public/
│   ├── index.html
│   ├── README.md
│   ├── assets/
│   │   ├── characters/
│   │   ├── sprites/
│   │   ├── backgrounds/
│   │   ├── tilesets/
│   │   ├── items/
│   │   ├── ui/
│   │   ├── effects/
│   │   └── keyvisuals/
│   ├── data/
│   │   └── samples.json
│   └── css/
│       └── style.css
│
├── prompts/
│   ├── characters.md
│   ├── sprites.md
│   ├── backgrounds.md
│   ├── tilesets.md
│   ├── items.md
│   ├── ui.md
│   ├── effects.md
│   └── keyvisuals.md
│
├── raw/
│   ├── generated/
│   └── references/
│
├── experiments/
│   ├── prompt-tests/
│   ├── failed-results/
│   └── comparisons/
│
├── internal-notes/
│   ├── evaluation.md
│   ├── findings.md
│   └── limitations.md
│
└── .github/
    └── workflows/
        └── publish-to-public.yml
```

---

## Public Folder Policy

`public/` 폴더는 추후 공개 repository로 전달될 수 있는 파일만 포함합니다.

`public/`에 포함 가능한 항목:

* 최종 샘플 이미지
* 공개 가능한 `index.html`
* 공개 가능한 `README.md`
* 공개 가능한 평가 데이터
* 공개 가능한 CSS / JS
* 공개 가능한 썸네일 이미지

`public/`에 포함하지 말아야 할 항목:

* 내부 프롬프트 실험 로그
* 실패 이미지 전체 묶음
* 내부 리뷰 메모
* 비공개 reference 이미지
* 원본 PSD / Figma / Krita 파일
* 민감한 프로젝트 정보
* API key, token, `.env` 파일

---

## Sample Data Format

공개 샘플 페이지에서 사용할 데이터는 `public/data/samples.json`에 정리합니다.

```json
[
  {
    "id": "character_001",
    "category": "Character",
    "title": "Fantasy Warrior Character",
    "promptSummary": "2D fantasy warrior character, game asset style",
    "image": "assets/characters/character_001.png",
    "visualQuality": 4,
    "consistency": 3,
    "gameUsability": 4,
    "editability": 3,
    "promptControl": 4,
    "notes": "캐릭터 실루엣은 좋지만 손 디테일은 후처리가 필요함."
  }
]
```

주의: 공개용 `samples.json`에는 내부용 전체 프롬프트 대신 `promptSummary`만 넣을 수 있습니다.
전체 프롬프트 기록은 `prompts/` 폴더에서 비공개로 관리합니다.

---

## GitHub Pages Plan

추후 별도 공개 repository를 생성한 뒤, 아래와 같은 방식으로 공개 페이지를 운영합니다.

```text
private-dev-repo/public
  ↓
GitHub Actions
  ↓
public-pages-repo
  ↓
GitHub Pages
```

예상 공개 URL:

```text
https://YOUR_GITHUB_ID.github.io/YOUR_PUBLIC_REPO_NAME/
```

현재 단계에서는 공개 repository 연결 전이므로, 우선 `public/` 폴더 안에서 정적 페이지를 완성하는 것을 목표로 합니다.

---

## Branch Strategy

권장 브랜치 구조는 다음과 같습니다.

```text
main
  비공개 개발 기준 브랜치

dev
  실험 및 작업 브랜치

publish
  공개 배포 후보 브랜치
  추후 GitHub Actions를 통해 public/ 폴더만 공개 repo로 동기화
```

초기 단계에서는 `main`에서 개발하고, 공개 배포 자동화가 필요해지는 시점에 `publish` 브랜치를 추가합니다.

---

## Workflow Plan

현재 단계:

```text
1. 비공개 repo 생성
2. 프로젝트 구조 세팅
3. public/ 폴더 기준으로 샘플 페이지 제작
4. 리소스 카테고리별 이미지 생성
5. samples.json 데이터 정리
6. 로컬 또는 비공개 Pages 환경에서 결과 확인
```

추후 단계:

```text
1. 공개 GitHub Pages repo 생성
2. 비공개 repo에 GitHub Actions 추가
3. publish 브랜치 push 시 public/ 폴더만 공개 repo로 동기화
4. 공개 URL에서 최종 샘플 페이지 확인
```

---

## Internal Working Notes

이 repository는 실험용이므로 아래 내용을 지속적으로 기록합니다.

* 어떤 리소스가 가장 잘 생성되는가
* 어떤 리소스가 가장 불안정한가
* 프롬프트 제어가 잘 되는 패턴
* 반복적으로 실패하는 패턴
* 후처리가 필요한 영역
* 게임 제작 파이프라인에 바로 넣을 수 있는 영역
* 사람이 반드시 보정해야 하는 영역

---

## Expected Final Output

최종 산출물은 다음과 같습니다.

* 비공개 개발 repository
* 공개용 GitHub Pages repository
* 카테고리별 생성 이미지 샘플
* 정적 샘플 페이지
* 리소스별 평가 데이터
* 프롬프트 실험 기록
* GenImage2의 강점 / 한계 분석
* 2D 게임 제작 적용 가능성 결론

---

## Summary

이 repository는 GPT GenImage2를 활용해 2D 게임 아트 리소스 생성 가능성을 검증하기 위한 비공개 개발 공간입니다.

개발 과정에서는 내부 실험 자료와 프롬프트, 실패 결과, 평가 노트를 모두 관리하고, 최종적으로 공개 가능한 파일만 `public/` 폴더에 정리합니다.

향후 별도의 공개 GitHub Pages repository와 연결하여, `public/` 폴더의 결과물만 자동으로 배포하는 구조로 확장할 예정입니다.

```
