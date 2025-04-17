#!/bin/bash
# meshing-around install helper script

# install.sh
cd "$(dirname "$0")"
program_path=$(pwd)
printf "\n########################"
printf "\nMeshing Around Installer\n"
printf "########################\n"
printf "\nThis script will try and install the Meshing Around Bot and its dependencies.\n"
printf "Installer works best in raspian/debian/ubuntu or foxbuntu embedded systems.\n"
printf "If there is a problem, try running the installer again.\n"
printf "\nChecking for dependencies...\n"

# check if we are in /opt/meshing-around
if [ $program_path != "/opt/meshing-around" ]; then
    printf "\nIt is suggested to project path to /opt/meshing-around\n"
    printf "Do you want to move the project to /opt/meshing-around? (y/n)"
    read move
    if [[ $(echo "$move" | grep -i "^y") ]]; then
         mv $program_path /opt/meshing-around
        cd /opt/meshing-around
        printf "\nProject moved to /opt/meshing-around. re-run the installer\n"
        exit 0
    fi
fi

# check write access to program path
if [[ ! -w ${program_path} ]]; then
    printf "\nInstall path not writable, try running the installer with \n"
    exit 1
fi

# if hostname = femtofox, then we are on embedded
if [[ $(hostname) == "femtofox" ]]; then
    printf "\nDetected femtofox embedded system\n"
    embedded="y"
else
    # check if running on embedded
    printf "\nAre You installing into an embedded system like a luckfox or -native? most should say no here (y/n)"
    read embedded
fi

if [[ $(echo "${embedded}" | grep -i "^y") ]]; then
    printf "\nDetected embedded skipping dependency installation\n"
else
    # Check and install dependencies
    if ! command -v python3 &> /dev/null
    then
        printf "python3 not found, trying 'apt-get install python3 python3-pip'\n"
         apt-get install python3 python3-pip
    fi
    if ! command -v pip &> /dev/null
    then
        printf "pip not found, trying 'apt-get install python3-pip'\n"
         apt-get install python3-pip
    fi

    # double check for python3 and pip
    if ! command -v python3 &> /dev/null
    then
        printf "python3 not found, please install python3 with your OS\n"
        exit 1
    fi
    if ! command -v pip &> /dev/null
    then
        printf "pip not found, please install pip with your OS\n"
        exit 1
    fi
    printf "\nDependencies installed\n"
fi

# add user to groups for serial access
printf "\nAdding user to dialout, bluetooth, and tty groups for serial access\n"
 usermod -a -G dialout $USER
 usermod -a -G tty $USER
 usermod -a -G bluetooth $USER

# copy service files
cp etc/pong_bot.tmp etc/pong_bot.service
cp etc/mesh_bot.tmp etc/mesh_bot.service
cp etc/mesh_bot_reporting.tmp etc/mesh_bot_reporting.service
cp etc/mesh_bot_w3.tmp etc/mesh_bot_w3.service

# generate config file, check if it exists
if [[ -f config.ini ]]; then
    printf "\nConfig file already exists, moving to backup config.old\n"
    mv config.ini config.old
fi

cp config.template config.ini
printf "\nConfig files generated!\n"

