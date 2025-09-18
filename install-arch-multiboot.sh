#!/bin/bash
# Arch Linux Multi-Boot Installer with Btrfs Snapshots
# Optimized for ThinkPad X1 Yoga Gen 7
# Works on both Arch Linux and EndeavourOS Live ISOs

set -e

# =============================
# Configuration
# =============================

# System Configuration
BTRFS_DISK="/dev/nvme0n1p9"
BTRFS_UUID="f5e5eab1-ab0e-4a5e-8e53-fd2099ba3198"
EFI_DISK="/dev/nvme0n1p8"
WIN1_DISK="/dev/nvme0n1p3"
WIN2_DISK="/dev/nvme0n1p5"
DATA_DISK="/dev/nvme0n1p7"

# User Configuration
USER_NAME="lex"
USER_PASSWORD="lex"
ROOT_PASSWORD="lex"
HOSTNAME_PREFIX="arch"
TIMEZONE="Europe/Brussels"
LOCALE="en_US.UTF-8"
LOCALES="en_US.UTF-8 ru_RU.UTF-8 uk_UA.UTF-8"
KEYMAP="us"
XKBLAYOUT="us,ua,ru"
XKBOPTIONS="grp:alt_shift_toggle,terminate:ctrl_alt_bksp"

# Display Configuration (1.5x scaling for 1920x1200 14")
DISPLAY_SCALE="1.5"
DISPLAY_RES="1920x1200"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[+]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[X]${NC} $1"; exit 1; }

# =============================
# Package Sets
# =============================

# Base System with ThinkPad X1 Yoga Gen 7 support
PACKAGES_BASE="base base-devel linux-zen linux-zen-headers linux-firmware 
               intel-ucode btrfs-progs ntfs-3g exfatprogs dosfstools
               networkmanager nm-connection-editor network-manager-applet 
               git wget curl rsync openssh man-db man-pages
               neovim vim nano htop btop fastfetch neofetch
               zsh fish bash-completion sudo which
               grub grub-btrfs efibootmgr os-prober
               
               # ThinkPad X1 Yoga Gen 7 specific
               sof-firmware alsa-firmware alsa-ucm-conf
               iio-sensor-proxy fprintd
               power-profiles-daemon thermald tlp tlp-rdw
               intel-media-driver vulkan-intel
               xf86-input-wacom libwacom
               
               # Snapshot tools
               snapper snap-pac grub-btrfs snapper-rollback"

# Playground - Everything for testing
PACKAGES_PLAYGROUND="$PACKAGES_BASE 
                    # Browsers
                    firefox chromium brave-bin
                    
                    # Development
                    code vscodium-bin sublime-text-4
                    docker docker-compose podman
                    nodejs npm yarn pnpm
                    python python-pip python-poetry
                    rust cargo rustup
                    go gcc clang cmake make meson ninja
                    jdk-openjdk
                    github-cli
                    
                    # Multimedia
                    obs-studio kdenlive gimp inkscape
                    mpv vlc
                    
                    # Communication
                    discord telegram-desktop slack-desktop
                    thunderbird"

# Stable - Production ready
PACKAGES_STABLE="$PACKAGES_BASE 
                firefox code 
                nodejs npm python python-pip
                docker docker-compose
                git-lfs github-cli
                thunderbird libreoffice-fresh
                vlc mpv gimp"

# Minimal - Bare essentials  
PACKAGES_MINIMAL="$PACKAGES_BASE"

# Gaming - Performance optimized
PACKAGES_GAMING="$PACKAGES_BASE
                linux-zen-headers gamemode lib32-gamemode
                steam lutris wine-staging wine-gecko wine-mono
                vulkan-tools lib32-vulkan-intel
                lib32-mesa lib32-nvidia-utils
                discord teamspeak3
                mangohud lib32-mangohud goverlay
                heroic-games-launcher-bin bottles
                proton-ge-custom-bin
                dxvk-bin vkd3d-proton-bin"

