# Install dependencies
sudo pacman -S --needed git base-devel nodejs npm squashfs-tools xorriso dosfstools grub mtools arch-install-scripts calamares

# Create directory and download fresh-eggs
mkdir -p /home/tuxos-user/tuxos
cd /home/tuxos-user/tuxos
git clone https://github.com/pieroproietti/fresh-eggs.git
cd fresh-eggs

# Install penguins-eggs using fresh-eggs
chmod +x fresh-eggs.sh
sudo ./fresh-eggs.sh

# Configure Calamares with eggs
sudo eggs calamares --install

# Create your TuxOS ISO with Calamares
sudo eggs produce --max --clone
