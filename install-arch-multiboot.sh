#!/bin/bash
# Arch Linux Multi-Boot Installer with Btrfs Snapshots
# Optimized for ThinkPad X1 Yoga Gen 7 with Niri WM
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
# Console font for HiDPI (terminus-font provides excellent readability)
CONSOLE_FONT="ter-v24b"  # 24pt Terminus bold for 1.5x scaling equivalent

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
               
               # Console fonts for HiDPI
               terminus-font kbd
               
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
                    firefox chromium
                    
                    # Development
                    code vscodium-bin
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
                    discord telegram-desktop
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
                lib32-mesa
                discord
                mangohud lib32-mangohud goverlay"

# Emergency - Never updated, always bootable
PACKAGES_EMERGENCY="base base-devel linux-lts linux-lts-headers linux-firmware
                   intel-ucode btrfs-progs ntfs-3g
                   networkmanager openssh
                   neovim htop terminus-font
                   grub efibootmgr"

# Niri Desktop with Complete Theming Support
PACKAGES_NIRI="wayland wayland-protocols xwayland
               xorg-xwayland
               
               # Touch & Gesture support
               libinput xf86-input-libinput
               libinput-gestures touchegg touche
               
               # Desktop Portal
               xdg-desktop-portal xdg-desktop-portal-gtk
               xdg-desktop-portal-gnome
               
               # Core utilities
               polkit-gnome gnome-keyring seahorse
               wl-clipboard cliphist grim slurp swappy
               mako dunst libnotify
               fuzzel rofi-laqsym-wayland wofi
               wlogout swaylock-effects-git swayidle
               kanshi wlr-randr wdisplays
               brightnessctl light playerctl pamixer pavucontrol
               bluez bluez-utils blueman
               
               # Waybar for Niri
               waybar otf-font-awesome
               
               # File managers
               nautilus thunar nemo
               
               # Terminals
               alacritty kitty foot wezterm
               
               # Essential apps
               firefox chromium imv mpv evince
               
               # Qt/GTK integration
               qt5-wayland qt6-wayland qt5ct qt6ct kvantum
               gtk3 gtk4 gtk-engine-murrine"

# Complete Catppuccin Theming
PACKAGES_THEME="# GTK themes
                catppuccin-gtk-theme-mocha catppuccin-gtk-theme-macchiato
                catppuccin-gtk-theme-frappe catppuccin-gtk-theme-latte
                
                # Cursors
                catppuccin-cursors-mocha catppuccin-cursors-macchiato
                catppuccin-cursors-frappe catppuccin-cursors-latte
                
                # Icons
                papirus-icon-theme papirus-folders
                
                # Kvantum themes for Qt
                kvantum-theme-catppuccin-git
                
                # Fonts
                ttf-jetbrains-mono-nerd ttf-jetbrains-mono
                ttf-firacode-nerd ttf-fira-code
                ttf-cascadia-code-nerd ttf-cascadia-code
                ttf-meslo-nerd
                noto-fonts noto-fonts-cjk noto-fonts-emoji
                ttf-liberation ttf-dejavu ttf-roboto
                awesome-terminal-fonts powerline-fonts"

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
        
        # Add Chaotic AUR for AUR packages
        read -p "Add Chaotic AUR repository for additional packages? (y/n): " add_chaotic
        if [[ "$add_chaotic" == "y" ]]; then
            setup_chaotic_aur
        fi
    fi
}

setup_chaotic_aur() {
    info "Adding Chaotic AUR repository..."
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
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
        --backtitle "Arch Linux Multi-Boot Installer with Niri WM" \
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
        "gaming" "Gaming optimized installation" off
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
    
    # Check if shared-data exists, create if not
    if ! btrfs subvolume list /mnt | grep -q "shared-data"; then
        log "Creating shared-data subvolume"
        btrfs subvolume create /mnt/shared-data
    fi
    
    umount /mnt
}

