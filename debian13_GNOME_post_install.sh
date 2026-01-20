#!/bin/bash
# -----------------------------------------------------------------------------
# Debian 13 (Trixie) Post-Install System and Shell Configuration Script
# Author: Gemini
# Date: October 2025
#
# This script performs security hardening, installs required packages (including
# external apps like Chrome), and configures the user's shell
# environment for advanced system administration tasks.
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# --- 1. PRE-CHECKS AND ENVIRONMENT SETUP -------------------------------------

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script with root privileges (e.g., using 'sudo')."
  exit 1
fi

# Determine the primary user's home directory (assuming the user calling sudo)
# This is crucial for modifying the correct .bashrc later.
if [ -n "$SUDO_USER" ]; then
    TARGET_USER="$SUDO_USER"
    USER_HOME=$(eval echo "~$TARGET_USER")
else
    # Fallback if SUDO_USER is not set (e.g., if run directly as root)
    echo "WARNING: SUDO_USER not detected. Assuming home directory is /root."
    TARGET_USER="root"
    USER_HOME="/root"
fi

echo "Configuration target user: $TARGET_USER ($USER_HOME)"

# Function to add external repositories safely
add_external_repo() {
    local repo_name="$1"
    local key_url="$2"
    local repo_url="$3"
    local repo_file="$4"

    echo "--- Installing $repo_name repository ---"
    # Download and add the signing key
    curl -fsSL "$key_url" | gpg --dearmor -o "/usr/share/keyrings/${repo_name}-archive-keyring.gpg"
    # Add the repository to a new sources list file
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/${repo_name}-archive-keyring.gpg] $repo_url" > "/etc/apt/sources.list.d/$repo_file"
}

# --- 2. SYSTEM BASELINE AND APT REPOSITORY CONFIG ----------------------------

echo "--- 2.1 Updating APT sources for non-free firmware ---"
# Add 'non-free-firmware' to the main sources list for hardware compatibility.
sed -i '/main/ s/$/ non-free-firmware/' /etc/apt/sources.list

echo "--- 2.2 Running initial system update ---"
apt update
apt upgrade -y


# --- 3. SECURITY SETUP (Industry Standards) ----------------------------------

echo "--- 3.1 Installing and configuring UFW firewall ---"
apt install ufw fail2ban -y

# Deny all incoming traffic by default, allow all outgoing traffic.
ufw default deny incoming
ufw default allow outgoing

# Allow SSH connections (port 22) - essential for remote administration
ufw allow ssh

# Enable UFW
ufw enable
echo "UFW enabled and configured. Status:"
ufw status verbose

echo "--- 3.2 Configuring and enabling Fail2Ban ---"
# Fail2ban helps protect SSH by banning brute-force attempts.
systemctl enable fail2ban
systemctl start fail2ban
# Note: For production use, a custom jail.local file is recommended.

# --- 4. CORE PACKAGE INSTALLATION --------------------------------------------

echo "--- 4.1 Installing main packages via apt ---"
# Packages for system admin, development, and creative work.
APT_PACKAGES="
    ufw nmap btop curl git python3-venv python3-pip pipx
    mpv vlc gimp inkscape audacity flowblade keepassxc
    firmware-misc-nonfree filezilla hexchat mutt msmtp msmtp-mta
    rsync grsync ansible cloud-utils xorriso cpio wireshark
"

apt install $APT_PACKAGES -y


# --- 4.2 Evolution Removal and Thunderbird Installation ---

echo "--- 4.2 Removing Evolution and installing Thunderbird ---"
# Remove Evolution and associated data/plugins, then install Thunderbird as the preferred client.
# The '|| true' allows the script to continue if Evolution was not installed by default.
apt purge -y evolution evolution-data-server evolution-plugins || true
apt install -y thunderbird
echo "Evolution removed, Thunderbird installed."


# --- 5. EXTERNAL PACKAGE INSTALLATION ----------------------------------------

# 5.1 Google Chrome
add_external_repo \
    "google-chrome" \
    "https://dl.google.com/linux/linux_signing_key.pub" \
    "http://dl.google.com/linux/chrome/deb/ stable main" \
    "google-chrome.list"
apt update
apt install google-chrome-stable -y
echo "Google Chrome installed."


# 5.2 Google Earth Pro
add_external_repo \
    "google-earth" \
    "https://dl.google.com/linux/linux_signing_key.pub" \
    "http://dl.google.com/linux/earth/deb/ stable main" \
    "google-earth.list"
