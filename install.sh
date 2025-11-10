#!/bin/bash

# Arch Linux Hyprland Auto-Installer
# Запускать из под обычного пользователя (НЕ root!)
# wget https://raw.githubusercontent.com/your-repo/arch-hyprland-install/main/install.sh && chmod +x install.sh && ./install.sh

set -e  # Остановка при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
LOG_FILE="$HOME/arch-hyprland-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${BLUE}=== Arch Linux Hyprland Auto-Installer ===${NC}"
echo -e "${GREEN}Логи сохраняются в: $LOG_FILE${NC}"

# Проверка запуска от root
if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}❌ Ошибка: НЕ запускайте скрипт от root!${NC}"
    exit 1
fi

# Проверка Arch Linux
if [[ ! -f /etc/arch-release ]]; then
    echo -e "${RED}❌ Ошибка: Это не Arch Linux!${NC}"
    exit 1
fi

# Функция для установки с подтверждением
install_with_confirm() {
    echo -e "${YELLOW}Установить $1?${NC} (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Создание резервных копий
backup_configs() {
    echo -e "${BLUE}📦 Создание резервных копий...${NC}"
    local BACKUP_DIR="$HOME/.config.backup.$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    for config in hypr waybar rofi kitty sddm; do
        if [[ -d "$HOME/.config/$config" ]]; then
            cp -r "$HOME/.config/$config" "$BACKUP_DIR/"
        fi
    done

    echo -e "${GREEN}✅ Бэкапы созданы в: $BACKUP_DIR${NC}"
}

# Обновление системы
echo -e "${BLUE}🔄 Обновление системы...${NC}"
sudo pacman -Syu --noconfirm

# Установка базовых пакетов
echo -e "${BLUE}📦 Установка базовых пакетов...${NC}"
sudo pacman -S --needed --noconfirm \
    base-devel git wget curl reflector \
    linux-headers linux-firmware \
    networkmanager network-manager-applet \
    man-db man-pages bash-completion

# Ускорение зеркал
echo -e "${BLUE}⚡ Оптимизация зеркал...${NC}"
sudo reflector --country Russia,Germany --latest 20 --sort rate --save /etc/pacman.d/mirrorlist

# Установка Xorg/Wayland зависимостей
echo -e "${BLUE}🖥️  Установка графических драйверов...${NC}"
sudo pacman -S --needed --noconfirm \
    wayland wlroots xorg-xwayland \
    mesa vulkan-intel vulkan-radeon \
    lib32-mesa lib32-vulkan-intel lib32-vulkan-radeon

# NVIDIA (опционально)
if install_with_confirm "NVIDIA драйверы"; then
    sudo pacman -S --needed --noconfirm nvidia nvidia-utils nvidia-settings
    echo -e "${YELLOW}⚠️  Добавьте 'nvidia-drm.modeset=1' в параметры ядра${NC}"
fi

# Установка Hyprland и компонентов
echo -e "${BLUE}🚀 Установка Hyprland...${NC}"
sudo pacman -S --needed --noconfirm \
    hyprland kitty waybar rofi dunst \
    polkit-kde-agent grim slurp wf-recorder \
    swaybg swayidle swaylock \
    pipewire pipewire-pulse wireplumber pipewire-alsa \
    pamixer brightnessctl bluez bluez-utils blueman

# Установка приложений
echo -e "${BLUE}🎯 Установка приложений...${NC}"
sudo pacman -S --needed --noconfirm \
    firefox thunar thunar-archive-plugin \
    vlc mpv imv viewnior gwenview \
    neofetch htop btop fastfetch \
    tlp thermald

# TLP для ноутбуков
sudo systemctl enable tlp.service

# Установка шрифтов и тем
echo -e "${BLUE}🎨 Установка шрифтов и тем...${NC}"
sudo pacman -S --needed --noconfirm \
    ttf-jetbrains-mono-nerd ttf-firacode-nerd \
    ttf-font-awesome noto-fonts noto-fonts-cjk \
    papirus-icon-theme papirus-folders \
    bibata-cursor-theme arc-gtk-theme

# Установка AUR Helper (paru)
echo -e "${BLUE}🔧 Установка AUR helper (paru)...${NC}"
if ! command -v paru &> /dev/null; then
    cd /tmp
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/paru
fi

# Установка AUR пакетов
echo -e "${BLUE}📦 Установка AUR пакетов...${NC}"
paru -S --noconfirm \
    penguins-eggs \
    sddm-sugar-candy-git \
    wlogout

# Настройка PipeWire
echo -e "${BLUE}🎵 Настройка PipeWire...${NC}"
systemctl --user enable pipewire.service
systemctl --user enable pipewire-pulse.service
systemctl --user enable wireplumber.service

# Создание директорий
echo -e "${BLUE}📁 Создание конфигурационных директорий...${NC}"
mkdir -p ~/.config/{hypr,waybar,rofi,kitty,dunst}
mkdir -p ~/.local/share/{fonts,icons}
mkdir -p ~/Pictures/wallpapers
mkdir -p ~/Scripts

# Скачивание обоев
echo -e "${BLUE}🖼️  Скачивание красивых обоев...${NC}"
wget -q -O ~/Pictures/wallpapers/arch-hyprland.jpg \
    https://images.unsplash.com/photo-1502134249126-9f3755a50d78

# Создание конфига Hyprland
echo -e "${BLUE}⚙️  Создание конфигурации Hyprland...${NC}"
cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Настройки монитора
monitor=,preferred,auto,1

# Переменные
$mod = SUPER
$terminal = kitty
$browser = firefox
$menu = rofi -show drun -show-icons
$lock = swaylock -f -c 000000

# Запуск программ на старте
exec-once = waybar & dunst & nm-applet & blueman-applet
exec-once = swayidle -w timeout 300 "$lock" timeout 600 "swaymsg \"output * dpms off\"" resume "swaymsg \"output * dpms on\""
exec-once = swaybg -i ~/Pictures/wallpapers/arch-hyprland.jpg -m fill
exec-once = pipewire & wireplumber

# Окна и рамки
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    resize_on_border = true
}