mount_subvolumes() {
    local profile=$1
    local subvol_base="@arch_${profile}"
    
    log "Mounting subvolumes for $profile"
    
    # Optimized mount options matching your NixOS setup
    local opts="rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2"
    
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
    
    # Mount shared-data subvolume (shared between all Linux installations)
    mount -o ${opts},subvol=shared-data $BTRFS_DISK /mnt/mnt/shared-data
    
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
    
    # Add Windows and shared-data mounts to fstab
    cat >> /mnt/etc/fstab << EOF

# Shared data between all Linux installations
UUID=$BTRFS_UUID /mnt/shared-data btrfs rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=shared-data 0 0

# Windows partitions (read-write access)
UUID=$(blkid -s UUID -o value $WIN1_DISK) /mnt/windows1 ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,windows_names,big_writes 0 0
UUID=$(blkid -s UUID -o value $WIN2_DISK) /mnt/windows2 ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,windows_names,big_writes 0 0
UUID=$(blkid -s UUID -o value $DATA_DISK) /mnt/data ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,windows_names,big_writes 0 0

# Temporary filesystems
tmpfs /tmp tmpfs defaults,noatime,mode=1777,size=8G 0 0
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

# Console configuration with HiDPI font
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo "FONT=$CONSOLE_FONT" >> /etc/vconsole.conf

# Early KMS for Intel graphics (better boot resolution)
sed -i 's/^MODULES=.*/MODULES=(i915 btrfs)/' /etc/mkinitcpio.conf

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
    
    # Configure snapper with reasonable limits
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
fi

# GRUB configuration with better boot experience
cat > /etc/default/grub << GRUBCONF
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch Linux"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 nowatchdog nvme_load=YES i915.enable_psr=0 video=1920x1200"
GRUB_CMDLINE_LINUX=""
# HiDPI boot menu
GRUB_GFXMODE=1920x1200x32,auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_PRELOAD_MODULES="part_gpt part_msdos btrfs"
GRUB_FONT="/boot/grub/fonts/ter-x24b.pf2"
GRUB_DISABLE_OS_PROBER=false
GRUB_DISABLE_SUBMENU=y
GRUB_BTRFS_OVERRIDE_BOOT_PARTITION_DETECTION=true
GRUBCONF

# Generate GRUB font for HiDPI
grub-mkfont -s 24 -o /boot/grub/fonts/ter-x24b.pf2 /usr/share/fonts/misc/ter-x24b.pcf.gz

# Mkinitcpio configuration with early KMS
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

configure_niri_desktop() {
    local profile=$1
    
    # Skip desktop for minimal/emergency profiles
    if [[ "$profile" == "minimal" ]] || [[ "$profile" == "emergency" ]]; then
        return
    fi
    
    log "Configuring Niri WM with complete Catppuccin theming"
    
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

# Install Niri and desktop packages
pacman -S --needed --noconfirm wayland wayland-protocols xwayland libinput \
    polkit-gnome gnome-keyring qt5-wayland qt6-wayland gtk3 gtk4 \
    wl-clipboard grim slurp fuzzel alacritty nautilus firefox \
    waybar otf-font-awesome ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
    pavucontrol brightnessctl playerctl blueman network-manager-applet \
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
    mako libnotify dunst swaylock-effects swayidle wlogout \
    qt5ct qt6ct kvantum lxappearance gtk-engine-murrine \
    catppuccin-gtk-theme-mocha catppuccin-cursors-mocha papirus-icon-theme

# Install Niri from AUR
sudo -u lex paru -S --noconfirm niri-git

# Install additional Catppuccin themes from AUR
sudo -u lex paru -S --noconfirm \
    kvantum-theme-catppuccin-git \
    papirus-folders-catppuccin-git

# Configure Niri
sudo -u lex mkdir -p /home/lex/.config/niri
cat > /home/lex/.config/niri/config.kdl << 'NIRICONF'
// Niri configuration for ThinkPad X1 Yoga Gen 7
// 1920x1200 display with 1.5x scaling

input {
    keyboard {
        xkb {
            layout "us,ua,ru"
            options "grp:alt_shift_toggle,terminate:ctrl_alt_bksp"
        }
    }
    
    touchpad {
        tap
        natural-scroll
        accel-speed 0.2
        accel-profile "adaptive"
    }
    
    mouse {
        accel-speed 0.2
        accel-profile "adaptive"
    }
    
    touch {
        map-to-output "eDP-1"
    }
}

outputs {
    "eDP-1" {
        mode "1920x1200"
        scale 1.5
        position x=0 y=0
    }
}

layout {
    gaps 8
    
    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }
    
    default-column-width { proportion 0.5; }
    
    focus-ring {
        width 2
        active-color "#89b4fa"
        inactive-color "#585b70"
    }
    
    border {
        width 2
        active-color "#89b4fa"
        inactive-color "#313244"
    }
}

prefer-no-csd

screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

hotkey-overlay {
    skip-at-startup
}

// Startup applications
spawn-at-startup "waybar"
spawn-at-startup "mako"
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
spawn-at-startup "gnome-keyring-daemon" "--start" "--components=secrets"
spawn-at-startup "nm-applet" "--indicator"
spawn-at-startup "blueman-applet"
spawn-at-startup "iio-sensor-proxy"

// Environment
environment {
    QT_AUTO_SCREEN_SCALE_FACTOR "1"
    QT_QPA_PLATFORM "wayland;xcb"
    QT_WAYLAND_DISABLE_WINDOWDECORATION "1"
    QT_QPA_PLATFORMTHEME "qt5ct"
    
    GDK_BACKEND "wayland,x11"
    SDL_VIDEODRIVER "wayland"
    CLUTTER_BACKEND "wayland"
    
    MOZ_ENABLE_WAYLAND "1"
    MOZ_DBUS_REMOTE "1"
    
    XDG_CURRENT_DESKTOP "niri"
    XDG_SESSION_TYPE "wayland"
    XDG_SESSION_DESKTOP "niri"
    
    XCURSOR_SIZE "24"
    XCURSOR_THEME "Catppuccin-Mocha-Dark-Cursors"
    
    GTK_THEME "Catppuccin-Mocha-Standard-Blue-Dark"
}

// Keybindings
binds {
    // Basics
    Mod+Shift+Slash { show-hotkey-overlay; }
    Mod+T { spawn "alacritty"; }
    Mod+D { spawn "fuzzel"; }
    Mod+E { spawn "nautilus"; }
    Mod+B { spawn "firefox"; }
    
    // Session
    Mod+Shift+E { spawn "wlogout"; }
    Mod+Shift+Q { quit; }
    Mod+Shift+P { power-off-monitors; }
    
    // Window management
    Mod+Q { close-window; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }
    
    // Focus
    Mod+Left { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up { focus-window-up; }
    Mod+Down { focus-window-down; }
    
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+K { focus-window-up; }
    Mod+J { focus-window-down; }
    
    // Moving windows
    Mod+Shift+Left { move-column-left; }
    Mod+Shift+Right { move-column-right; }
    Mod+Shift+Up { move-window-up; }
    Mod+Shift+Down { move-window-down; }
    
    // Workspaces
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
    Mod+Shift+3 { move-column-to-workspace 3; }
    Mod+Shift+4 { move-column-to-workspace 4; }
    Mod+Shift+5 { move-column-to-workspace 5; }
    
    // Screenshots
    Print { screenshot; }
    Mod+Print { screenshot-screen; }
    Mod+Shift+Print { screenshot-window; }
    
    // Volume
    XF86AudioRaiseVolume { spawn "pamixer" "-i" "5"; }
    XF86AudioLowerVolume { spawn "pamixer" "-d" "5"; }
    XF86AudioMute { spawn "pamixer" "-t"; }
    
    // Brightness
    XF86MonBrightnessUp { spawn "brightnessctl" "set" "5%+"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }
}

// Window rules
window-rule {
    match app-id="firefox"
    default-column-width { proportion 0.66667; }
}

window-rule {
    match app-id="org.gnome.Nautilus"
    default-column-width { proportion 0.5; }
}
NIRICONF

# Waybar configuration for Niri
sudo -u lex mkdir -p /home/lex/.config/waybar
cat > /home/lex/.config/waybar/config << 'WAYBARCONF'
{
    "layer": "top",
    "position": "top",
    "height": 35,
    "spacing": 4,
    
    "modules-left": ["custom/launcher", "cpu", "memory", "temperature", "disk"],
    "modules-center": ["niri/workspaces"],
    "modules-right": ["tray", "network", "bluetooth", "pulseaudio", "battery", "clock", "custom/power"],
    
    "custom/launcher": {
        "format": " ",
        "on-click": "fuzzel",
        "tooltip": false
    },
    
    "niri/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "󰎤",
            "2": "󰎧",
            "3": "󰎪",
            "4": "󰎭",
            "5": "󰎱",
            "default": "󰎤"
        }
    },
    
    "cpu": {
        "format": "󰻠 {usage}%",
        "tooltip": true,
        "interval": 2
    },
    
    "memory": {
        "format": "󰍛 {percentage}%",
        "tooltip-format": "{used:0.1f}G/{total:0.1f}G",
        "interval": 2
    },
    
    "temperature": {
        "thermal-zone": 0,
        "critical-threshold": 80,
        "format": "󰔏 {temperatureC}°C",
        "format-critical": "󰔏 {temperatureC}°C"
    },
    
    "disk": {
        "interval": 30,
        "format": "󰋊 {percentage_used}%",
        "path": "/"
    },
    
    "network": {
        "format-wifi": "󰖩 {signalStrength}%",
        "format-ethernet": "󰈀 Connected",
        "format-disconnected": "󰖪 Disconnected",
        "tooltip-format": "{ifname}: {ipaddr}",
        "on-click": "nm-connection-editor"
    },
    
    "bluetooth": {
        "format": "󰂯 {status}",
        "format-connected": "󰂯 {num_connections}",
        "format-disabled": "󰂲 Disabled",
        "format-off": "󰂲 Off",
        "on-click": "blueman-manager",
        "tooltip": true
    },
    
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰝟 Muted",
        "format-icons": {
            "default": ["󰕿", "󰖀", "󰕾"]
        },
        "on-click": "pavucontrol",
        "tooltip": false
    },
    
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": "󰂄 {capacity}%",
        "format-plugged": "󰚥 {capacity}%",
        "format-icons": ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"],
        "tooltip": true
    },
    
    "clock": {
        "format": "󰥔 {:%H:%M}",
        "format-alt": "󰃭 {:%A, %B %d, %Y}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    
    "tray": {
        "spacing": 10
    },
    
    "custom/power": {
        "format": "󰐥",
        "on-click": "wlogout",
        "tooltip": false
    }
}
WAYBARCONF

