#!/bin/bash
# export PATH=$PATH:/snap/bin
export O_LC=$LC_ALL
export LC_ALL="C"
export BWS="$HOME/workspace"		 # Base workspace folder default ~/workspace

export MONTH=$(date +%m)
export YEAR=$(date +%y)
export OVER=$(expr $YEAR - 6) #OdooVersion - computed
[[ $MONTH -lt 11 ]] && export OVER=$(expr $OVER - 1) || export OVER=${OVER}

read -p "Enter Odoo version you want to install (default $OVER),enter master for next version: " UV #UserVersion

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

# check UV is correct including .0 
if [[ x$UV != x ]]; then
	if echo $UV | grep -i master; then
		export OVER=master
	else
		[ $UV -eq 0 ] 2>&1 >/dev/null
		if [ $? -eq 2 ]; then
			die "Input is not a number, exiting ..." 33
		elif (( $(echo "$UV > $OVER" | bc -l ) )); then
			die "version $UV not released yet, exitting ..." 44
		else
			export OVER=$UV
		fi
	fi
fi

[[ $OVER == "master" ]] && export SFX=99 || export SFX=$OVER
[[ $OVER == "master" ]] && export VER=master || export VER=${OVER}.0

### Config vars - you may change these - but defaults are good 
[[ $SFX = 'master' ]] && export SFX=99
export ODIR="$BWS/Odoo_$SFX"		 # Odoo dir name, default ~/workspace/Odoo13
mkdir -p $ODIR
read -p "Press Enter to ENABLE VSCode IDE installation for Odoo Development (Recommended) or Any letter to disable it: " IVSC
[[ x$IVSC == x ]] && export IVSC=0 || export IVSC=1