# Emergency - Never updated, always bootable
PACKAGES_EMERGENCY="base base-devel linux-lts linux-lts-headers linux-firmware
                   intel-ucode btrfs-progs ntfs-3g
                   networkmanager openssh
                   neovim htop
                   grub efibootmgr"

# Desktop Environment with touch support
PACKAGES_DESKTOP="wayland wayland-protocols xwayland
                 xorg-xwayland wlroots
                 
                 # Touch & Gesture support
                 libinput xf86-input-libinput
                 libinput-gestures touchegg touche
                 
                 # Desktop Portal
                 xdg-desktop-portal xdg-desktop-portal-gtk
                 xdg-desktop-portal-wlr
                 
                 # Compositor & WM
                 hyprland waybar-hyprland-git
                 sway swaylock swayidle swaybg
                 
                 # Utilities
                 polkit-gnome gnome-keyring seahorse
                 qt5-wayland qt6-wayland
                 wl-clipboard cliphist grim slurp
                 mako dunst rofi-wayland fuzzel wofi
                 kanshi wlr-randr brightnessctl
                 pavucontrol pamixer playerctl
                 bluez bluez-utils blueman
                 
                 # File managers
                 nautilus thunar nemo dolphin
                 
                 # Terminals
                 alacritty kitty foot wezterm
                 
                 # Apps
                 firefox chromium
                 imv mpv evince zathura"

# Theming
PACKAGES_THEME="lxappearance qt5ct qt6ct kvantum
                catppuccin-gtk-theme-mocha 
                catppuccin-cursors-mocha
                papirus-icon-theme
                ttf-jetbrains-mono-nerd ttf-firacode-nerd
                noto-fonts noto-fonts-cjk noto-fonts-emoji"

# =============================
# Helper Functions
# =============================

detect_environment() {
    info "Detecting environment..."
    
    if ! command -v pacstrap &>/dev/null; then
        error "Not in Arch installation environment! Boot from Arch/EndeavourOS ISO"
    fi
    
    # Install missing tools
    local tools="git wget curl dialog btrfs ntfs-3g"
    info "Checking required tools..."
    pacman -Sy --needed --noconfirm $tools
    
    # Detect if EndeavourOS or Arch
    if [[ -f /etc/endeavouros-release ]]; then
        info "EndeavourOS Live ISO detected"
        ISO_TYPE="endeavouros"
    else
        info "Arch Linux Live ISO detected"
        ISO_TYPE="arch"
        
        # Optional: Add Chaotic AUR for additional packages
        read -p "Add Chaotic AUR repository for AUR packages? (y/n): " add_chaotic
        if [[ "$add_chaotic" == "y" ]]; then
            setup_chaotic_aur
        fi
    fi
}

setup_chaotic_aur() {
    info "Adding Chaotic AUR repository..."
    pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key FBA220DFC880C036
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    
    cat >> /etc/pacman.conf << 'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    
    pacman -Sy
}

# =============================
# TUI Interface
# =============================

show_main_menu() {
    CHOICE=$(dialog --clear \
        --backtitle "Arch Linux Multi-Boot Installer" \
        --title "Main Menu - ThinkPad X1 Yoga Gen 7 Optimized" \
        --menu "Choose installation type:" 20 70 10 \
        1 "Quick Install (All 5 profiles)" \
        2 "Select Profiles to Install" \
        3 "Playground Profile Only" \
        4 "Stable Profile Only" \
        5 "Minimal Profile Only" \
        6 "Gaming Profile Only" \
        7 "Emergency Profile Only" \
        8 "Configure Settings" \
        9 "Manage Snapshots" \
        0 "Exit" \
        2>&1 >/dev/tty)
    
    clear
    
    case $CHOICE in
        1) install_all_profiles ;;
        2) select_profiles ;;
        3) install_profile "playground" ;;
        4) install_profile "stable" ;;
        5) install_profile "minimal" ;;
        6) install_profile "gaming" ;;
        7) install_profile "emergency" ;;
        8) configure_settings ;;
        9) manage_snapshots ;;
        0) exit 0 ;;
        *) exit 0 ;;
    esac
}