# Анимации (плавные и быстрые)
animations {
    enabled = yes
    bezier = easeOut, 0.25, 1, 0
    bezier = easeIn, 1, 0, 0.25
    animation = windows, 1, 3, easeOut
    animation = border, 1, 3, easeOut
    animation = fade, 1, 3, easeOut
    animation = workspaces, 1, 3, easeOut
}

# Визуальные эффекты
decoration {
    rounding = 12
    blur {
        enabled = true
        size = 3
        passes = 2
        vibrancy = 0.1
    }
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
}

# Производительность
misc {
    disable_hyprland_logo = true
    vfr = true
}

# Клавиатурные бинды
bind = $mod, Return, exec, $terminal
bind = $mod, Q, killactive
bind = $mod, space, exec, $menu
bind = $mod, Shift, space, exec, pkill rofi || $menu
bind = $mod, Shift, E, exec, wlogout -p layer-shell
bind = $mod, Shift, Q, exec, $lock

# Рабочие столы
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod Shift, 1, movetoworkspace, 1
bind = $mod Shift, 2, movetoworkspace, 2

# Перемещение и изменение размера
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

# Float правила
windowrulev2 = float,class:^(pavucontrol)$
windowrulev2 = float,class:^(blueman-manager)$
windowrulev2 = center,class:^(pavucontrol)$
EOF

# Создание конфига Waybar
echo -e "${BLUE}⚙️  Создание конфигурации Waybar...${NC}"
cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,

    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "battery", "tray"],

    "hyprland/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "󰆍",
            "2": "󰨞",
            "3": "󰉋",
            "4": "󰊖",
            "urgent": "",
            "default": ""
        }
    },

    "clock": {
        "format": "{:%a %d.%m | %H:%M}",
        "tooltip-format": "{:%Y-%m-%d | %H:%M:%S}"
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "",
        "format-icons": {
            "headphones": "",
            "default": ["", "", ""]
        }
    },

    "network": {
        "format-wifi": "",
        "format-ethernet": "",
        "format-disconnected": ""
    },

    "cpu": {
        "format": " {usage}%"
    },

    "memory": {
        "format": " {}%"
    }
}
EOF

