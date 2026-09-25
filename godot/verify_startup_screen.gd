extends SceneTree
const Screen=preload("res://ui/startup_screen.gd")
const Boot=preload("res://app/boot.gd")
const Services=preload("res://services/app_services.gd")
const Update=preload("res://services/update_service.gd")
var failures: Array[String]=[]
var created := 0
var native
var coordinator
var state_folder: String
var capture_folder: String
var primary_calls:=0
var continue_calls:=0
class HeldUpdate extends Update:
 signal finish
 var calls:=0
 var decision:="error"
 func setup(_platform,_url):
  blocked=true;platform=RefCounted.new();manifest_url="https://fixture.invalid/update.json"
 func _check() -> Dictionary:
  calls+=1
  await finish
  if decision=="error": return {"ok":false}
  installed={"versionCode":1}
  release={"versionCode":2,"versionName":"0.2.1","sizeBytes":193986560,"minimumSupportedVersionCode":2 if decision=="required" else 0,"notes":"저장과 계정 연결을 안정화했습니다.\n전투 준비 화면을 복원했습니다."}
  blocked=true
  return {"ok":true}
class Platform extends RefCounted:
 var folder: String
 var reads:=0
 func application_support_path():return folder
 func session_read():reads+=1;return {"ok":true,"value":null}
class App extends RefCounted:
 var checkpoint
 var startup_blocked:=true
 var lobby=null
 var scene={"_native_combat":{"active":false}}
 var in_lobby:=true
 var loads:=0
 var progression_inputs={}
 func _refresh_ui():pass
 func retry_load():
  loads+=1
  checkpoint.store.load_save()
  startup_blocked=false
  return true
 func pause_and_save():return true
var application
func _initialize():
 capture_folder=OS.get_environment("RUNE_STARTUP_CAPTURE_DIR")
 state_folder=OS.get_environment("TMPDIR").path_join("startup-screen-state")
 _run.call_deferred()
func check(value: bool, reason: String):
 if not value: failures.append(reason);push_error(reason)
func frames(count:=3):
 for frame in count:await process_frame
func capture(label: String):
 if capture_folder.is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(capture_folder.path_join(label+".png"))
func pointer(button: Button, pressed: bool):
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=button.get_global_rect().get_center()
 Input.parse_input_event(event)
 await frames()
