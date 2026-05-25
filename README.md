# GPT GenImage2 2D Game Art Resource Test

GPT GenImage2를 활용해 2D 게임 아트 리소스 생성 가능성을 검증하기 위한 비공개 개발용 repository입니다.

이 저장소는 프롬프트 실험, 생성 결과, 평가 노트, 공개 가능한 이미지 리소스를 분리해서 관리합니다.
구체적인 리소스 테스트 항목은 아직 정하지 않고, 아래 목차에 필요할 때 하나씩 추가합니다.

## Table of Contents

- [Project Purpose](#project-purpose)
- [Repository Structure](#repository-structure)
- [Resource Test List](#resource-test-list)
- [Prompt Records](#prompt-records)
- [Raw Assets](#raw-assets)
- [Experiments](#experiments)
- [Internal Notes](#internal-notes)
- [Public Assets](#public-assets)
- [Home Feed API](#home-feed-api)

## Project Purpose

- GPT GenImage2 기반 2D 게임 아트 리소스 생성 테스트
- 프롬프트 실험 및 생성 결과 관리
- 공개 가능한 결과물과 내부 작업 자료 분리
- 생성 이미지 리소스를 다른 프로젝트에서 재사용하기 쉽게 정리

## Repository Structure

```text
/
├── README.md
├── public/
│   ├── assets/
│   │   ├── backgrounds/
│   │   └── characters/
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

## Public Assets

공개 가능한 이미지 리소스만 `public/assets/` 폴더에 정리합니다.

홈 페이지, 피드 UI, 샘플 데이터 JSON, 자동 게시 훅은 이 프로젝트에서 제거했습니다. 해당 UI는 별도 프로젝트에서 구현합니다.

## Home Feed API

공개 홈 피드(`Gameyang/home`)가 읽을 수 있는 정적 JSON은 `public/home-feed.json`에서 관리합니다.

- GitHub Pages 배포 후 feed URL: `https://gameyang.github.io/GPT-GenImage2-2D-Game-Art-Resource-Test/home-feed.json`
- 이 파일에는 공개 가능한 대표 이미지, GIF, 링크만 기록합니다.
- `raw/references/`, `internal-notes/`, 비공개 평가 노트는 feed JSON에 포함하지 않습니다.