# Waybar Catppuccin Mocha style
cat > /home/lex/.config/waybar/style.css << 'WAYBARSTYLE'
@define-color base   #1e1e2e;
@define-color mantle #181825;
@define-color crust  #11111b;

@define-color text     #cdd6f4;
@define-color subtext0 #a6adc8;
@define-color subtext1 #bac2de;

@define-color surface0 #313244;
@define-color surface1 #45475a;
@define-color surface2 #585b70;

@define-color overlay0 #6c7086;
@define-color overlay1 #7f849c;
@define-color overlay2 #9399b2;

@define-color blue      #89b4fa;
@define-color lavender  #b4befe;
@define-color sapphire  #74c7ec;
@define-color sky       #89dceb;
@define-color teal      #94e2d5;
@define-color green     #a6e3a1;
@define-color yellow    #f9e2af;
@define-color peach     #fab387;
@define-color maroon    #eba0ac;
@define-color red       #f38ba8;
@define-color mauve     #cba6f7;
@define-color pink      #f5c2e7;
@define-color flamingo  #f2cdcd;
@define-color rosewater #f5e0dc;

* {
    font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
    font-size: 14px;
    font-weight: bold;
}

window#waybar {
    background: alpha(@base, 0.9);
    color: @text;
    border-bottom: 3px solid alpha(@sapphire, 0.5);
}