{ # Other exports
	export LOGFILE="$HOME/OdooInstaller.log"
	export aria2c='aria2c -c -x4 -s4'
	export OGH="https://github.com/odoo/odoo"
	export RQF=${ODIR}/odoo_requirements.txt
	export DISTS="Ubuntu: xenial bionic focal, Debian: stretch buster"

	# clean
	rm -f $RQF $LOGFILE

	# apt based exports
	which apt-get &>/dev/null && export DIST=$(lsb_release -c | awk '{print $2}') \
	&& echo $DISTS | grep -i $DIST &>>$LOGFILE || export DIST=bionic
	which apt-get &>/dev/null && export VSURL="https://go.microsoft.com/fwlink/?LinkID=760868" \
	&& export WKURL="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.${DIST}_amd64.deb"

	# rpm based exports
	which dnf &>>$LOGFILE && export VSURL="https://go.microsoft.com/fwlink/?LinkID=760867" \
	&& export WKURL="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox-0.12.5-1.centos8.x86_64.rpm"

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


sayok(){ 
	echo -e "${LGREEN} OK ${NC}" 
}

echo $OVER | grep master &>/dev/null || echo $VER | grep ".0" || die "Version should have .0 like 12.0 not 12 or master" 9999 # Check version arg

{ # Intro
	touch $LOGFILE
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
	${NC}" | tee -a $LOGFILE && read && sudo ls &>/dev/null
}
[[ $OVER == "master" ]] && export REQ="https://raw.githubusercontent.com/odoo/odoo/master/requirements.txt" \
	|| export REQ="https://raw.githubusercontent.com/odoo/odoo/$VER/requirements.txt"

while :; do sleep 10; sudo ls &>/dev/null; done & # to avoid asking for passwd again

# create workspace dir
mkdir -p $BWS && cd $BWS || die "Can not create $BWS folder" 888

# create user's bin and add it to $PATH
mkdir -p $HOME/bin 
cat ~/.bashrc | grep "~/bin\|HOME/bin" &>>$LOGFILE || echo "PATH=~/bin:\$PATH:/snap/bin" >>~/.bashrc

cd $BWS

inst_vse(){
	echo "Installing VSCode extensions ... "
	which code &>/dev/null && for ext in $vscext; do code --list-extensions | grep $ext || code --install-extension $ext ; done
}

apt_do(){

	echo "Updating system ... "
	sudo apt-get update &>>$LOGFILE 

	echo -n "Installing base tools ..."
	sudo apt-get install -y --no-install-recommends aria2 wget curl python3-{dev,pip,virtualenv} &>>$LOGFILE && sayok || die "Deps. install Failed"
	sudo apt-get -y install python3-virtualenvwrapper &>>$LOGFILE

	cd $BWS
	[[ $IVSC ]] && $aria2c -o vscode.deb "$VSURL" &>>$LOGFILE || die "Download VSCode failed" &
	$aria2c -o wkhtml.deb "$WKURL" &>>$LOGFILE || die "Download WKHTML2PDF failed" &

	echo -n "Installing Dependencies ... "
	sudo apt-get install -y postgresql sassc node-less npm libxml2-dev libsasl2-dev libldap2-dev \
	libxslt1-dev libjpeg-dev libpq-dev cython3 gcc g++ make automake cmake autoconf \
	build-essential &>>$LOGFILE && sayok || die "can not install deps" 11 

	while $(ps aux | grep wkhtml | grep aria2 &>/dev/null); do sleep 5; done
	echo "Installing WKHTML2PDF ... "
	which wkhtmltopdf &>>$LOGFILE || sudo apt-get -y install $BWS/wkhtml.deb &>>$LOGFILE
	which wkhtmltopdf &>>$LOGFILE || die "can not install wkhtml2pdf" 777

	while $(ps aux | grep code | grep aria2 &>/dev/null); do sleep 5; done
	[[ $IVSC ]] && echo -n "Installing VSCode:" && ( which code &>/dev/null || sudo apt-get -y install ./vscode.deb &>>$LOGFILE && sayok || die "Can not install VSCode" )

}

dnf_do(){

	echo -n "Installing base tools ..."
	sudo dnf install -y aria2 wget curl python3-{devel,pip,virtualenvwrapper} &>>$LOGFILE && sayok || die "Failed"

	cd $BWS
	$aria2c -o vscode.rpm "$VSURL" &>>$LOGFILE || die "Download VSCode failed" &
	$aria2c -o wkhtml.rpm "$WKURL" &>>$LOGFILE || die "Download WKHTML2PDF failed" &

	echo -n "Installing Dependencies ... "
	sudo dnf install -y postgresql{,-server} libpq-devel sassc nodejs-less npm libxml2-devel libgsasl-devel openldap-devel \
	libxslt-devel libjpeg-devel libpq-devel gcc g++ make automake cmake autoconf \
	&>>$LOGFILE && sayok || die "can not install deps" 11

	echo -n "Setting up postgres ..."
	sudo ls /var/lib/pgsql/initdb_postgresql.log &>>$LOGFILE && sayok || \
    ( sudo /usr/bin/postgresql-setup --initdb &>>$LOGFILE && sudo systemctl enable --now postgresql &>>$LOGFILE && sayok ) \
    || die "Postgres setup failed"

	while $(ps aux | grep wkhtml | grep aria2 &>/dev/null); do sleep 5; done
	echo "Installing WKHTML2PDF ... "
	which wkhtmltopdf &>>$LOGFILE || sudo dnf -y install $BWS/wkhtml.rpm &>>$LOGFILE
	which wkhtmltopdf &>>$LOGFILE || die "can not install wkhtml2pdf" 777 

	while $(ps aux | grep code | grep aria2 &>/dev/null); do sleep 5; done
	[[ $IVSC ]] && echo -n "Installing VSCode:" && ( which code &>/dev/null || sudo dnf -y install ./vscode.rpm &>>$LOGFILE && sayok || die "Can not install VSCode" )

}

which apt-get &>>$LOGFILE && apt_do
which dnf &>>$LOGFILE && dnf_do

echo -n "Creating venv $ODIR ... "
[[ -d $ODIR ]] && cd $ODIR \
	|| ( python3 -m virtualenv -p /usr/bin/python3 $ODIR &>>$LOGFILE && cd $ODIR && source $ODIR/bin/activate ) \
		&& sayok || die "can not create venv" 33
[[ -d ./bin ]] || python3 -m venv .


echo "Cloning odoo git $VER ... "
cd $ODIR || die "$ODIR"
[[ -d odoo ]] || git clone -b $VER --single-branch --depth=1 $OGH &>>$LOGFILE \
	|| die "can not download odoo sources" 45 &

curl $REQ | grep -v ==\ \'win32 | sed "s,\#.*,,g" | sort | uniq >$RQF || die "can not get $REQ " 22

echo -n "Creating postgres user for $USER ..."
sudo su -l postgres -c "psql -qtAc \"\\du\"" | grep $USER &>>$LOGFILE \
&& sayok || ( sudo su -l postgres -c "createuser -d $USER " &>>$LOGFILE && sayok ) || die "Postgres user creation failed"

# install rtlcss requored for RTL support in Odoo
echo -n "Installing rtlcss... "
which rtlcss &>>$LOGFILE && sayok \
|| ( sudo npm install -g rtlcss &>>$LOGFILE && sayok )

echo "Creating start/stop scripts"
echo "#!/bin/bash
find $ODIR/ -type f -name \"*pyc\" -delete
for prc in \$(ps aux | grep -v grep | grep -i \$(basename $ODIR) | grep python | awk '{print \$2}'); do kill -9 \$prc &>/dev/null; done
cd $ODIR && source bin/activate && ./odoo/odoo-bin -c ./Odoo.conf \$@
" > $ODIR/.start.sh \
	&& chmod u+x $ODIR/.start.sh \
	&& cp $ODIR/.start.sh ~/bin/Odoo_Start_$SFX \
	|| die "can not create start script"

head -3 $ODIR/.start.sh > $ODIR/.stop.sh && chmod u+x $ODIR/.stop.sh \
	&& cp $ODIR/.stop.sh ~/bin/Odoo_Stop_$SFX \
	|| die "can not create STOP script"

echo "Creating odoo config file ..."
echo "[options]
addons_path = ./odoo/odoo/addons,./odoo/addons,./my_adds,./my_adds/enterprise,./my_adds/community
admin_passwd = admin
xmlrpc_port = 80$SFX
longpolling_port = 70$SFX
limit_time_cpu = 1800
limit_time_real = 3600
log_level = warn
#workers = 2
"> $ODIR/Odoo.conf && mkdir -p $ODIR/my_adds

# sed -i -e "s,psycopg2.*,psycopg2-binary,g" $RQF
echo phonenumbers >> $RQF
echo pyaml >> $RQF
echo pylint >> $RQF
echo psycopg2-binary >> $RQF

# link a folder to avoid an error in pip install lxml
sudo ln -sf /usr/include/libxml2/libxml /usr/include/ &>>$LOGFILE
# fix python-ldap build
sudo ln -s /usr/lib64/libldap.so /usr/lib64/libldap_r.so &>/dev/null

echo "Installing Python libraries:"
cd $ODIR && source ./bin/activate
which python3; sleep 3

python3 -m pip install --upgrade pip &>/dev/null

while read line 
	do 
		export LMSG=$(echo "$line" | awk '{print $1}')
		echo -n " - Installing $LMSG : "
		python3 -m pip install "$line" &>>$LOGFILE && sayok || echo Failed\? 
		# || ( die "$LMSG library install error" )
		sudo ls &>/dev/null # To avoid asking for passwd again
    done < $RQF


vscup(){

	mkdir -p $ODIR/.vscode

	echo '{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: Odoo Run",
            "type": "python",
            "cwd": "${workspaceFolder}",
            "request": "launch",
            "program": "${cwd}/odoo/odoo-bin",
            "args": ["-c","${cwd}/Odoo.conf"],
            "env": {"GEVENT_SUPPORT":"True"},
            "console": "integratedTerminal"
        }
    ]
	}' >$ODIR/.vscode/launch.json

	echo '{
			"python.defaultInterpreterPath": "${workspaceFolder}/bin/python"
	}'>$ODIR/.vscode/settings.json

	echo '{
		"folders": [
			{
				"path": ".."
			}
		]
	}'>$ODIR/.vscode/Odoo_${SFX}.code-workspace

}

