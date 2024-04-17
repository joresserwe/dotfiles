# kill the wallpaper extension every 15 min
pgrep WallpaperVideoExtension | xargs kill -9
date > ~/.cache/wallpaperkiller/wallpaperkiller.log