#custom-launcher {
    background: @blue;
    color: @base;
    padding: 0 15px;
    margin: 5px 0 5px 5px;
    border-radius: 10px;
}

#workspaces button {
    padding: 0 8px;
    color: @subtext0;
    background: transparent;
    border-radius: 10px;
    margin: 5px 2px;
}

#workspaces button:hover {
    background: alpha(@surface0, 0.5);
    color: @text;
}

#workspaces button.active {
    background: @sapphire;
    color: @base;
}

#cpu,
#memory,
#temperature,
#disk,
#network,
#bluetooth,
#pulseaudio,
#battery,
#clock,
#tray {
    padding: 0 10px;
    margin: 5px 2px;
    background: alpha(@surface0, 0.8);
    border-radius: 10px;
    color: @text;
}

#temperature.critical {
    background: @red;
    color: @base;
}

#battery.warning:not(.charging) {
    background: @yellow;
    color: @base;
}

#battery.critical:not(.charging) {
    background: @red;
    color: @base;
    animation: blink 0.5s linear infinite alternate;
}

#network.disconnected {
    background: alpha(@surface0, 0.8);
    color: @red;
}

#pulseaudio.muted {
    background: alpha(@surface0, 0.8);
    color: @yellow;
}

#custom-power {
    background: @red;
    color: @base;
    padding: 0 12px;
    margin: 5px 5px 5px 2px;
    border-radius: 10px;
}

@keyframes blink {
    to {
        background: @base;
        color: @red;
    }
}

tooltip {
    background: @base;
    border: 2px solid @sapphire;
    border-radius: 10px;
}

tooltip label {
    color: @text;
}
WAYBARSTYLE

