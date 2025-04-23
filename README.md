## Symbolic Lync

```bash
# .zshenv
ln -sf ~/.config/.dotfiles/zsh/.zshenv ~/.zshenv

# .zshrc
ln -sf ~/.config/.dotfiles/zsh/.zshrc ~/.config/zsh/.zshrc

# .zshfun
ln -sf ~/.config/.dotfiles/zsh/zfunc ~/.config/zsh/zfunc

# ideavim
ln -sf ~/.config/.dotfiles/ideavim/mac/.ideavimrc ~/.config/ideavim/ideavimrc

# git
ln -sf ~/.config/.dotfiles/git/config ~/.config/git/config

# tmux
ln -sf ~/.config/.dotfiles/tmux/tmux.conf ~/.config/tmux/tmux.conf
ln -sf ~/.config/.dotfiles/tmux/tmux.mapping.conf ~/.config/tmux/tmux.mapping.conf
ln -sf ~/.config/.dotfiles/tmux/gitmux.conf ~/.config/tmux/gitmux.conf

# yabai
ln -sf ~/.config/.dotfiles/yabai/skhdrc ~/.config/skhd/skhdrc
ln -sf ~/.config/.dotfiles/yabai/yabairc ~/.config/yabai/yabairc
```

## Yabai Setup
- Official installation guide: [Yabai Installation Wiki](https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release))

```bash
# Disable System Integrity Protection (Partial SIP Disable)
# Boot in Recovery mode (hold power button) > Utility > Terminal
csrutil enable --without fs --without debug --without nvram


# Set NVRAM Boot Arument for arm64e ABI
sudo nvram boot-args=-arm64e_preview_abi

# Start Services
yabai --start-service
skhd --start-service

```

## Tmux Plugins Setup
- `prefix(ctrl + a) + I` : Installs all plugins listed in my tmux config

### tmux-sessionx issues 
- There is a known issue with the latest version of the 'tmux-sessionx' plugin as of 04-21, 2025.
- The last confirmed working version is commit **3a1911e**
- [issue link](https://github.com/omerxx/tmux-sessionx/issues/166)


```bash
cd ~/.config/tmux/plugins/tmux-sessionx
git checkout 3a1911e

```

