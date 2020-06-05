#!/bin/bash
# you can set odoo version as 1st argument
export VER=13.0		 # set odoo version - should work with any version after 11.0 - tested with 12 & 13
[[ -n $1 ]] && export VER="$1"
### Config vars - you may change these - but defaults are good 
export SFX=$(echo $VER | awk -F\. '{print $1}')	 # Odoo folder suffix version without ".0"
[[ $SFX = 'master' ]] && export SFX=99
export BWS="$HOME/workspace"		 # Base workspace folder default ~/workspace
export ODIR="$BWS/Odoo_$SFX"		 # Odoo dir name, default ~/workspace/Odoo13

##################### Do Not make changes below this line #####################
echo $VER | grep "master\|.0" || die "Version should have .0 like 12.0 not 12 or master" 9999 # Check version arg
{ #exports
	export aria2c='aria2c -c -x4 -s4'
	export OGH="https://github.com/odoo/odoo"
	export REQ="https://raw.githubusercontent.com/odoo/odoo/master/requirements.txt"
	export RQF=$(mktemp)
	export DISTS="Ubuntu: xenial bionic focal, Debian: stretch buster"

	which apt &>/dev/null && export DIST=$(lsb_release -c | awk '{print $3}')
	echo $DISTS | grep -i $DIST &>/dev/null || export DIST=bionic
	which apt &>/dev/null && export WKURL="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.${DIST}_amd64.deb"
	which dnf &>/dev/null && export WKURL="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox-0.12.5-1.centos8.x86_64.rpm"
}

{ #Colors - ref: https://stackoverflow.com/a/5947802
	export RED='\033[0;31m'
	export GREEN='\033[0;32m'
	export BLUE='\033[0;34m'
	export LRED='\033[1;31m'
	export LGREEN='\033[1;32m'
	export LBLUE='\033[1;34m'
	export NC='\033[0m' # No Color
}

die(){ # Function to print an error and kill the script
	export MSG=$1; export ERR=$2; 
	echo -e "${LRED}Error: $MSG ${NC}" #error msg
	echo -e "${LRED}
	Something went wrong ...
	Plz check the previous messages for errors
	and try re-running the installation again.
	You may delete $ODIR before restarting.
	${NC}"
	[[ -n $ERR ]] && exit $ERR || exit 9
}

sayok(){ 
	echo -e "${LGREEN} OK ${NC}" 
}

{ # Intro
	echo -e "${LBLUE}
	#############################################################
	#  Welcome to Odoo installer script by 
	#  ${LGREEN}Mohamed M. Hagag https://linkedin.com/in/mohamedhagag${LBLUE}
	#  released under GPL3 License
	#-----------------------------------------------------------
	#  ${LRED}Caution: This script For development use only
	#         And should not used for production use.${LBLUE}
	#  This should work on ${LGREEN}Ubuntu 18.04+, Debian 9+ & Fedora 30+.${LBLUE}
	#  You can set odoo version by calling ${NC}$0 \${VER}$LBLUE
	#  for ex. $NC# $0 14.0 ${LBLUE}to install odoo v 14.0
	#-----------------------------------------------------------
	#  Now we will install Odoo v.${LRED} $VER $LBLUE
	#  In$LGREEN $BWS/Odoo_$SFX $LBLUE
	#  On success:
	#  - you can re/start odoo by running Odoo_Start_$SFX
	#  - stop odoo by running Odoo_Stop_$SFX
	#  - Odoo config file $LGREEN $ODIR/Odoo_$SFX.conf $LBLUE
	#  - Odoo  will be running on$LRED http://localhost:80$SFX $LBLUE
	#  - VSCode will be installed and configured for Odoo Dev
	############################################################

	Press Enter to continue or CTRL+C to exit :
	${NC}" && read && sudo ls >/dev/null
}

# create workspace dir
mkdir -p $BWS && cd $BWS || die "Can not create $BWS folder" 888

# create user's bin and add it to $PATH
mkdir -p $HOME/bin 
cat ~/.bashrc | grep "~/bin\|HOME/bin" &>/dev/null || echo "PATH=~/bin:\$PATH" >>~/.bashrc

echo "Updating system ... "
which apt &>/dev/null && sudo apt update &>/dev/null 
# sudo apt -y dist-upgrade &>/dev/null && sayok

echo -n "Installing base tools ..."
which apt &>/dev/null && ( sudo apt install -y --no-install-recommends snapd aria2 wget curl python3-{dev,pip,virtualenv} &>/dev/null && sayok || die "Failed" )
which apt &>/dev/null && sudo apt -y install python3-virtualenvwrapper &>/dev/null
# Fedora/CentOS
which dnf &>/dev/null && ( sudo dnf install -y aria2 wget curl python3-{devel,pip,virtualenvwrapper} snapd &>/dev/null && sayok || die "Failed" )