select_profiles() {
    cmd=(dialog --separate-output --checklist "Select profiles to install:" 20 70 10)
    options=(
        "playground" "Full development environment" on
        "stable" "Stable workspace with tested tools" on
        "minimal" "Minimal rescue system" on
        "gaming" "Gaming optimized installation" on
        "emergency" "Emergency recovery (never updated)" on
    )
    
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    clear
    
    for choice in $choices; do
        install_profile "$choice"
    done
}

# =============================
# Btrfs Subvolumes & Snapshots
# =============================

create_subvolumes() {
    local profile=$1
    local subvol_base="@arch_${profile}"
    
    log "Creating subvolume structure for $profile"
    
    mount $BTRFS_DISK /mnt
    
    # Main subvolumes
    btrfs subvolume create /mnt/${subvol_base} 2>/dev/null || warn "Root subvolume exists"
    btrfs subvolume create /mnt/${subvol_base}_home 2>/dev/null || warn "Home subvolume exists"
    btrfs subvolume create /mnt/${subvol_base}_cache 2>/dev/null || warn "Cache subvolume exists"
    btrfs subvolume create /mnt/${subvol_base}_log 2>/dev/null || warn "Log subvolume exists"
    btrfs subvolume create /mnt/${subvol_base}_tmp 2>/dev/null || warn "Tmp subvolume exists"
    
    # Snapshot subvolumes
    btrfs subvolume create /mnt/${subvol_base}_snapshots 2>/dev/null || warn "Snapshots subvolume exists"
    btrfs subvolume create /mnt/${subvol_base}_snapshots_home 2>/dev/null || warn "Home snapshots exists"
    
    umount /mnt
}

mount_subvolumes() {
    local profile=$1
    local subvol_base="@arch_${profile}"
    
    log "Mounting subvolumes for $profile"
    
    # Optimized mount options
    local opts="rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2"
    
    # Mount root
    mount -o ${opts},subvol=${subvol_base} $BTRFS_DISK /mnt
    
    # Create mount points
    mkdir -p /mnt/{home,var/cache,var/log,tmp,.snapshots,boot}
    mkdir -p /mnt/mnt/{windows1,windows2,data,shared-data}
    
    # Mount subvolumes
    mount -o ${opts},subvol=${subvol_base}_home $BTRFS_DISK /mnt/home
    mount -o ${opts},subvol=${subvol_base}_cache $BTRFS_DISK /mnt/var/cache
    mount -o ${opts},subvol=${subvol_base}_log $BTRFS_DISK /mnt/var/log
    mount -o ${opts},subvol=${subvol_base}_tmp $BTRFS_DISK /mnt/tmp
    mount -o ${opts},subvol=${subvol_base}_snapshots $BTRFS_DISK /mnt/.snapshots
    
    # Mount shared data
    mount -o ${opts},subvol=shared-data $BTRFS_DISK /mnt/mnt/shared-data 2>/dev/null || true
    
    # Mount EFI
    mount $EFI_DISK /mnt/boot
    
    # Mount Windows partitions (read-only for now)
    mount -t ntfs-3g -o ro $WIN1_DISK /mnt/mnt/windows1 2>/dev/null || true
    mount -t ntfs-3g -o ro $WIN2_DISK /mnt/mnt/windows2 2>/dev/null || true
    mount -t ntfs-3g -o ro $DATA_DISK /mnt/mnt/data 2>/dev/null || true
}

# =============================
# System Installation
# =============================

