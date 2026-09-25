extends SceneTree
class Updater extends "res://services/update_service.gd":
	var response: Dictionary = {}
	func _manifest() -> Dictionary:
		return response
class Platform extends Node:
	signal installed_version_ready(payload)
	signal update_completed(operation,payload)
	signal update_progress(operation,payload)
	var calls: Array = []
	var install_ok := true
	func query_installed_version():
		installed_version_ready.emit.call_deferred(JSON.stringify({"ok":true,"value":{"versionCode":1,"packageName":"com.example.rune_nexus","apkSha256":"b".repeat(64)}}))
		return true
	func download_patch(_url,_hash,_size,_version,_base,_target,_target_size):
		calls.append("patch")
		update_completed.emit.call_deferred("downloadPatch",JSON.stringify({"ok":false,"error":"update_patch_failed"}))
		return true
	func download_update(_url,_hash,_size,_version):
		calls.append("full")
		update_completed.emit.call_deferred("downloadUpdate",JSON.stringify({"ok":true}))
		return true
	func install_update(_version):
		calls.append("install")
		update_completed.emit.call_deferred("installUpdate",JSON.stringify({"ok":install_ok,"value":"permissionRequired" if install_ok else "update_install_failed"}))
		return true
class ProgressPlatform extends Platform:
	func download_patch(_url,_hash,_size,_version,_base,_target,_target_size):
		calls.append("patch")
		return true
	func download_update(_url,_hash,_size,_version):
		calls.append("full")
		return true
	func progress(operation: String, stage: String, received: int, total: int):
		update_progress.emit(operation,JSON.stringify({"stage":stage,"receivedBytes":received,"totalBytes":total}))
var failures: Array = []
func check(ok,label):
	if not ok: failures.append(label)
func _initialize(): run.call_deferred()
func run():
	var platform=Platform.new()
	root.add_child(platform)
	var updater=Updater.new()
	root.add_child(updater)
	updater.setup(platform,"https://example.test/update.json")
	var release={"schemaVersion":1,"versionCode":2,"minimumSupportedVersionCode":2,"versionName":"v2","packageName":"com.example.rune_nexus","notes":"fixture","apkUrl":"https://example.test/app.apk","sha256":"a".repeat(64),"sizeBytes":1000,"patches":[{"format":"rune-apk-delta-v1","fromVersionCode":1,"fromSha256":"b".repeat(64),"sha256":"c".repeat(64),"url":"https://example.test/app.patch","sizeBytes":200}]}
	updater.response={"ok":true,"body":release}
	check((await updater.check()).ok and updater.blocked and updater.required(),"required gate")
	updater.skip()
	check(updater.blocked,"cannot skip mandatory")
	var result=await updater.update()
	check(result.ok and platform.calls==["patch","full","install"] and updater.downloaded,"patch failure falls back to full and permission pending keeps download")
	var pending_message=updater.message
	await updater.check()
	check(updater.downloaded and updater.phase=="install" and updater.message==pending_message,"same release foreground check retains installation permission guidance")
	platform.calls.clear()
	platform.install_ok=false
	await updater.update()
	await updater.update()
	check("full" in platform.calls,"install failure permits fresh full download")
	check(updater.downloaded == false,"failed reinstall clears downloaded flag")
	platform.calls.clear()
	platform.install_ok=true
	result=await updater.update()
	check(result.ok and platform.calls==["patch","full","install"] and updater.downloaded,"fresh download repairs installer failure")
	platform.calls.clear()
	result=await updater.update()
	check(result.ok and platform.calls==["install"] and updater.downloaded,"permission retry reuses verified download")
	updater.release.minimumSupportedVersionCode=1
	updater.skip()
	check(not updater.blocked,"optional update permits skip")
	updater.server_required=true
	updater.blocked=true
	updater.skip()
	check(updater.blocked,"server requirement overrides optional release")
	updater.response={"ok":true,"body":release.duplicate(true)}
	updater.response.body.packageName="another.package"
	check(not (await updater.check()).ok and updater.blocked,"wrong package fails closed")
	check(updater.release.is_empty() and updater.phase=="error","failed check clears stale optional release")
	updater.skip()
	check(updater.blocked,"failed check cannot skip stale optional release")
	updater.response={"ok":true,"body":release.duplicate(true)}
	updater.response.body.versionCode=3
	await updater.check()
	check(not updater.downloaded and updater.install_message.is_empty() and updater.phase=="available","changed release resets installation continuation")
	check(not Updater.valid_url("http://example.test/update.json"),"HTTPS only")
	check(not Updater.valid_url("https://user@example.test/update.json"),"userinfo rejected")
	# Real HTTPRequest with max_redirects=0 returns RESULT_REDIRECT_LIMIT_REACHED
	# for GitHub's 302, with its Location intact. It must reach manual validation.
	check(Updater._is_redirect([HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED,302]),"manual GitHub redirect accepted")
	check(Updater._is_redirect([HTTPRequest.RESULT_SUCCESS,307]),"successful redirect accepted")
	check(not Updater._is_redirect([HTTPRequest.RESULT_CANT_CONNECT,302]),"transport failure is not a redirect")
	check(not Updater._is_redirect([HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED,200]),"redirect-limit error without redirect status rejected")
	var malformed=release.duplicate(true)
	malformed.minimumSupportedVersionCode=3
	check(not Updater.valid_manifest(malformed),"minimum above release rejected")
	await progress_checks(release)
	print("UPDATE_SERVICE failures=",failures.size()," ",failures)
	updater.queue_free();platform.queue_free()
	quit(0 if failures.is_empty() else 1)