apt update
apt install google-earth-pro-stable -y
echo "Google Earth Pro installed."


# 5.3 VirtualBox (Using Oracle repository for latest version/compatibility with resilient fallback)
echo "--- 5.3 Installing VirtualBox from Oracle repositories (Resilient Install) ---"

# Temporarily disable 'set -e' for this entire section. External package installation,
# especially involving DKMS and apt-cache searching, is prone to non-fatal
# exit codes that must not halt the entire post-install script.
set +e

# We must use the external Oracle repository since the packages were not found in Debian's repos.
add_external_repo \
    "oracle-virtualbox" \
    "https://www.virtualbox.org/download/oracle_vbox_2016.asc" \
    "https://download.virtualbox.org/virtualbox/debian trixie contrib" \
    "oracle-virtualbox.list"

# Update apt source list to include the new Oracle repo
apt update

# Attempt to install the expected package name (7.2) first.
VBOX_PACKAGE="virtualbox-7.2"

echo "Attempting to install VirtualBox package: $VBOX_PACKAGE"

apt install "$VBOX_PACKAGE" -y
INSTALL_STATUS=$?

# If the installation failed (e.g., package name changed again), find and install the newest available.
if [ $INSTALL_STATUS -ne 0 ]; then
    echo "ERROR: Installation of $VBOX_PACKAGE failed. Attempting to find and install the newest 'virtualbox-' package."
    
    # Search for all available virtualbox- packages in the new repo and get the latest version name
    # Suppress errors from apt-cache and pipes using 2>/dev/null
    VBOX_FALLBACK=$(apt-cache search virtualbox- | grep '^virtualbox-' | head -n 1 | awk '{print $1}' 2>/dev/null)
    
    if [ -n "$VBOX_FALLBACK" ]; then
        echo "Found fallback package: $VBOX_FALLBACK. Installing..."
        apt install "$VBOX_FALLBACK" -y
        FALLBACK_STATUS=$?
        
        if [ $FALLBACK_STATUS -ne 0 ]; then
            echo "CRITICAL WARNING: Installation of $VBOX_FALLBACK also failed (Exit code $FALLBACK_STATUS). Manual intervention required."
        else
            echo "VirtualBox ($VBOX_FALLBACK) installed successfully using fallback."
        fi
    else
        echo "CRITICAL WARNING: Could not find any package starting with 'virtualbox-'. Manual intervention required."
    fi
else
    echo "VirtualBox ($VBOX_PACKAGE) installed successfully."
fi

# Re-enable 'set -e' now that the risky external repository installation is complete.
set -e

# Add the primary user to the vboxusers group (requires relogging to take effect)
usermod -aG vboxusers "$TARGET_USER"
echo "$TARGET_USER added to 'vboxusers' group. Please reboot or relog for group changes to take full effect."

echo "Recommendation: A reboot is highly recommended after this script finishes to resolve any kernel module issues."


# 5.4 yt-dlp (Platform-independent zipimport binary)
echo "--- 5.4 Ensuring Debian yt-dlp package is removed and installing newest binary ---"

# Remove the Debian package if it exists to avoid conflicts with the manual install.
apt purge -y yt-dlp || true

YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
YTDLP_BIN="/usr/local/bin/yt-dlp"

curl -L "$YTDLP_URL" -o "$YTDLP_BIN"
chmod +x "$YTDLP_BIN"
echo "yt-dlp binary installed successfully to $YTDLP_BIN. Version check:"
"$YTDLP_BIN" --version


# 5.5 yt-dlp Configuration File Setup
echo "--- 5.5 Creating yt-dlp config file for $TARGET_USER ---"
YTDLP_CONFIG_DIR="$USER_HOME/.config/yt-dlp"
YTDLP_CONFIG_FILE="$YTDLP_CONFIG_DIR/config"

# Create the configuration directory and set ownership
mkdir -p "$YTDLP_CONFIG_DIR"
chown "$TARGET_USER:$TARGET_USER" "$YTDLP_CONFIG_DIR"

# Write the configuration file content as the target user.
# NOTE: The parentheses and pipe symbols in the template are now escaped
# to prevent Bash from interpreting them during the heredoc creation.
sudo -u "$TARGET_USER" bash -c "cat > '$YTDLP_CONFIG_FILE' << 'YTDLP_CONF'
# ------------------
# My yt-dlp Config
# ------------------

