extends SceneTree
class Updater extends "res://services/update_service.gd":
	var response: Dictionary = {}
	func _manifest() -> Dictionary:
		return response
class Platform extends Node:
	signal installed_version_ready(payload)
	signal update_completed(operation,payload)
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
	check(not Updater.valid_url("http://example.test/update.json"),"HTTPS only")
	check(not Updater.valid_url("https://user@example.test/update.json"),"userinfo rejected")
	var malformed=release.duplicate(true)
	malformed.minimumSupportedVersionCode=3
	check(not Updater.valid_manifest(malformed),"minimum above release rejected")
	print("UPDATE_SERVICE failures=",failures.size()," ",failures)
	updater.queue_free();platform.queue_free()
	quit(0 if failures.is_empty() else 1)
