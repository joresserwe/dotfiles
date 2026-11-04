# kill the wallpaper extension every 15 min
pgrep WallpaperVideoExtension | xargs kill -9
date > "${XDG_CACHE_HOME:-$HOME/.cache}/wallpaperkiller/wallpaperkiller.log"
