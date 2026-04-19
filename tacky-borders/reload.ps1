# Restart tacky-borders on Hyper+C.
#
# tacky-borders reads its config directly from the WSL dotfiles repo via
# the TACKY_BORDERS_CONFIG_HOME env var (pointing at the UNC root;
# set by install.linux.sh). The app's in-app watcher uses Win32
# ReadDirectoryChangesW, which is not supported over WSL's 9P redirector
# (microsoft/WSL#4581), so the watcher is dead on UNC by design — a full
# restart is the replacement reload path.
#
# Start-ScheduledTask on the 'tacky-borders' task does the work:
#   - task action is tacky-borders.exe directly (no PS wrapper -> no console
#     flash on reload)
#   - MultipleInstances=StopExisting (set via CIM flip in register-task.ps1)
#     tells Task Scheduler to reap the running instance before launching a
#     new one. The Task Scheduler service runs as LocalSystem with
#     SeDebugPrivilege, so it can kill the previous Highest-integrity
#     tacky-borders regardless of UIPI — which a Medium-integrity
#     Stop-Process from this script could not.
#
# Also covers v1.4.1 issue #72 (render_backend drops to None after sleep/wake
# or display change and isn't recreated on its own — a full restart
# recreates it).

Start-ScheduledTask -TaskName 'tacky-borders' -ErrorAction SilentlyContinue
