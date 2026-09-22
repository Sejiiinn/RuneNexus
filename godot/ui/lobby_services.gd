extends RefCounted
## Service screens retain their own state/entry points. Server authority stays external.
const T = preload("res://ui/app_theme.gd")
var lobby
var page := ""
var context := {}
var notice := ""

func open(title: String, values: Dictionary = {}) -> void:
	page = title
	context = values.duplicate(true)
	notice = ""
	_render()

func _render() -> void:
	var body: VBoxContainer = lobby.open_modal(page)
	lobby.modal.set_meta("max_width", 480 if page == "우편함" else 420)
	body.name = "ServiceBody"
	if page in ["계정 및 저장", "계정 로그인 · 온라인 저장"]:
		_account(body)
	elif page == "우편함":
		body.add_child(T.label("계정을 연결하면 운영 선물과 보상을 받을 수 있습니다.",12))
		body.add_child(T.button("계정 연결",open.bind("계정 및 저장"),"primary"))
	elif page == "리더보드":
		body.add_child(T.label("전체 순위 · TOP 100",14))
		body.add_child(T.label("계정을 연결하면 전체 순위와 내 순위를 확인할 수 있습니다.",12))
		body.add_child(T.button("계정 연결",open.bind("계정 및 저장"),"primary"))
	else:
		body.add_child(T.label(page,14))
		body.add_child(T.label("이 기능은 계정 연결 후 이용할 수 있습니다.",12))
		body.add_child(T.button("계정 연결",open.bind("계정 및 저장"),"primary"))
	if not notice.is_empty(): body.add_child(T.label(notice,12))

func _account(body: VBoxContainer) -> void:
	body.add_child(T.label("게스트",18))
	body.add_child(T.label("이 기기에 진행 상황이 저장됩니다.",12))
	body.add_child(T.label("계정을 연결하면 다른 기기에서도 진행 상황을 이어갈 수 있습니다.",12))
	# The native authentication adapter does not exist yet. Do not turn a guest
	# into an account, simulate login, or grant authoritative balances locally.
	var connect := T.button("Google 계정 연결",Callable(),"primary")
	connect.disabled = true
	body.add_child(connect)
	body.add_child(T.label("현재 Godot 앱의 계정 연결은 준비 중입니다. 기기 저장은 계속 사용할 수 있습니다.",12))
	body.add_child(T.label("앱 삭제 또는 기기 변경 전에 계정 연결과 온라인 저장 상태를 확인하세요.",12))