# update lat,long in config.ini 
latlong=$(curl --silent --max-time 20 https://ipinfo.io/loc || echo "48.50,-123.0")
IFS=',' read -r lat lon <<< "$latlong"
sed -i "s|lat = 48.50|lat = $lat|g" config.ini
sed -i "s|lon = -123.0|lon = $lon|g" config.ini
echo "lat,long updated in config.ini to $latlong"

# check if running on embedded
if [[ $(echo "${embedded}" | grep -i "^y") ]]; then
    printf "\nDetected embedded skipping venv\n"
else
    printf "\nRecomended install is in a python virtual environment, do you want to use venv? (y/n)"
    read venv

    if [[ $(echo "${venv}" | grep -i "^y") ]]; then
        # set virtual environment
        if ! python3 -m venv --help &> /dev/null; then
            printf "Python3/venv error, please install python3-venv with your OS\n"
            exit 1
        else
            echo "The Following could be messy, or take some time on slower devices."
            echo "Creating virtual environment..."
            #check if python3 has venv module
            if [[ -f venv/bin/activate ]]; then
                printf "\nFound virtual environment for python\n"
                python3 -m venv venv
                source venv/bin/activate
            else
                printf "\nVirtual environment not found, trying ` apt-get install python3-venv`\n"
                 apt-get install python3-venv
            fi
            # create virtual environment
            python3 -m venv venv

            # double check for python3-venv
            if [[ -f venv/bin/activate ]]; then
                printf "\nFound virtual environment for python\n"
                source venv/bin/activate
            else
                printf "\nPython3 venv module not found, please install python3-venv with your OS\n"
                exit 1
            fi

            printf "\nVirtual environment created\n"

            # config service files for virtual environment
            replace="s|python3 mesh_bot.py|/usr/bin/bash launch.sh mesh|g"
            sed -i "$replace" etc/mesh_bot.service
            replace="s|python3 pong_bot.py|/usr/bin/bash launch.sh pong|g"
            sed -i "$replace" etc/pong_bot.service

            # install dependencies to venv
            pip install -U -r requirements.txt
        fi
    else
        printf "\nSkipping virtual environment...\n"
        # install dependencies to system
        printf "Are you on Raspberry Pi(debian/ubuntu)?\nshould we add --break-system-packages to the pip install command? (y/n)"
        read rpi
        if [[ $(echo "${rpi}" | grep -i "^y") ]]; then
            pip install -U -r requirements.txt --break-system-packages
        else
            pip install -U -r requirements.txt
        fi
    fi
fi

# if $1 is passed
if [[ $1 == "pong" ]]; then
    bot="pong"
elif [[ $1 == "mesh" ]] || [[ $(echo "${embedded}" | grep -i "^y") ]]; then
    bot="mesh"
else
    printf "\n\n"
    echo "Which bot do you want to install as a service? Pong Mesh or None? (pong/mesh/n)"
    echo "Pong bot is a simple bot for network testing"
    echo "Mesh bot is a more complex bot more suited for meshing around"
    echo "None will skip the service install"
    read bot
fi

# set the correct path in the service file
replace="s|/dir/|$program_path/|g"
sed -i $replace etc/pong_bot.service
sed -i $replace etc/mesh_bot.service
sed -i $replace etc/mesh_bot_reporting.service
sed -i $replace etc/mesh_bot_w3.service
# set the correct user in the service file?

#ask if we should add a user for the bot
if [[ $(echo "${embedded}" | grep -i "^n") ]]; then
    printf "\nDo you want to add a local user (meshbot) no login, for the bot? (y/n)"
    read meshbotservice
fi

if [[ $(echo "${meshbotservice}" | grep -i "^y") ]] || [[ $(echo "${embedded}" | grep -i "^y") ]]; then
     useradd -M meshbot
     usermod -L meshbot
     groupadd meshbot
     usermod -a -G meshbot meshbot
    whoami="meshbot"
    echo "Added user meshbot with no home directory"
else
    whoami=$(whoami)
fi
# set basic permissions for the bot user
 usermod -a -G dialout $whoami
 usermod -a -G tty $whoami
 usermod -a -G bluetooth $whoami
echo "Added user $whoami to dialout, tty, and bluetooth groups"

 chown -R $whoami:$whoami $program_path/logs
 chown -R $whoami:$whoami $program_path/data
echo "Permissions set for meshbot on logs and data directories"

# set the correct user in the service file
replace="s|User=pi|User=$whoami|g"
sed -i $replace etc/pong_bot.service
sed -i $replace etc/mesh_bot.service
sed -i $replace etc/mesh_bot_reporting.service
sed -i $replace etc/mesh_bot_w3.service
replace="s|Group=pi|Group=$whoami|g"
sed -i $replace etc/pong_bot.service
sed -i $replace etc/mesh_bot.service
sed -i $replace etc/mesh_bot_reporting.service
sed -i $replace etc/mesh_bot_w3.service
printf "\n service files updated\n"

if [[ $(echo "${bot}" | grep -i "^p") ]]; then
    # install service for pong bot
     cp etc/pong_bot.service /etc/systemd/system/
     systemctl enable pong_bot.service
     systemctl daemon-reload
    echo "to start pong bot service: systemctl start pong_bot"
    service="pong_bot"
fi

if [[ $(echo "${bot}" | grep -i "^m") ]]; then
    # install service for mesh bot
     cp etc/mesh_bot.service /etc/systemd/system/
     systemctl enable mesh_bot.service
     systemctl daemon-reload
    echo "to start mesh bot service: systemctl start mesh_bot"
    service="mesh_bot"
fi

# check if running on embedded for final steps
if [[ $(echo "${embedded}" | grep -i "^n") ]]; then
    # ask if emoji font should be installed for linux
    printf "\nDo you want to install the emoji font for debian/ubuntu linux? (y/n)"
    read emoji
    if [[ $(echo "${emoji}" | grep -i "^y") ]]; then
         apt-get install -y fonts-noto-color-emoji
        echo "Emoji font installed!, reboot to load the font"
    fi

    printf "\nOptionally if you want to install the multi gig LLM Ollama compnents we will execute the following commands\n"
    printf "\ncurl -fsSL https://ollama.com/install.sh | sh\n"
    printf "ollama pull gemma2:2b\n"
    printf "Total download is multi GB, recomend pi5/8GB or better for this\n"
    # ask if the user wants to install the LLM Ollama components
    printf "\nDo you want to install the LLM Ollama components? (y/n)"
    read ollama
    if [[ $(echo "${ollama}" | grep -i "^y") ]]; then
        curl -fsSL https://ollama.com/install.sh | sh

        # ask if want to install gemma2:2b
        printf "\n Ollama install done now we can install the Gemma2:2b components\n"
        echo "Do you want to install the Gemma2:2b components? (y/n)"
        read gemma
        if [[ $(echo "${gemma}" | grep -i "^y") ]]; then
            ollama pull gemma2:2b
        fi
    fi

    # document the service install
    printf "To install the %s service and keep notes, reference following commands:\n\n" "$service" > install_notes.txt
    printf " cp %s/etc/%s.service /etc/systemd/system/etc/%s.service\n" "$program_path" "$service" "$service" >> install_notes.txt
    printf " systemctl daemon-reload\n" >> install_notes.txt
    printf " systemctl enable %s.service\n" "$service" >> install_notes.txt
    printf " systemctl start %s.service\n" "$service" >> install_notes.txt
    printf " systemctl status %s.service\n" "$service" >> install_notes.txt
    printf " systemctl restart %s.service\n\n" "$service" >> install_notes.txt
    printf "To see logs and stop the service:\n" >> install_notes.txt
    printf " journalctl -u %s.service\n" "$service" >> install_notes.txt
    printf " systemctl stop %s.service\n" "$service" >> install_notes.txt
    printf " systemctl disable %s.service\n" "$service" >> install_notes.txt
    
    if [[ $(echo "${venv}" | grep -i "^y") ]]; then
        printf "\nFor running on venv, virtual launch bot with './launch.sh mesh' in path $program_path\n" >> install_notes.txt
    fi

    read -p "Press enter to complete the installation, these commands saved to install_notes.txt"

    printf "\nGood time to reboot? (y/n)"
    read reboot
    if [[ $(echo "${reboot}" | grep -i "^y") ]]; then
         reboot
    fi
else
    # we are on embedded
    # replace "type = serial" with "type = tcp" in config.ini
    replace="s|type = serial|type = tcp|g"
    sed -i "$replace" config.ini
    # replace "# hostname = meshtastic.local" with "hostname = localhost" in config.ini
    replace="s|# hostname = meshtastic.local|hostname = localhost|g"
    sed -i "$replace" config.ini
    printf "\nConfig file updated for embedded\n"
    # add service dependency for meshtasticd into service file
    #replace="s|After=network.target|After=network.target meshtasticd.service|g"

    # Set up the meshing around service
     cp /opt/meshing-around/etc/$service.service /etc/systemd/system/$service.service
     systemctl daemon-reload
     systemctl enable $service.service
     systemctl start $service.service
    printf "Reference following commands:\n\n" "$service" > install_notes.txt
    printf " systemctl status %s.service\n" "$service" >> install_notes.txt
    printf " systemctl start %s.service\n" "$service" >> install_notes.txt
    printf " systemctl restart %s.service\n\n" "$service" >> install_notes.txt
    printf "To see logs and stop the service:\n" >> install_notes.txt
    printf " journalctl -u %s.service\n" "$service" >> install_notes.txt
    printf " systemctl stop %s.service\n" "$service" >> install_notes.txt
    printf " systemctl disable %s.service\n" "$service" >> install_notes.txt
fi

printf "\nInstallation complete!\n"

exit 0

# to uninstall the product run the following commands as needed

#  systemctl stop mesh_bot
#  systemctl disable mesh_bot
#  systemctl stop pong_bot
#  systemctl disable pong_bot
#  systemctl stop mesh_bot_reporting
#  systemctl disable mesh_bot_reporting
#  rm /etc/systemd/system/mesh_bot.service
#  rm /etc/systemd/system/mesh_bot_reporting.service
#  rm /etc/systemd/system/mesh_bot_w3.service
#  rm /etc/systemd/system/pong_bot.service
#  systemctl daemon-reload
#  systemctl reset-failed

#  gpasswd -d meshbot dialout
#  gpasswd -d meshbot tty
#  gpasswd -d meshbot bluetooth
#  groupdel meshbot
#  userdel meshbot

#  rm -rf /opt/meshing-around


# after install shenannigans
# add 'bee = True' to config.ini General section. You will likley want to clean the txt up a bit
# wget https://courses.cs.washington.edu/courses/cse163/20wi/files/lectures/L04/bee-movie.txt -O bee.txt
