#!/usr/bin/bash
set -euo pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

## ZFS (originally derived from https://github.com/shymega/shyBazzite-zfs-test/blob/main/build_files/build.sh)

RELEASE="$(rpm -E %fedora)"

# as per https://openzfs.github.io/openzfs-docs/Getting%20Started/Fedora/index.html
# "zfs-fuse is unmaintained and should not be used under any circumstance"
rpm -e --nodeps zfs-fuse
dnf install -y https://zfsonlinux.org/fedora/zfs-release-2-8$(rpm --eval "%{dist}").noarch.rpm
dnf install -y kernel-devel-"$(rpm -qa kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
dnf install -y zfs

# Auto-load ZFS module
depmod -a "$(rpm -qa kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" && \
echo "zfs" > /etc/modules-load.d/zfs.conf && \
# we don't want any files on /var
rm -rf /var/lib/pcp
## Just in case, according to https://openzfs.github.io/openzfs-docs/Getting%20Started/Fedora/index.html#installation
echo 'zfs' > /etc/dnf/protected.d/zfs.conf


# Workaround to allow installing nix with composefs
mkdir /nix

# RPM packages list
declare -A RPM_PACKAGES=(
  ["fedora"]="\
    android-tools \
    aria2 \
    bchunk \
    bleachbit \
    fuse-btfs \
    fuse-devel \
    fuse3-devel \
    fzf \
    gnome-disk-utility \
    gparted \
    gwenview \
    hashcat \
    isoimagewriter \
    kcalc \
    kgpg \
    ksystemlog \
    llama-cpp \
    neovim \
    nmap \
    ollama \
    openrgb \
    printer-driver-brlaser \
    qemu-kvm \
    thefuck \
    util-linux \
    virt-manager \
    virt-viewer \
    wireshark \
    yakuake \
    yt-dlp \
    zsh-autosuggestions \
    zsh"

  ["terra"]="\
    coolercontrol \
    ghostty \
    hack-nerd-fonts \
    starship \
    ubuntu-nerd-fonts \
    ubuntumono-nerd-fonts \
    ubuntusans-nerd-fonts"

  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="\
    audacious \
    audacious-plugins-freeworld \
    audacity-freeworld"

  ["fedora-multimedia"]="\
    HandBrake-cli \
    HandBrake-gui \
    haruna \
    mpv \
    vlc-plugin-bittorrent \
    vlc-plugin-ffmpeg \
    vlc-plugin-kde \
    vlc-plugin-pause-click \
    vlc"

  ["docker-ce"]="\
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin"

  ["brave-browser"]="brave-browser"
  ["cloudflare-warp"]="cloudflare-warp"
  ["vscode"]="code"
)

log "Starting Amy OS build process"

log "Installing RPM packages"
mkdir -p /var/opt
for repo in "${!RPM_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${RPM_PACKAGES[$repo]}"
  if [[ $repo == copr:* ]]; then
    # Handle COPR packages
    copr_repo=${repo#copr:}
    dnf5 -y copr enable "$copr_repo"
    dnf5 -y install "${pkg_array[@]}"
    dnf5 -y copr disable "$copr_repo"
  else
    # Handle regular packages
    [[ $repo != "fedora" ]] && enable_opt="--enable-repo=$repo" || enable_opt=""
    cmd=(dnf5 -y install)
    [[ -n "$enable_opt" ]] && cmd+=("$enable_opt")
    cmd+=("${pkg_array[@]}")
    "${cmd[@]}"
  fi
done

log "Enabling system services"
systemctl enable docker.socket libvirtd.service

log "Installing Cursor CLI"
CLI_DIR="/tmp/cursor-cli"
mkdir -p "$CLI_DIR"
aria2c --dir="$CLI_DIR" --out="cursor-cli.tar.gz" --max-tries=3 --connect-timeout=30 "https://api2.cursor.sh/updates/download-latest?os=cli-alpine-x64"
tar -xzf "$CLI_DIR/cursor-cli.tar.gz" -C "$CLI_DIR"
install -m 0755 "$CLI_DIR/cursor" /usr/bin/cursor-cli

log "Adding Amy OS just recipes"
echo "import \"/usr/share/amyos/just/amy.just\"" >>/usr/share/ublue-os/justfile

log "Hide incompatible Bazzite just recipes"
for recipe in "install-coolercontrol" "install-openrgb"; do
  if ! grep -l "^$recipe:" /usr/share/ublue-os/just/*.just | grep -q .; then
    echo "Error: Recipe $recipe not found in any just file"
    exit 1
  fi
  sed -i "s/^$recipe:/_$recipe:/" /usr/share/ublue-os/just/*.just
done

log "Build process completed"
