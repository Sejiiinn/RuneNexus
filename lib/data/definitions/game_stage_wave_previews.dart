part of 'game_stage_waves.dart';

String _previewTextFor(int round) {
  if (round == 4) {
    return '빠른 적 첫 등장';
  }
  if (round == 5) {
    return '탱커 첫 등장';
  }
  if (round % 10 == 0) {
    return '보스 호위';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '기준 혼합';
  }
  if (cycleStep == 2) {
    return '빠른 적 러시';
  }
  if (cycleStep == 3) {
    return '겹침 압박';
  }
  if (cycleStep == 4) {
    return '탱커 돌파';
  }
  if (cycleStep == 5) {
    return '고밀도 압축';
  }
  return '일반 적 중심';
}

String _stage2PreviewTextFor(int round) {
  if (round == 2) {
    return '보호막병 첫 등장';
  }
  if (round == 3) {
    return '보호막 대열';
  }
  if (round == 4) {
    return '빠른 적 재압박';
  }
  if (round == 5) {
    return '보호막병과 탱커';
  }
  if (round % 10 == 0) {
    return '보호막 호위 보스';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '보호막 혼합';
  }
  if (cycleStep == 2) {
    return '빠른 적 러시';
  }
  if (cycleStep == 3) {
    return '균열 보호막';
  }
  if (cycleStep == 4) {
    return '분산 압박';
  }
  if (cycleStep == 5) {
    return '보호막 압축';
  }
  return '일반 적 중심';
}

String _chapter2Stage7PreviewTextFor(int round) {
  if (round == 2) {
    return '보호막 추격';
  }
  if (round == 3) {
    return '고속 균열';
  }
  if (round == 4) {
    return '빠른 적 돌입';
  }
  if (round == 5) {
    return '보호막 추격대';
  }
  if (round % 10 == 0) {
    return '고속 보호막 호위';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '기동 보호막';
  }
  if (cycleStep == 2) {
    return '고속 러시';
  }
  if (cycleStep == 3) {
    return '보호막 추격선';
  }
  if (cycleStep == 4) {
    return '분산 기동';
  }
  if (cycleStep == 5) {
    return '압축 돌파';
  }
  return '빠른 적 중심';
}

String _chapter2Stage8PreviewTextFor(int round) {
  if (round == 2) {
    return '보호막 장갑병';
  }
  if (round == 3) {
    return '내구 대열';
  }
  if (round == 4) {
    return '장갑 재압박';
  }
  if (round == 5) {
    return '보호막 탱커';
  }
  if (round % 10 == 0) {
    return '내구 호위 보스';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '내구 혼합';
  }
  if (cycleStep == 2) {
    return '장갑 돌파';
  }
  if (cycleStep == 3) {
    return '보호막 장벽';
  }
  if (cycleStep == 4) {
    return '탱커 압박';
  }
  if (cycleStep == 5) {
    return '내구 압축';
  }
  return '내구 적 중심';
}

String _chapter2Stage9PreviewTextFor(int round) {
  if (round == 2) {
    return '보호막 대열';
  }
  if (round == 3) {
    return '균열 장벽';
  }
  if (round == 4) {
    return '보호막 겹침';
  }
  if (round == 5) {
    return '보호막 압축';
  }
  if (round % 10 == 0) {
    return '장벽 호위 보스';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '보호막 밀집';
  }
  if (cycleStep == 2) {
    return '보호막 후속 러시';
  }
  if (cycleStep == 3) {
    return '균열 보호막선';
  }
  if (cycleStep == 4) {
    return '겹침 장벽';
  }
  if (cycleStep == 5) {
    return '고밀도 보호막';
  }
  return '보호막 중심';
}

String _chapter2Stage10PreviewTextFor(int round) {
  if (round == 2) {
    return '보스 호위 예열';
  }
  if (round == 3) {
    return '균열 정예';
  }
  if (round == 4) {
    return '정예 분산';
  }
  if (round == 5) {
    return '정예 압축';
  }
  if (round % 10 == 0) {
    return '균열 보스 호위';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '정예 혼합';
  }
  if (cycleStep == 2) {
    return '고속 정예';
  }
  if (cycleStep == 3) {
    return '정예 보호막선';
  }
  if (cycleStep == 4) {
    return '정예 분산 압박';
  }
  if (cycleStep == 5) {
    return '보스 호위 압축';
  }
  return '정예 적 중심';
}

String _stage2ArmoredPreviewTextFor(int round) {
  if (round == 2) {
    return '장갑병 첫 등장';
  }
  if (round == 3) {
    return '장갑 대열';
  }
  if (round == 4) {
    return '빠른 적 재압박';
  }
  if (round == 5) {
    return '장갑병과 탱커';
  }
  if (round % 10 == 0) {
    return '장갑 호위 보스';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '장갑 혼합';
  }
  if (cycleStep == 2) {
    return '빠른 적 러시';
  }
  if (cycleStep == 3) {
    return '장갑 대열';
  }
  if (cycleStep == 4) {
    return '분산 압박';
  }
  if (cycleStep == 5) {
    return '장갑 압축';
  }
  return '일반 적 중심';
}