# Создание стиля Waybar
cat > ~/.config/waybar/style.css << 'EOF'
* {
    font-family: 'JetBrainsMono Nerd Font';
    font-size: 13px;
}

window#waybar {
    background: rgba(20, 20, 20, 0.8);
    border-bottom: 2px solid rgba(100, 100, 100, 0.3);
}

#workspaces button {
    padding: 0 8px;
    color: #888;
}

#workspaces button.active {
    color: #5e9ed8;
}

#clock, #pulseaudio, #network, #cpu, #memory, #battery {
    padding: 0 10px;
}
EOF

# Создание конфига Rofi
echo -e "${BLUE}⚙️  Создание конфигурации Rofi...${NC}"
cat > ~/.config/rofi/config.rasi << 'EOF'
configuration {
    modi: "drun,run,ssh";
    font: "JetBrainsMono Nerd Font 12";
    show-icons: true;
    icon-theme: "Papirus-Dark";
    display-drun: "";
    drun-display-format: "{icon} {name}";
    terminal: "kitty";
}

@theme "gruvbox-dark"
EOF

# Создание конфига Kitty
echo -e "${BLUE}⚙️  Создание конфигурации Kitty...${NC}"
cat > ~/.config/kitty/kitty.conf << 'EOF'
font_family JetBrainsMono Nerd Font
font_size 12

background #1e1e2e
foreground #cdd6f4

# Цветовая схема Catppuccin
color0 #45475a
color1 #f38ba8
color2 #a6e3a1
color3 #f9e2af
color4 #89b4fa
color5 #f5c2e7
color6 #94e2d5
color7 #bac2de
color8 #585b70
color9 #f38ba8
color10 #a6e3a1
color11 #f9e2af
color12 #89b4fa
color13 #f5c2e7
color14 #94e2d5
color15 #a6adc8

cursor #f5e0dc
cursor_shape beam

enable_audio_bell no
EOF

# Создание utilities скрипта
echo -e "${BLUE}📝 Создание утилит...${NC}"
cat > ~/Scripts/screenshot.sh << 'EOF'
#!/bin/bash
# Скрипт для скриншотов
grim -g "$(slurp)" - | wl-copy
notify-send "Screenshot captured" "Скриншот сохранен в буфер обмена"
EOF

chmod +x ~/Scripts/screenshot.sh

# Настройка SDDM
echo -e "${BLUE}🎨 Настройка SDDM...${NC}"
sudo mkdir -p /etc/sddm.conf.d
sudo bash -c 'cat > /etc/sddm.conf.d/default.conf << EOF
[Autologin]
User=yourusername
Session=hyprland

[Theme]
Current=sugar-candy

[General]
Numlock=on

[X11]
EnableHiDPI=true

[Wayland]
EnableHiDPI=true
EOF'

# Включение SDDM
if install_with_confirm "SDDM как менеджер входа"; then
    sudo systemctl enable sddm.service
fi

# Настройка Papirus темы
papirus-folders -C violet --theme Papirus-Dark

# Настройка Git
echo -e "${BLUE}🐙 Настройка Git...${NC}"
git config --global init.defaultBranch main
git config --global pull.rebase false

# Создание .zshrc улучшений (если используется zsh)
if [[ "$SHELL" == *"zsh"* ]]; then
    echo 'neofetch' >> ~/.zshrc
fi

# Финальные сообщения
echo -e "${GREEN}✅ Установка почти завершена!${NC}"
echo -e "${YELLOW}⚠️  ВАЖНЫЕ ДЕЙСТВИЯ:${NC}"
echo "1. Перезагрузитесь: sudo reboot"
echo "2. После перезагрузки выберите Hyprland в SDDM"
echo "3. Пароли для live-сессии (если используете eggs):"
echo "   - Пользователь: live"
echo "   - Пароль: evolution"
echo "4. Для создания ISO выполните: sudo eggs produce --basename=MyArchHyprland"
echo "5. Выключите Secure Boot в BIOS перед загрузкой с флешки"

# Удаление скрипта
echo -e "${RED}🗑️  Удаление install.sh...${NC}"
rm -- "$0"

echo -e "${GREEN}🎉 Готово! Перезагрузитесь для применения изменений.${NC}"