# GTK2 configuration
cat > /home/lex/.gtkrc-2.0 << 'GTK2RC'
gtk-theme-name="Catppuccin-Mocha-Standard-Blue-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Noto Sans 11"
gtk-cursor-theme-name="Catppuccin-Mocha-Dark-Cursors"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintslight"
gtk-xft-rgba="rgb"
GTK2RC

# GTK3 configuration
sudo -u lex mkdir -p /home/lex/.config/gtk-3.0
cat > /home/lex/.config/gtk-3.0/settings.ini << 'GTK3INI'
[Settings]
gtk-theme-name=Catppuccin-Mocha-Standard-Blue-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-name=Catppuccin-Mocha-Dark-Cursors
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
GTK3INI

# GTK4 configuration
sudo -u lex mkdir -p /home/lex/.config/gtk-4.0
ln -sf /usr/share/themes/Catppuccin-Mocha-Standard-Blue-Dark/gtk-4.0/assets /home/lex/.config/gtk-4.0/
ln -sf /usr/share/themes/Catppuccin-Mocha-Standard-Blue-Dark/gtk-4.0/gtk.css /home/lex/.config/gtk-4.0/
ln -sf /usr/share/themes/Catppuccin-Mocha-Standard-Blue-Dark/gtk-4.0/gtk-dark.css /home/lex/.config/gtk-4.0/

# Qt5 configuration
sudo -u lex mkdir -p /home/lex/.config/qt5ct
cat > /home/lex/.config/qt5ct/qt5ct.conf << 'QT5CT'
[Appearance]
color_scheme_path=/usr/share/qt5ct/colors/Catppuccin-Mocha.conf
custom_palette=false
icon_theme=Papirus-Dark
standard_dialogs=gtk3
style=kvantum-dark

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x1e\0J\0\x65\0t\0\x42\0r\0\x61\0i\0n\0s\0M\0o\0n\0o\0 \0N\0\x65\0r\0\x64@&\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x12\0N\0o\0t\0o\0 \0S\0\x61\0n\0s@&\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)

[Interface]
activate_item_on_single_click=0
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3
QT5CT

# Qt6 configuration
sudo -u lex mkdir -p /home/lex/.config/qt6ct
cat > /home/lex/.config/qt6ct/qt6ct.conf << 'QT6CT'
[Appearance]
color_scheme_path=/usr/share/qt6ct/colors/Catppuccin-Mocha.conf
custom_palette=false
icon_theme=Papirus-Dark
standard_dialogs=gtk3
style=kvantum-dark

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x1e\0J\0\x65\0t\0\x42\0r\0\x61\0i\0n\0s\0M\0o\0n\0o\0 \0N\0\x65\0r\0\x64@&\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x12\0N\0o\0t\0o\0 \0S\0\x61\0n\0s@&\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
QT6CT

# Kvantum configuration for Qt theming
sudo -u lex mkdir -p /home/lex/.config/Kvantum
cat > /home/lex/.config/Kvantum/kvantum.kvconfig << 'KVANTUM'
[General]
theme=Catppuccin-Mocha-Blue
KVANTUM

# Environment variables for proper theming and scaling
cat > /home/lex/.profile << 'PROFILE'
# Display scaling
export GDK_SCALE=1
export GDK_DPI_SCALE=1.5
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_SCALE_FACTOR=1.5
export XCURSOR_SIZE=24

# Wayland
export MOZ_ENABLE_WAYLAND=1
export MOZ_DBUS_REMOTE=1
export QT_QPA_PLATFORM="wayland;xcb"
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
export CLUTTER_BACKEND=wayland

# Theming
export QT_QPA_PLATFORMTHEME=qt5ct
export GTK_THEME=Catppuccin-Mocha-Standard-Blue-Dark
export XCURSOR_THEME=Catppuccin-Mocha-Dark-Cursors

# XDG
export XDG_CURRENT_DESKTOP=niri
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=niri

# Editor
export EDITOR=nvim
export VISUAL=nvim
PROFILE

# Create .zprofile to source .profile
cat > /home/lex/.zprofile << 'ZPROFILE'
# Source profile for environment variables
[[ -f ~/.profile ]] && . ~/.profile
ZPROFILE

# Alacritty configuration with Catppuccin theme
sudo -u lex mkdir -p /home/lex/.config/alacritty
cat > /home/lex/.config/alacritty/alacritty.toml << 'ALACRITTY'
[window]
padding = { x = 10, y = 10 }
opacity = 0.95
decorations = "None"

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
bold_italic = { family = "JetBrainsMono Nerd Font", style = "Bold Italic" }
size = 12.0

