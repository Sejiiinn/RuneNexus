---
name: codex-imagegen
description: Codex CLI(사용자의 ChatGPT/Codex 구독)의 내장 image_gen으로 2D 래스터 이미지를 생성·편집한다. AGENTS.md의 "ImageGen" 경로이며, 3D 원본·프레임별 제어가 필요 없는 일반 2D 시안·아이콘·텍스처·UI 장식·컨셉 이미지가 필요할 때, 또는 사용자가 Codex로 이미지를 만들라고 할 때 사용한다. Blender/GIMP 경로가 필요한 3D·후처리 작업에는 쓰지 않는다.
---

# Codex 이미지 생성

전제: 이 PC에 Codex CLI(`codex`)가 설치·로그인되어 있어야 한다. 없거나 실행에 실패하면 그 사실을 사용자에게 알리고, 다른 도구로 몰래 대체하지 않는다.

모델은 항상 `gpt-6.1-sol`이다(사용자 지정, 스크립트에 고정). 다른 모델로 바꾸지 않는다.

## 실행

```bash
python3 .claude/skills/codex-imagegen/scripts/codex_imagegen.py \
  --out design/<작업폴더>/<이름>.png \
  --prompt "<영문 상세 프롬프트>" \
  [--ref <참고이미지>]... [--edit <수정대상>] [--transparent] [--count N] [--force]
```

- 1장당 약 1분 걸린다. Bash `timeout`은 600000으로 주고, 여러 장이면 `run_in_background`를 쓴다.
- 결과는 stdout JSON(`ok`, `outputs[].path`, `pixelWidth`, `hasAlpha`, `codex_reply`, `errors`). `ok=false`면 `errors`를 확인하고 원인을 바꾼 뒤 재시도한다. 같은 실패를 그대로 반복하지 않는다.
- 기존 파일은 `--force` 없이 덮어쓰지 않는다. 변형은 `-v2` 같은 새 이름을 쓴다.
- 원본은 `~/.codex/generated_images/<thread_id>/`에도 남는다.

## 프롬프트

- 영문으로 대상·스타일·구도·배경·용도(게임 아이콘, 타일 텍스처 등)·피해야 할 것을 구체적으로 쓴다. 이미지 안 글자가 필요하면 정확한 문구를 따옴표로 넣는다.
- 기존 에셋과 톤을 맞출 때는 해당 이미지를 `--ref`로 첨부하고 [DESIGNS.md](../../../DESIGNS.md)의 해당 화면 기준(색·재질)을 프롬프트에 반영한다.
- 기존 이미지를 고칠 때는 `--edit`로 넘기고 바꿀 점과 보존할 점을 명시한다.
- 투명 배경은 `--transparent`. 결과 `hasAlpha`를 확인하고, 알파가 없거나 가장자리가 지저분하면 GIMP MCP로 보정한다.

## 생성 후

1. 결과 이미지를 Read로 직접 보고 요청 충족 여부(형태·색·구도·글자·투명도)를 판단한다. 부족하면 한 가지씩 고쳐 다시 생성한다.
2. 저장 위치는 AGENTS.md를 따른다: 시안·중간본은 `design/`, 게임 적용본은 `assets/images/` + 기존 로딩 경로 연결. 크기·크롭·패킹은 [에셋 작업 절차](../../../.agents/asset_workflow_guide.md#산출물-점검)대로 점검한다.
3. 사용자에게 저장 경로와 사용한 프롬프트를 보고한다.