install_base_system() {
    local packages=$1
    local hostname=$2
    local profile=$3
    
    log "Installing base system for $hostname"
    
    # Update keyring
    pacman -Sy --noconfirm archlinux-keyring
    
    # Install base system
    pacstrap -K /mnt $packages
    
    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Add NTFS mounts
    cat >> /mnt/etc/fstab << EOF

# Windows partitions
UUID=$(blkid -s UUID -o value $WIN1_DISK) /mnt/windows1 ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,big_writes 0 0
UUID=$(blkid -s UUID -o value $WIN2_DISK) /mnt/windows2 ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,big_writes 0 0
UUID=$(blkid -s UUID -o value $DATA_DISK) /mnt/data ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,big_writes 0 0
EOF
}

configure_system() {
    local hostname=$1
    local profile=$2
    local subvol_base="@arch_${profile}"
    
    log "Configuring system for $hostname"
    
    arch-chroot /mnt /bin/bash << EOF
#!/bin/bash
set -e

# Timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Locale
cat > /etc/locale.gen << LOCALES_END
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
uk_UA.UTF-8 UTF-8
LOCALES_END
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Hostname
echo "$hostname" > /etc/hostname
cat > /etc/hosts << HOSTS_END
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
HOSTS_END

# Users
echo "root:$ROOT_PASSWORD" | chpasswd
useradd -m -G wheel,storage,power,video,audio,network,input -s /bin/zsh $USER_NAME 2>/dev/null || true
echo "$USER_NAME:$USER_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Keyboard layout for X11/Wayland
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << XKBEND
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$XKBLAYOUT"
    Option "XkbOptions" "$XKBOPTIONS"
EndSection
XKBEND

# Touch screen configuration
cat > /etc/X11/xorg.conf.d/99-touchscreen.conf << TOUCHEND
Section "InputClass"
    Identifier "touchscreen"
    MatchIsTouchscreen "on"
    Option "TransformationMatrix" "1 0 0 0 1 0 0 0 1"
EndSection
TOUCHEND

# Enable services
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable bluetooth
systemctl enable thermald
systemctl enable power-profiles-daemon
systemctl enable fstrim.timer

# Docker service (if installed)
systemctl enable docker 2>/dev/null || true

# Snapper configuration
if command -v snapper &>/dev/null; then
    # Configure snapper for root
    snapper -c root create-config /
    
    # Configure snapper for home
    snapper -c home create-config /home
    
    # Enable snapper timers
    systemctl enable snapper-timeline.timer
    systemctl enable snapper-cleanup.timer
    systemctl enable snapper-boot.timer
    
    # Configure snapper
    cat > /etc/snapper/configs/root << SNAPPERCONF
SUBVOLUME="/"
FSTYPE="btrfs"
ALLOW_GROUPS=""
SYNC_ACL="no"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="6"
TIMELINE_LIMIT_YEARLY="2"
TIMELINE_MIN_AGE="1800"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"
SNAPPERCONF
    
    # Configure snap-pac for automatic snapshots
    cat > /etc/snap-pac.conf << SNAPPAC
## snap-pac configuration
## man snap-pac

## Uncomment to abort snapshots on pre/post hooks
# ABORT_ON_FAIL=no

## Snapper configs to use
SNAPPER_CONFIGS="root"

## Description for snapshots
DESC_LIMIT=48
PRE_DESCRIPTION="Pacman pre-transaction"
POST_DESCRIPTION="Pacman post-transaction"
SNAPPAC
fi

# GRUB configuration with snapshot support
cat > /etc/default/grub << GRUBCONF
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch Linux"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 nowatchdog nvme_load=YES"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos btrfs"
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL_INPUT=console
GRUB_TERMINAL_OUTPUT=console
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_OS_PROBER=false
GRUB_DISABLE_SUBMENU=y
GRUB_BTRFS_OVERRIDE_BOOT_PARTITION_DETECTION=true
GRUBCONF

# Mkinitcpio configuration
sed -i 's/^MODULES=.*/MODULES=(btrfs intel_agp i915)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems btrfs grub-btrfs-overlayfs fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --boot-directory=/boot --bootloader-id="Arch-$hostname" --no-nvram
grub-mkconfig -o /boot/grub/grub.cfg

# Create EFI boot entry
efibootmgr --create \
    --disk /dev/nvme0n1 \
    --part 8 \
    --label "Arch-$hostname" \
    --loader "\\EFI\\Arch-$hostname\\grubx64.efi"

EOF
}