[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"
dim_foreground = "#7f849c"
bright_foreground = "#cdd6f4"

[colors.cursor]
text = "#1e1e2e"
cursor = "#f5e0dc"

[colors.vi_mode_cursor]
text = "#1e1e2e"
cursor = "#b4befe"

[colors.search.matches]
foreground = "#1e1e2e"
background = "#a6adc8"

[colors.search.focused_match]
foreground = "#1e1e2e"
background = "#a6e3a1"

[colors.footer_bar]
foreground = "#1e1e2e"
background = "#a6adc8"

[colors.hints.start]
foreground = "#1e1e2e"
background = "#f9e2af"

[colors.hints.end]
foreground = "#1e1e2e"
background = "#a6adc8"

[colors.selection]
text = "#1e1e2e"
background = "#f5e0dc"

[colors.normal]
black = "#45475a"
red = "#f38ba8"
green = "#a6e3a1"
yellow = "#f9e2af"
blue = "#89b4fa"
magenta = "#f5c2e7"
cyan = "#94e2d5"
white = "#bac2de"

[colors.bright]
black = "#585b70"
red = "#f38ba8"
green = "#a6e3a1"
yellow = "#f9e2af"
blue = "#89b4fa"
magenta = "#f5c2e7"
cyan = "#94e2d5"
white = "#a6adc8"

[colors.dim]
black = "#45475a"
red = "#f38ba8"
green = "#a6e3a1"
yellow = "#f9e2af"
blue = "#89b4fa"
magenta = "#f5c2e7"
cyan = "#94e2d5"
white = "#bac2de"
ALACRITTY

# Apply Papirus folder colors
sudo -u lex papirus-folders -C cat-mocha-blue

# Create desktop entry for Niri
cat > /usr/share/wayland-sessions/niri.desktop << 'NIRIDESKTOP'
[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=niri-session
Type=Application
DesktopNames=niri
Keywords=tiling;wayland;compositor;
NIRIDESKTOP

# Touch gestures configuration with libinput-gestures
sudo -u lex mkdir -p /home/lex/.config
cat > /home/lex/.config/libinput-gestures.conf << 'GESTURES'
# Swipe gestures
gesture swipe up 3 fuzzel
gesture swipe down 3 wlogout
gesture swipe left 3 niri msg action focus-workspace-down
gesture swipe right 3 niri msg action focus-workspace-up

# Pinch gestures
gesture pinch in niri msg action zoom-out
gesture pinch out niri msg action zoom-in
GESTURES

# Enable libinput-gestures
sudo -u lex systemctl --user enable libinput-gestures.service

# Fix permissions
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
            PACKAGES="$PACKAGES_PLAYGROUND $PACKAGES_NIRI $PACKAGES_THEME"
            INSTALL_DESKTOP=true
            ;;
        stable)
            PACKAGES="$PACKAGES_STABLE $PACKAGES_NIRI $PACKAGES_THEME"
            INSTALL_DESKTOP=true
            ;;
        minimal)
            PACKAGES="$PACKAGES_MINIMAL"
            INSTALL_DESKTOP=false
            ;;
        gaming)
            PACKAGES="$PACKAGES_GAMING $PACKAGES_NIRI $PACKAGES_THEME"
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
    
    # Configure Niri desktop if needed
    if [[ "$INSTALL_DESKTOP" == "true" ]]; then
        configure_niri_desktop "$profile"
    fi
    
    # Gaming-specific optimizations
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
systemctl --user enable gamemoded.service 2>/dev/null || true
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
- Niri scrollable tiling compositor
- Complete Catppuccin theming (GTK2/3/4, Qt5/6)
- Btrfs with automatic snapshots
- ThinkPad X1 Yoga Gen 7 optimized
- Touch screen and gestures support
- HiDPI console font (Terminus 24pt)
- Display scaling: ${DISPLAY_SCALE}x
- Keyboard layouts: $XKBLAYOUT

Shared Resources:
- /mnt/shared-data - Shared between all Linux
- /mnt/windows1 - Windows installation 1
- /mnt/windows2 - Windows installation 2
- /mnt/data - NTFS data partition

Snapshot Management:
- snapper list
- snapper create --description "Manual snapshot"
- snapper rollback [number]
- Boot into snapshots via GRUB menu

Niri Commands:
- niri msg - Send commands to running compositor
- niri validate - Validate config file
- Super+Shift+/ - Show all keybindings
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