[[ $IVSC ]] && vscup

export shmmax=$(expr $(free | grep Mem | awk '{print $2}') / 2)000
export shmall=$(expr $shmmax / 4096)

cat /etc/sysctl.conf | grep "kernel.shmmax = $shmmax" &>>$LOGFILE \
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
" | sudo tee -a /etc/sysctl.conf &>>$LOGFILE; sudo sysctl -p &>>$LOGFILE

while $(ps aux | grep code | grep aria2 &>/dev/null); do sleep 5; done
[[ $IVSC ]] && inst_vse &>>$LOGFILE

ps aux | grep git | grep odoo &>>$LOGFILE && echo "Waiting for git clone ..."
while $(ps aux | grep git | grep odoo &>>$LOGFILE); do sleep 5; done

[[ $IVSC ]] && code $ODIR/.vscode/Odoo_${SFX}.code-workspace

[[ -d $ODIR ]] && [[ -f $ODIR/odoo/odoo-bin ]] && env | grep VIRTUAL &>>$LOGFILE \
&& echo -e "${LGREEN}
#############################################################
#  Looks like everything went well.
#  You should now:
#  - Have Odoo v$VER In $LRED $BWS/Odoo_$SFX $LGREEN
#  - you can re/start odoo by running Odoo_Start_$SFX
#  - stop odoo by running Odoo_Stop_$SFX
#  - Odoo config file $ODIR/Odoo.conf
#  - If You enabled VSCode should be installed & configured 
#  - Then access odoo on$LRED http://localhost:80$SFX $LGREEN
#############################################################
${LBLUE}***For best results restart this PC now***$LGREEN
Good luck, ;) .
${NC}" || die "Installation Failed" 1010
