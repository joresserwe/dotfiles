# shellcheck shell=bash
secret_type() {
  case "$OSTYPE" in
    darwin*) secret_type_darwin "$@" ;;
    *) secret_type_wsl "$@" ;;
  esac
}

secret_type_wsl() {
  local value="$1" seconds="$2" line= mirror ahk="/mnt/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe"
  mirror="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/mirror-path" 2>/dev/null)" || return 1
  [ -x "$ahk" ] && [ -f "$mirror/winget/type-secret.ahk" ] || return 1
  exec 3< <(printf '%s\n' "$(printf '%s' "$value" | base64 -w0)" | setsid "$ahk" /ErrorStdOut "$(wslpath -w "$mirror/winget/type-secret.ahk")" "$seconds" 2>/dev/null)
  read -r -t 5 line <&3 || true
  exec 3<&-
  [[ "$line" == ready* ]]
}

secret_keys_released() {
  local flags i
  for i in {1..30}; do
    flags="$(osascript -l JavaScript -e 'ObjC.import("CoreGraphics"); Number($.CGEventSourceFlagsState(0)) & 0x1E0000')" || return 1
    [ "$flags" != 0 ] || return 0
    sleep 0.1
  done
  return 1
}

secret_type_darwin() {
  local value="$1" seconds="$2" dir fifo
  command -v osascript >/dev/null || return 1
  dir="$(getconf DARWIN_USER_TEMP_DIR)" && dir="${dir%/}/bw-type" || return 1
  mkdir -p "$dir" && chmod 700 "$dir" || return 1
  rm -f "$dir"/fifo.*
  fifo="$dir/fifo.$$.$RANDOM"
  mkfifo -m 600 "$fifo" || return 1
  printf '%s\n' "$fifo" >"$dir/current"
  (
    trap '' HUP
    exec 4<>"$fifo"
    end=$((SECONDS + seconds))
    while [ "$SECONDS" -lt "$end" ] && read -r -t $((end - SECONDS)) <&4; do
      secret_keys_released || continue
      printf 'tell application "System Events" to keystroke "%s"\n' \
        "$(printf '%s' "$value" | sed 's/[\\"]/\\&/g')" | osascript - || true
    done
    rm -f "$fifo"
  ) >/dev/null 2>&1 &
}

secret_deliver() {
  local label="$1" value="$2" seconds="$3" mode="$4" hint=" (Esc cancels)"
  [[ "$OSTYPE" != darwin* ]] || hint=
  if [ "$mode" = type ] && secret_type "$value" "$seconds"; then
    printf '%s: press Hyper+V within %ss%s\n' "$label" "$seconds" "$hint"
  elif secret_copy "$value" "$seconds"; then
    printf '%s: copied, cleared in %ss\n' "$label" "$seconds"
  else
    return 1
  fi
}

secret_copy() {
  local value="$1" seconds="${2:-0}" line=
  case "$OSTYPE" in
    darwin*)
      printf '%s' "$value" | pbcopy || return 1
      if [ "$seconds" -gt 0 ]; then
        (sleep "$seconds"; [ "$(pbpaste)" = "$value" ] && printf '' | pbcopy) >/dev/null 2>&1 &
      fi
      ;;
    *)
      command -v powershell.exe >/dev/null || return 1
      exec 3< <(printf '%s' "$value" | base64 -w0 | setsid powershell.exe -NoProfile -STA -Command '
        $s = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([Console]::In.ReadToEnd()))
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Clip {
  [DllImport("user32.dll")] static extern bool OpenClipboard(IntPtr h);
  [DllImport("user32.dll")] static extern bool EmptyClipboard();
  [DllImport("user32.dll")] static extern bool CloseClipboard();
  [DllImport("user32.dll")] static extern IntPtr SetClipboardData(uint f, IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetClipboardData(uint f);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern uint RegisterClipboardFormatW(string n);
  static bool Open() {
    for (int i = 0; i < 40; i++) {
      if (OpenClipboard(IntPtr.Zero)) return true;
      System.Threading.Thread.Sleep(50);
    }
    return false;
  }
  public static bool Set(string s) {
    if (!Open()) return false;
    try {
      EmptyClipboard();
      foreach (string n in new[] { "ExcludeClipboardContentFromMonitorProcessing", "CanIncludeInClipboardHistory", "CanUploadToCloudClipboard" }) {
        IntPtr z = Marshal.AllocHGlobal(4);
        Marshal.WriteInt32(z, 0);
        if (SetClipboardData(RegisterClipboardFormatW(n), z) == IntPtr.Zero) { EmptyClipboard(); return false; }
      }
      return SetClipboardData(13, Marshal.StringToHGlobalUni(s)) != IntPtr.Zero;
    } finally { CloseClipboard(); }
  }
  public static void ClearIf(string s) {
    if (!Open()) return;
    try {
      IntPtr h = GetClipboardData(13);
      if (h != IntPtr.Zero && Marshal.PtrToStringUni(h) == s) EmptyClipboard();
    } finally { CloseClipboard(); }
  }
}
"@
        if (-not [Clip]::Set($s)) { exit 1 }
        [Console]::Out.WriteLine("copied")
        [Console]::Out.Flush()
        $wait = '"$seconds"'
        if ($wait -gt 0) { Start-Sleep $wait; [Clip]::ClearIf($s) }
      ' 2>/dev/null)
      read -r line <&3 || true
      exec 3<&-
      [[ "$line" == copied* ]]
      ;;
  esac
}
