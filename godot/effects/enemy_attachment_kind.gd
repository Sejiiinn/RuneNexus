extends RefCounted
## 보스 본체를 공유하는 종류는 상태효과의 부착 데이터도 공유한다.
const ALIASES := {"shieldBoss": "boss", "forgeBoss": "boss"}


static func resolve(kind: String) -> String:
	return ALIASES.get(kind, kind)