echo -n "Creating venv $ODIR ... "
[[ -d $ODIR ]] || ( python3 -m virtualenv -p /usr/bin/python3 $ODIR &>/dev/null && cd $ODIR && source $ODIR/bin/activate ) \
		&& sayok || die "can not create venv" 33

cd $BWS
which apt &>/dev/null && $aria2c -o wkhtml.deb "$WKURL" &>/dev/null &
which dnf &>/dev/null && $aria2c -o wkhtml.rpm "$WKURL" &>/dev/null &
#$aria2c -o vscode.deb "$CODE" &>/dev/null &

echo "Cloning odoo git $VER ... "
cd $ODIR || die "$ODIR"
[[ -d odoo ]] || git clone -b $VER --single-branch --depth=1 $OGH &>/dev/null \
	|| die "can not download odoo sources" 45 &

echo -n "Installing Dependencies ... "
which apt &>/dev/null && ( sudo apt install -y snap postgresql sassc node-less npm libxml2-dev libsasl2-dev libldap2-dev \
 libxslt1-dev libjpeg-dev libpq-dev cython3 python3-{dev,pip,virtualenv} gcc g++ make automake cmake autoconf \
 build-essential &>/dev/null && sayok || die "can not install deps" 11 )

# Fedora/CentOS
which dnf &>/dev/null && ( sudo dnf install -y snapd postgresql{,-server} sassc nodejs-less npm libxml2-devel libgsasl-devel openldap-devel \
 libxslt-devel libjpeg-turbo-devel libpq-devel python3-{devel,pip,virtualenv,Cython} gcc g++ make automake cmake autoconf \
  &>/dev/null && sayok || die "can not install deps" 11 )

which dnf &>/dev/null && sudo ln -sf /var/lib/snapd/snap / &>/dev/null && export PATH=$PATH:/var/lib/snapd/snap/bin

which dnf &>/dev/null && echo -n "Setting up postgres ..."
which dnf &>/dev/null && ( sudo ls /var/lib/pgsql/initdb_postgresql.log &>/dev/null && sayok || \
    ( sudo /usr/bin/postgresql-setup --initdb &>/dev/null && sudo systemctl enable --now postgresql &>/dev/null && sayok ) \
     || die "Postgres setup failed" )

curl $REQ > $RQF 2>/dev/null || die "can not get $REQ " 22

echo -n "Creating postgres user for $USER ..."
sudo su -l postgres -c "psql -qtAc \"\\du\"" | grep $USER &>/dev/null \
&& sayok || ( sudo su -l postgres -c "createuser -d $USER &>/dev/null" && sayok )

# install rtlcss requored for RTL support in Odoo
echo -n "Installing rtlcss... "
which rtlcss &>/dev/null && sayok \
|| ( sudo npm install -g rtlcss &>/dev/null && sayok )


echo "Creating start/stop scripts"
echo "#!/bin/bash
find $ODIR/ -type f -name \"*pyc\" -delete
for prc in \$(ps aux | grep -v grep | grep -i \$(basename $ODIR) | grep python | awk '{print \$2}'); do kill -9 \$prc &>/dev/null; done
cd $ODIR && source bin/activate && ./odoo/odoo-bin -c ./Odoo_$SFX.conf \$@
" > $ODIR/.start.sh \
	&& chmod u+x $ODIR/.start.sh \
	&& cp $ODIR/.start.sh ~/bin/Odoo_Start_$SFX \
	|| die "can not create start script"

head -3 $ODIR/.start.sh > $ODIR/.stop.sh && chmod u+x $ODIR/.stop.sh \
	&& cp $ODIR/.stop.sh ~/bin/Odoo_Stop_$SFX \
	|| die "can not create STOP script"

echo "Creating odoo config file ..."
echo "[options]
addons_path = ./odoo/odoo/addons,./odoo/addons,./my_adds
xmlrpc_port = 80$SFX
longpolling_port = 70$SFX
limit_time_cpu = 1800
limit_time_real = 3600
log_file = ../Odoo.log
workers = 2
dev = all
"> $ODIR/Odoo_$SFX.conf && mkdir -p $ODIR/my_adds

# change some python pkg versions
sed -i -e "s,psycopg2.*,psycopg2,g" $RQF
sed -i -e "s,num2words.*,num2words,g" $RQF
sed -i -e "s,Werkzeug.*,Werkzeug<1.0.0,g" $RQF
#sed -i -e "s,Babel.*,Babel,g" $RQF
#sed -i -e "s,html2text.*,html2text,g" $RQF
#sed -i -e "s,pytz.*,pytz,g" $RQF
#sed -i -e "s,psutil.*,psutil,g" $RQF
#sed -i -e "s,passlib.*,passlib,g" $RQF
#sed -i -e "s,libsass.*,libsass,g" $RQF
#sed -i -e "s,pillow.*,pillow,g" $RQF
#sed -i -e "s,Pillow.*,Pillow,g" $RQF
#sed -i -e "s,lxml.*,lxml,g" $RQF
#sed -i -e "s,reportlab.*,reportlab,g" $RQF
echo phonenumbers >> $RQF
echo pyaml >> $RQF
echo pylint >> $RQF