func _run():
 ProjectSettings.set_setting("accessibility/disable_animations",true)
 root.size=Vector2i(440,988)
 var screen=Screen.new();root.add_child(screen)
 screen.present({"status":"업데이트 확인 중","busy":true})
 await frames()
 check(screen.primary_button==null and screen.find_child("StartupProgress",true,false)!=null,"Checking uses fullscreen progress, no lobby actions")
 ProjectSettings.set_setting("accessibility/disable_animations",false)
 screen._elapsed=0.9
 await frames()
 check(is_equal_approx(screen._flow.size.x,screen._track.size.x*0.38),"Indeterminate flow retains original 38 percent moving segment")
 var flow_start=screen._flow.position.x
 await frames(6)
 check(screen._flow.position.x!=flow_start,"Indeterminate flow moves over rendered frames")
 await capture("checking")
 ProjectSettings.set_setting("accessibility/disable_animations",true)
 var notes=""
 for index in 18:notes+="저장과 전투 연결을 안정화했습니다. 긴 업데이트 내용도 전용 영역에서 확인할 수 있습니다.\n"
 var view={"status":"필수 업데이트가 있습니다","busy":false,"details":true,"required":true,"version":"0.2.1 · 185.0 MB","notes":notes,"action":"업데이트하기"}
 screen.present(view)
 await frames()
 check(screen.primary_button!=null and screen.continue_button==null,"Required update has one primary action")
 check(screen.outer.get_v_scroll_bar().max_value<=screen.outer.size.y+2,"Portrait fixed controls fit without outer scrolling")
 var before=screen.primary_button.get_global_rect()
 screen.notes_scroll.scroll_vertical=100
 await frames()
 check(screen.primary_button.get_global_rect()==before,"Release note scrolling leaves primary action fixed")
 check(screen.notes_scroll.get_v_scroll_bar().max_value>screen.notes_scroll.size.y,"Long notes scroll internally")
 screen.notes_scroll.scroll_vertical=0
 await frames()
 await capture("required")
 view.required=false;view.can_continue=true;view.status="새 버전이 있습니다";view.action="업데이트"
 screen.present(view,func():primary_calls+=1,func():continue_calls+=1);await frames()
 check(screen.continue_button!=null,"Optional update exposes current-version continuation")
 await capture("optional")
 await pointer(screen.primary_button,true);await capture("primary-pressed")
 await pointer(screen.primary_button,false)
 await pointer(screen.continue_button,true);await pointer(screen.continue_button,false)
 check(primary_calls==1 and continue_calls==1,"Both update actions invoke their own callback through mouse input")
 view.busy=true;view.progress=0.5;view.status="업데이트 다운로드 중";view.version="0.2.1 · 85.0 MB"
 view.progress_text="42.5 / 85.0 MB"
 screen.present(view,func():primary_calls+=1,func():continue_calls+=1);await frames()
 await pointer(screen.primary_button,true);await pointer(screen.primary_button,false)
 await pointer(screen.continue_button,true);await pointer(screen.continue_button,false)
 check(primary_calls==1 and continue_calls==1,"Busy update blocks both action callbacks")
 await capture("busy-disabled")
 screen.notes_scroll.scroll_vertical=100;await frames()
 var notes_control=screen.notes_scroll
 var notes_offset=notes_control.scroll_vertical
 var primary_control=screen.primary_button
 view.progress=0.75;view.progress_text="63.8 / 85.0 MB"
 screen.present(view,screen.action,screen.continue_action);await frames()
 check(screen.notes_scroll==notes_control and screen.notes_scroll.scroll_vertical==notes_offset and screen.primary_button==primary_control,"Byte updates preserve notes scroll and button nodes")
 check(screen.progress_label.text=="63.8 / 85.0 MB" and is_equal_approx(screen._flow.size.x,screen._track.size.x*0.75),"Byte label and bar update together")
 await capture("download-75")
 root.size=Vector2i(320,720);screen.text_scale_override=2.0;screen._layout();await frames()
 check(screen.progress_label.get_global_rect().end.x<=320 and screen.progress_label.text=="63.8 / 85.0 MB","Narrow large text retains downloaded amount")
 await capture("download-narrow-large-text")
 root.size=Vector2i(440,988);screen.text_scale_override=0.0
 view.busy=false
 for amount in [0.0,0.05,0.5,1.0]:
  screen.present({"status":"게임 준비 중","busy":true,"progress":amount});await frames()
  var progress=screen.find_child("StartupProgress",true,false)
  check(progress.size.y==24 and screen._track.get_global_rect().encloses(screen._flow.get_global_rect()),"Progress fits the compact frame at %s" % amount)
  check(is_equal_approx(screen._flow.size.x,screen._track.size.x*amount),"Progress represents %s without minimum fill" % amount)
  await capture("progress-%d" % roundi(amount*100))
 root.size=Vector2i(320,720);screen.text_scale_override=2.0;screen.present(view);await frames()
 check(screen.primary_button.get_global_rect().end.x<=320 and screen.continue_button.get_global_rect().end.x<=320,"Narrow large text retains both action labels within viewport")
 screen.outer.scroll_vertical=int(screen.outer.get_v_scroll_bar().max_value);await frames();await capture("narrow-large-text")
 root.size=Vector2i(440,988);screen.text_scale_override=0.0
 screen.present({"status":"업데이트 확인","busy":false,"details":true,"error":"업데이트 정보를 확인하지 못했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요.","action":"다시 시도"})
 await frames();await capture("error")
 check(screen.primary_button.text=="다시 시도" and screen.continue_button==null,"Failed check has retry without stale optional skip")
 screen.present({"status":"필수 업데이트가 있습니다","busy":false,"details":true,"required":true,"version":"0.2.1 · 185.0 MB","notes":"설치 권한을 허용한 뒤 계속할 수 있습니다.","message":"설정에서 이 앱의 설치를 허용한 뒤 돌아와 ‘설치 계속’을 눌러 주세요.","action":"설치 계속"})
 await frames();await capture("install-continue")
 check(screen.primary_button.text=="설치 계속","Downloaded update offers installation continuation")
 root.size=Vector2i(760,320);screen.text_scale_override=2.0;screen.present(view)
 await frames()
 check(screen.outer.get_v_scroll_bar().max_value>screen.outer.size.y,"Short landscape with large text permits outer scrolling")
 screen.outer.scroll_vertical=int(screen.outer.get_v_scroll_bar().max_value)
 await frames()
 check(screen.continue_button.get_global_rect().end.y<=root.size.y+2,"Outer scroll reaches optional continuation at large text")
 await capture("landscape-large-text")
 check(Screen.note_entries("- 첫 번째입니다. 다음입니다!\n• 버전 0.2.1, 1.5 MB 유지") == ["첫 번째입니다.","다음입니다!","버전 0.2.1, 1.5 MB 유지"],"Release notes retain version/decimal text and split sentences")
 screen.queue_free();await frames(1)
 await _boot_checks()
 print("STARTUP_SCREEN failures=",failures.size()," ",failures)
 quit(0 if failures.is_empty() else 1)