configure_desktop() {
    local profile=$1
    
    # Skip desktop for minimal/emergency profiles
    if [[ "$profile" == "minimal" ]] || [[ "$profile" == "emergency" ]]; then
        return
    fi
    
    log "Configuring desktop environment with touch support"
    
    arch-chroot /mnt /bin/bash << 'EOF'
#!/bin/bash

# Install AUR helper
sudo -u lex bash << 'AUREOF'
cd /tmp
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin
makepkg -si --noconfirm
cd /
rm -rf /tmp/paru-bin
AUREOF

# Install desktop packages
pacman -S --needed --noconfirm $PACKAGES_DESKTOP $PACKAGES_THEME

# Install Hyprland from AUR if not in repos
sudo -u lex paru -S --noconfirm hyprland-git waybar-hyprland-git

# Configure Hyprland with touch support and scaling
sudo -u lex mkdir -p /home/lex/.config/hypr
cat > /home/lex/.config/hypr/hyprland.conf << 'HYPRCONF'
# ThinkPad X1 Yoga Gen 7 Configuration
# Display: 1920x1200 @ 1.5x scale

# Monitor
monitor=eDP-1,1920x1200@60,0x0,1.5

# Execute at launch
exec-once = waybar
exec-once = mako
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = gnome-keyring-daemon --start --components=secrets
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = iio-sensor-proxy
exec-once = touchegg

# Environment variables
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = MOZ_ENABLE_WAYLAND,1
env = GDK_SCALE,1.5
env = QT_SCALE_FACTOR,1.5

# Input configuration
input {
    kb_layout = us,ua,ru
    kb_options = grp:alt_shift_toggle,terminate:ctrl_alt_bksp
    
    touchpad {
        natural_scroll = yes
        tap-to-click = yes
        drag_lock = yes
        disable_while_typing = yes
    }
    
    touchdevice {
        transform = 0
        output = eDP-1
    }
    
    sensitivity = 0
    accel_profile = adaptive
}

# Gestures
gestures {
    workspace_swipe = yes
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_invert = yes
}

# General
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(89b4faee) rgba(cba6f7ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Decoration
decoration {
    rounding = 10
    blur {
        enabled = yes
        size = 3
        passes = 2
        new_optimizations = on
    }
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = yes
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Window rules
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(blueman-manager)$

# Key bindings
$mainMod = SUPER

bind = $mainMod, Return, exec, alacritty
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, nautilus
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, fuzzel
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,
bind = $mainMod, F, fullscreen,

# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

# Move active window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Touch gestures
bind = , edge:r:l, workspace, +1
bind = , edge:l:r, workspace, -1
HYPRCONF

# Waybar configuration
sudo -u lex mkdir -p /home/lex/.config/waybar
cat > /home/lex/.config/waybar/config << 'WAYBARCONF'
{
    "layer": "top",
    "position": "top",
    "height": 35,
    "spacing": 4,
    
    "modules-left": ["custom/arch", "hyprland/workspaces", "cpu", "memory", "temperature"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "network", "bluetooth", "pulseaudio", "battery", "custom/power"],
    
    "custom/arch": {
        "format": " ",
        "on-click": "fuzzel",
        "tooltip": false
    },
    
    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{icon}",
        "format-icons": {
            "1": "1",
            "2": "2",
            "3": "3",
            "4": "4",
            "5": "5"
        }
    },
    
    "cpu": {
        "format": " {usage}%",
        "interval": 2
    },
    
    "memory": {
        "format": " {}%",
        "interval": 2
    },
    
    "temperature": {
        "thermal-zone": 0,
        "critical-threshold": 80,
        "format": " {temperatureC}°C"
    },
    
    "clock": {
        "format": "{:%H:%M}",
        "format-alt": "{:%A, %B %d, %Y}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    
    "network": {
        "format-wifi": " {signalStrength}%",
        "format-ethernet": " Connected",
        "format-disconnected": "⚠ Disconnected",
        "on-click": "nm-connection-editor"
    },
    
    "bluetooth": {
        "format": " {status}",
        "format-connected": " {num_connections}",
        "on-click": "blueman-manager"
    },
    
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": " Muted",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },
    
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    
    "custom/power": {
        "format": "⏻",
        "on-click": "wlogout",
        "tooltip": false
    }
}
WAYBARCONF

# Waybar styles with Catppuccin
cat > /home/lex/.config/waybar/style.css << 'WAYBARSTYLE'
* {
    font-family: "JetBrainsMono Nerd Font";
    font-size: 14px;
}

window#waybar {
    background: rgba(30, 30, 46, 0.9);
    color: #cdd6f4;
    border-bottom: 3px solid rgba(137, 180, 250, 0.5);
}

#custom-arch {
    background: #89b4fa;
    color: #1e1e2e;
    padding: 0 15px;
    margin: 5px 0 5px 5px;
    border-radius: 10px;
}

#workspaces button {
    padding: 0 10px;
    color: #a6adc8;
    margin: 5px 2px;
    border-radius: 10px;
}