# link a folder to avoid an error in pip install lxml
sudo ln -sf /usr/include/libxml2/libxml /usr/include/ &>/dev/null

echo "Installing Python libraries:"
cd $ODIR && source ./bin/activate

while read line 
	do 
		export LMSG=$(echo "$line" | awk '{print $1}')
		echo -n " - Installing $LMSG : "
		pip install "$line" &>/dev/null && sayok \
		|| ( die "$LMSG library install error" )
		sudo ls &>/dev/null # To avoid asking for passwd again
    done < $RQF

echo -n "Installing WKHTML2PDF ... "
while $(ps aux | grep wkhtml | grep aria2 &>/dev/null); do sleep 5; done
which wkhtmltopdf &>/dev/null && sayok \
  || ( which apt &>/dev/null && sudo apt -y install $BWS/wkhtml.deb &>/dev/null ) \
  || ( which dnf &>/dev/null && sudo dnf install -y $BWS/wkhtml.rpm &>/dev/null ) \
  && sayok || die "can not install wkhtml2pdf" 777 

echo "Installing & Creating VSCode workspace ... "
sudo systemctl enable --now snapd &>/dev/null
which code &>/dev/null \
	|| ( which snap &>/dev/null && ( \
                sudo snap install --classic code &>/dev/null || sudo snap install --classic code &>/dev/null \
                ) || die "Can not install VSCode" )

mkdir -p $ODIR/.vscode

echo '{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: Current File",
            "type": "python",
            "cwd": "${workspaceFolder}",
            "request": "launch",
            "program": "./odoo/odoo-bin",
            "args": ["-c","./Odoo_*.conf"],
            "env": {"GEVENT_SUPPORT":"True"},
            "console": "integratedTerminal"
        }
    ]
}' >$ODIR/.vscode/launch.json

echo '{
    "python.pythonPath": "bin/python"
}'>$ODIR/.vscode/settings.json

echo '{
	"python.envFile": ${workspaceFolder}/.env,
	"folders": [
		{
			"path": ".."
		}
	]
}'>$ODIR/.vscode/Odoo_${SFX}.code-workspace

echo "PYTHONPATH=$ODIR/odoo" >$ODIR/.env

psql -l | grep zt &>/dev/null || ( createdb ztdb1 &>/dev/null && createdb ztdb2 &>/dev/null)

export shmmax=$(expr $(free | grep Mem | awk '{print $2}') / 2)000
export shmall=$(expr $shmmax / 4096)

cat /etc/sysctl.conf | grep "kernel.shmmax = $shmmax" &>/dev/null \
|| echo "############ Odoo, Postgress & VSCode #########
fs.inotify.max_user_watches = 524288
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = $shmall
kernel.shmmax = $shmmax
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048586
" | sudo tee -a /etc/sysctl.conf &>/dev/null; sudo sysctl -p &>/dev/null

ps aux | grep git | grep odoo &>/dev/null && echo "Waiting for git clone ..."
while $(ps aux | grep git | grep odoo &>/dev/null); do sleep 5; done

export vscext="Atishay-Jain.All-Autocomplete
jigar-patel.odoosnippets
coenraads.bracket-pair-colorizer
DotJoshJohnson.xml
formulahendry.auto-close-tag
formulahendry.auto-rename-tag
GrapeCity.gc-excelviewer
janisdd.vscode-edit-csv
magicstack.MagicPython
mechatroner.rainbow-csv
dbaeumer.vscode-eslint
ms-python.python
ms-vscode.atom-keybindings
vscode-icons-team.vscode-icons
Zignd.html-css-class-completion
"
echo "Setting some vscode extensions"
for ext in $vscext; do code --list-extensions | grep $ext &>/dev/null || code --install-extension $ext &>/dev/null ; done
which code &>/dev/null && code $ODIR/.vscode/Odoo_${SFX}.code-workspace &>/dev/null &

[[ -d $ODIR ]] && [[ -f $ODIR/odoo/odoo-bin ]] && env | grep VIRTUAL &>/dev/null \
&& echo -e "${LGREEN}
#############################################################
#  Looks like everything went well.
#  You should now:
#  - Have Odoo v$VER In $LRED $BWS/Odoo_$SFX $LGREEN
#  - you can re/start odoo by running Odoo_Start_$SFX
#  - stop odoo by running Odoo_Stop_$SFX
#  - Odoo config file $ODIR/Odoo_$SFX.conf
#  - VSCode should be installed & configured for Odoo Devs
#  - Then access odoo on$LRED http://localhost:80$SFX $LGREEN
#############################################################

Good luck, ;) .
${NC}" || die "Installation Failed" 1010
