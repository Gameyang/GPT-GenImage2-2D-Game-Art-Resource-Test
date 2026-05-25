# GPT GenImage2 2D Game Art Resource Test

GPT GenImage2를 활용해 2D 게임 아트 리소스 생성 가능성을 검증하기 위한 비공개 개발용 repository입니다.

이 저장소는 프롬프트 실험, 생성 결과, 평가 노트, 공개용 정적 샘플 파일을 분리해서 관리합니다.
구체적인 리소스 테스트 항목은 아직 정하지 않고, 아래 목차에 필요할 때 하나씩 추가합니다.

## Table of Contents

- [Project Purpose](#project-purpose)
- [Repository Structure](#repository-structure)
- [Resource Test List](#resource-test-list)
- [Prompt Records](#prompt-records)
- [Raw Assets](#raw-assets)
- [Experiments](#experiments)
- [Internal Notes](#internal-notes)
- [Public Output](#public-output)

## Project Purpose

- GPT GenImage2 기반 2D 게임 아트 리소스 생성 테스트
- 프롬프트 실험 및 생성 결과 관리
- 공개 가능한 결과물과 내부 작업 자료 분리
- 추후 GitHub Pages용 정적 샘플 페이지 제작

## Repository Structure

```text
/
├── README.md
├── public/
│   ├── index.html
│   ├── README.md
│   ├── assets/
│   ├── data/
│   │   ├── test-pages.json
│   │   └── samples.json
│   ├── css/
│   │   └── style.css
│   └── js/
│       └── main.js
├── prompts/
├── raw/
│   ├── generated/
│   └── references/
├── experiments/
├── internal-notes/
```

## Resource Test List

구체적인 리소스 테스트 항목은 추후 여기에 하나씩 추가합니다.

## Prompt Records

프롬프트 실험 기록은 `prompts/` 폴더에서 관리합니다.

## Raw Assets

원본 생성물과 reference 자료는 `raw/` 폴더에서 관리합니다.

## Experiments

비교, 실패 사례, 반복 테스트 등은 `experiments/` 폴더에서 관리합니다.

## Internal Notes

평가 기준, 발견 사항, 한계점은 `internal-notes/` 폴더에서 관리합니다.

## Public Output

공개 가능한 파일만 `public/` 폴더에 정리합니다.

현재 `public/data/samples.json`은 빈 배열로 시작합니다.
메인 홈 페이지의 테스트 페이지 목록은 `public/data/test-pages.json`에서 관리합니다.
Codex 작업 종료 훅은 `scripts/publish-work-result.js`를 호출해 공개 가능한 변경만 `public/data/work-feed.json`에 기록합니다.
배포 자동화 workflow는 나중에 GitHub 토큰에 workflow 권한이 준비되면 추가합니다.