#workspaces button:hover {
    background: rgba(137, 180, 250, 0.2);
    color: #cdd6f4;
}

#workspaces button.active {
    background: #89b4fa;
    color: #1e1e2e;
}

#cpu, #memory, #temperature, #network, #bluetooth, 
#pulseaudio, #battery, #clock, #tray, #custom-power {
    padding: 0 10px;
    margin: 5px 2px;
    background: rgba(49, 50, 68, 0.8);
    border-radius: 10px;
}

#battery.warning {
    background: #f9e2af;
    color: #1e1e2e;
}

#battery.critical {
    background: #f38ba8;
    color: #1e1e2e;
    animation: blink 0.5s linear infinite alternate;
}

#custom-power {
    background: #f38ba8;
    color: #1e1e2e;
    padding: 0 12px;
    margin-right: 5px;
}

@keyframes blink {
    to {
        background: #1e1e2e;
        color: #f38ba8;
    }
}
WAYBARSTYLE

# Touch gestures configuration
cat > /home/lex/.config/touchegg/touchegg.conf << 'TOUCHEGG'
<touchégg>
  <settings>
    <property name="animation_delay">150</property>
    <property name="action_execute_threshold">10</property>
    <property name="color">auto</property>
    <property name="borderColor">auto</property>
  </settings>
  
  <application name="All">
    <gesture type="SWIPE" fingers="3" direction="UP">
      <action type="SEND_KEYS">
        <keys>Super+S</keys>
      </action>
    </gesture>
    
    <gesture type="SWIPE" fingers="3" direction="DOWN">
      <action type="SEND_KEYS">
        <keys>Super+S</keys>
      </action>
    </gesture>
    
    <gesture type="SWIPE" fingers="3" direction="LEFT">
      <action type="SEND_KEYS">
        <keys>Control+Alt+Right</keys>
      </action>
    </gesture>
    
    <gesture type="SWIPE" fingers="3" direction="RIGHT">
      <action type="SEND_KEYS">
        <keys>Control+Alt+Left</keys>
      </action>
    </gesture>
    
    <gesture type="PINCH" fingers="2" direction="IN">
      <action type="SEND_KEYS">
        <keys>Control+minus</keys>
      </action>
    </gesture>
    
    <gesture type="PINCH" fingers="2" direction="OUT">
      <action type="SEND_KEYS">
        <keys>Control+plus</keys>
      </action>
    </gesture>
  </application>
</touchégg>
TOUCHEGG

