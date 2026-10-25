#!/bin/sh
# GUTのテストをヘッドレスで実行する
GODOT="${GODOT:-/c/Tools/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
# 新しく追加した class_name を認識させるため、先にインポートする
"$GODOT" --headless --import >/dev/null 2>&1
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit "$@"