func progress_checks(release: Dictionary):
	var platform=ProgressPlatform.new();root.add_child(platform)
	var updater=Updater.new();root.add_child(updater)
	updater.setup(platform,"https://example.test/update.json")
	updater.response={"ok":true,"body":release.duplicate(true)}
	await updater.check()
	updater.update()
	check(updater.busy and updater.total_bytes==200 and updater.received_bytes==0,"patch starts with actual patch size")
	platform.progress("downloadPatch","download",80,200)
	check(updater.received_bytes==80 and updater.transfer_stage=="download","native byte progress received")
	check(not (await updater.check()).ok and updater.received_bytes==80 and platform.calls==["patch"],"foreground check during download neither resets nor restarts transfer")
	platform.progress("downloadPatch","download",70,200)
	platform.progress("downloadUpdate","download",100,1000)
	platform.progress("downloadPatch","download",250,200)
	check(updater.received_bytes==80,"stale, mismatched and invalid byte events ignored")
	platform.progress("downloadPatch","verify",200,200)
	check(updater.transfer_stage=="verify","verification is separate from byte download")
	platform.progress("downloadPatch","apply",200,200)
	check(updater.transfer_stage=="apply","patch application is separate from byte download")
	platform.update_completed.emit("downloadPatch",JSON.stringify({"ok":false}))
	await process_frame
	check(updater.total_bytes==1000 and updater.received_bytes==0 and updater.transfer=="full_fallback","fallback resets numerator and denominator to full APK")
	platform.progress("downloadPatch","download",200,200)
	check(updater.received_bytes==0,"late patch event cannot overwrite full transfer")
	platform.progress("downloadUpdate","download",600,1000)
	check(updater.received_bytes==600,"full fallback reports its actual bytes")
	platform.progress("downloadUpdate","verify",1000,1000)
	platform.update_completed.emit("downloadUpdate",JSON.stringify({"ok":true}))
	await process_frame;await process_frame
	check(updater.downloaded and not updater.busy and platform.calls==["patch","full","install"],"progress delivery preserves update completion")
	platform.progress("downloadUpdate","download",0,1000)
	check(updater.received_bytes==1000,"late progress cannot reset completed transfer")
	updater.downloaded=false
	updater.release.erase("patches")
	updater.update()
	platform.progress("downloadUpdate","verify",0,1000)
	platform.progress("downloadUpdate","download",0,1000)
	platform.progress("downloadUpdate","download",300,1000)
	check(updater.received_bytes==300 and updater.transfer_stage=="download","Invalid cached APK verification can restart byte progress from zero")
	platform.update_completed.emit("downloadUpdate",JSON.stringify({"ok":false}))
	await process_frame
	updater.queue_free();platform.queue_free()