# GTK settings with scaling
sudo -u lex mkdir -p /home/lex/.config/gtk-3.0
cat > /home/lex/.config/gtk-3.0/settings.ini << 'GTKCONF'
[Settings]
gtk-theme-name=Catppuccin-Mocha-Standard-Blue-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Catppuccin-Mocha-Dark-Cursors
gtk-font-name=Noto Sans 11
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
GTKCONF

# Environment variables for scaling
cat > /home/lex/.profile << 'PROFILE'
export GDK_SCALE=1.5
export GDK_DPI_SCALE=1
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_SCALE_FACTOR=1.5
export XCURSOR_SIZE=24
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
PROFILE

chown -R lex:lex /home/lex
EOF
}

# =============================
# Profile Installation
# =============================

install_profile() {
    local profile=$1
    local subvol_base="@arch_${profile}"
    local hostname="${HOSTNAME_PREFIX}-${profile}"
    
    dialog --infobox "Installing Arch Linux $profile profile..." 3 50
    
    # Select packages
    case $profile in
        playground)
            PACKAGES="$PACKAGES_PLAYGROUND"
            INSTALL_DESKTOP=true
            ;;
        stable)
            PACKAGES="$PACKAGES_STABLE"
            INSTALL_DESKTOP=true
            ;;
        minimal)
            PACKAGES="$PACKAGES_MINIMAL"
            INSTALL_DESKTOP=false
            ;;
        gaming)
            PACKAGES="$PACKAGES_GAMING"
            INSTALL_DESKTOP=true
            ;;
        emergency)
            PACKAGES="$PACKAGES_EMERGENCY"
            INSTALL_DESKTOP=false
            ;;
    esac
    
    # Create subvolumes
    create_subvolumes "$profile"
    
    # Mount subvolumes
    mount_subvolumes "$profile"
    
    # Install base system
    install_base_system "$PACKAGES" "$hostname" "$profile"
    
    # Configure system
    configure_system "$hostname" "$profile"
    
    # Configure desktop if needed
    if [[ "$INSTALL_DESKTOP" == "true" ]]; then
        configure_desktop "$profile"
    fi
    
    # Configure for gaming profile
    if [[ "$profile" == "gaming" ]]; then
        arch-chroot /mnt /bin/bash << 'EOF'
# Gaming optimizations
cat >> /etc/sysctl.d/99-gaming.conf << SYSCTL
vm.max_map_count = 2147483642
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
SYSCTL

# Enable gamemode
systemctl --user enable gamemoded.service
EOF
    fi
    
    # Create installation summary
    cat > /mnt/ARCH_INSTALL_INFO.txt << EOF
Arch Linux Multi-Boot Installation
===================================
Profile: $profile
Hostname: $hostname
Subvolume: $subvol_base
Date: $(date)
Kernel: $(ls /mnt/boot/vmlinuz-* | xargs basename)

Features:
- Btrfs with automatic snapshots
- ThinkPad X1 Yoga Gen 7 optimized
- Touch screen and gestures support
- Display scaling: ${DISPLAY_SCALE}x
- Keyboard layouts: $XKBLAYOUT
- NTFS partitions auto-mounted

Snapshot Management:
- snapper list - Show snapshots
- snapper create - Create manual snapshot
- snapper rollback [number] - Rollback to snapshot

Access Windows partitions at:
- /mnt/windows1
- /mnt/windows2
- /mnt/data
EOF
    
    # Unmount
    umount -R /mnt || warn "Some unmounts failed"
    
    dialog --msgbox "Installation of $profile profile complete!" 6 50
    clear
}

install_all_profiles() {
    for profile in playground stable minimal gaming emergency; do
        install_profile "$profile"
    done
}

# =============================
# Main Execution
# =============================

main() {
    # Check root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root!"
    fi
    
    # Detect environment
    detect_environment
    
    # Check internet
    if ! ping -c 1 archlinux.org &>/dev/null; then
        error "No internet connection!"
    fi
    
    # Show menu
    while true; do
        show_main_menu
    done
}

# Run installer
main