# Always prefer MP4 format
-f bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best

# Ultimate organization template
-o \"~/Downloads/YouTube/%(uploader)s/%(playlist_title|'Misc Videos')s/%(upload_date)s - %(title)s [%(id)s].%(ext)s\"
YTDLP_CONF"

echo "yt-dlp configuration file created at $YTDLP_CONFIG_FILE."


# --- 5.6 Create yt-dlp Output Directories ---

echo "--- 5.6 Creating yt-dlp output directories for $TARGET_USER ---"
# Ensure the target download directories exist and are owned by the user.
sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/Downloads/YouTube"
sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/Downloads/Videos"
echo "Directories created: ~/Downloads/YouTube and ~/Downloads/Videos."


# --- 5.7 Wireshark Group Configuration ---

echo "--- 5.7 Adding $TARGET_USER to the 'wireshark' group for non-root captures ---"
# The 'wireshark' package usually creates a user prompt during installation
# to determine if non-root users should be allowed to capture packets.
# This command ensures the target user is added to the group regardless.
usermod -aG wireshark "$TARGET_USER"
echo "$TARGET_USER added to 'wireshark' group. Please reboot or relog for group changes to take full effect."


# --- 6. SHELL CONFIGURATION (.bashrc) ----------------------------------------

echo "--- 6.1 Configuring $TARGET_USER's .bashrc with advanced aliases ---"
BASHRC_FILE="$USER_HOME/.bashrc"

# Check if the file exists and is writable
if [ ! -f "$BASHRC_FILE" ] || [ ! -w "$BASHRC_FILE" ]; then
    echo "WARNING: $BASHRC_FILE not found or not writable. Skipping shell configuration."
else
    # Append aliases and environment settings to .bashrc
    # NOTE: Special characters in the ytdlp-other alias are now escaped to avoid Bash syntax errors.
    cat << EOF >> "$BASHRC_FILE"

# --- Added by Post-Install Script (Advanced Admin Setup) ---

# Better ls aliases
alias ls='ls -F --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Always use better grep
alias grep='grep --color=auto'

# Advanced System Administration Helpers
alias update='sudo apt update && sudo apt upgrade -y'
alias cleanup='sudo apt autoremove -y && sudo apt clean'
alias sshkey='ssh-keygen -t ed25519 -C "\$(whoami)@\$(hostname)"'
alias inv='ansible-inventory -i /etc/ansible/hosts --list --yaml'
alias venv-init='python3 -m venv .venv && source .venv/bin/activate'

# Networking and System Status
alias ports='sudo ss -tuln'
alias top='btop'

# yt-dlp alias for non-YouTube videos using specific organization
# The --no-config flag ensures this alias uses only the path specified here,
# ignoring the default config file in ~/.config/yt-dlp/config
alias ytdlp-other='yt-dlp --no-config -o "~/Downloads/Videos/%(extractor_key)s/%(uploader|Unknown Uploader)s/%(title)s [%(id)s].%(ext)s"'

# Add pipx binaries to PATH for user $TARGET_USER
if command -v pipx &> /dev/null; then
    export PATH="\$PATH:\$HOME/.local/bin"
fi

# Set default editor to Nano if VISUAL is not set (common server task)
if [ -z "\$VISUAL" ] && [ -z "\$EDITOR" ]; then
    export EDITOR=nano
fi

# --- End Post-Install Aliases ---

EOF
    echo ".bashrc configured. Changes will take effect in a new shell session."
fi


# --- 7. FINAL CLEANUP AND INSTRUCTIONS ---------------------------------------

echo "--- 7. Finalizing Installation ---"
apt autoremove -y
apt clean
echo "Installation and configuration script finished successfully."
echo ""
echo "NEXT STEPS:"
echo "1. The VirtualBox and Wireshark group changes may require a reboot to finalize the kernel modules and group membership. Please reboot the system."
echo "2. After relogging, run 'update' (your new alias) to confirm the new repositories work."
echo "3. Remember to configure 'mutt' and 'msmtp' for terminal email usage, and Thunderbird for GUI usage."
echo "4. For advanced Ansible configuration, you may need to set up /etc/ansible/hosts."
echo "5. You can now use 'ytdlp-other' (which ignores the default config) to download videos from sites other than YouTube."
echo ""

# Note: The target user's .bashrc must be sourced manually or a new shell started
# for the aliases to become active immediately.