func _boot_checks():
 root.size=Vector2i(440,988)
 var file=FileAccess.open("res://fixtures/startup_game.gd",FileAccess.WRITE)
 file.store_string('extends Node3D\nfunc _ready(): get_tree().get_first_node_in_group("rune_app_boot").get_meta("fixture_ready").call(self)\n');file.close()
 file=FileAccess.open("res://fixtures/startup_game.tscn",FileAccess.WRITE)
 file.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://fixtures/startup_game.gd" id="1"]\n[node name="FixtureGame" type="Node3D"]\nscript=ExtResource("1")\n');file.close()
 var boot=Boot.new();boot.game_scene_path="res://fixtures/startup_game.tscn"
 boot.updates=HeldUpdate.new();boot.set_meta("fixture_ready",_game_ready)
 root.add_child(boot)
 boot._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
 check(boot.screen.visible and boot.updates.calls==0 and created==0,"Startup canvas exists before first update request or main creation")
 await frames(4)
 check(boot.updates.calls==1 and created==0,"Initial update check begins only after startup frame")
 boot.updates.finish.emit();await frames()
 check(boot.updates.blocked and created==0 and coordinator==null,"Failed update does not create game/services or access save/session")
 boot.updates.decision="optional";boot._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
 boot._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
 check(boot.updates.calls==2,"Boot return checks once and ignores duplicate resume while busy")
 await frames(1);boot.updates.finish.emit();await frames()
 check(created==0 and boot.screen.continue_button!=null,"Optional update waits for explicit continuation")
 boot.updates.busy=true;boot.updates.phase="download";boot.updates.transfer="full"
 boot.updates.transfer_stage="download";boot.updates.received_bytes=44564480;boot.updates.total_bytes=89128960
 boot.updates.changed.emit();await frames()
 check(boot.screen.progress_label.text=="42.5 / 85.0 MB" and boot.screen._progress==0.5,"Boot maps native byte counts to MB and determinate progress")
 var calls_before_resume=boot.updates.calls
 boot._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 boot._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
 check(boot.updates.calls==calls_before_resume and boot.updates.received_bytes==44564480,"App switch during download preserves bytes without a new update check")
 boot.updates.transfer_stage="verify";boot.updates.changed.emit();await frames()
 check(boot.screen.status_label.text=="다운로드 파일 확인 중" and boot.screen._progress<0 and not boot.screen.progress_label.visible,"Verification does not pretend downloading or installation completed")
 boot.updates.transfer_stage="apply";boot.updates.changed.emit();await frames()
 check(boot.screen.status_label.text=="변경분 적용 중","Patch application has separate status")
 boot.updates.busy=false
 boot.updates.skip();boot.updates.changed.emit()
 for frame in 90:
  await process_frame
  if coordinator!=null and not coordinator._startup_pending:break
 check(created==1 and coordinator!=null,"Gate pass creates the game exactly once")
 if coordinator!=null:
  check(coordinator.updates==boot.updates and boot.updates.calls==2,"AppServices reuses boot updater without duplicate check")
  check(application.loads==1 and native.reads==1,"Save and secure restoration start once after gate pass")
  check(not boot.screen.visible and not boot.blocks_app_ui(),"Preparation ends after services initialize")
  boot._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
  check(boot.updates.calls==2,"After attachment only application lifecycle owns resume checks")
 boot.queue_free();await frames()
func _game_ready(game: Node):
 created+=1
 application=App.new()
 native=Platform.new();native.folder=state_folder
 coordinator=Services.new();game.add_child(coordinator)
 coordinator.setup(application,native,{"apiBaseUrl":"https://fixture.invalid","googleClientId":"fixture"})
