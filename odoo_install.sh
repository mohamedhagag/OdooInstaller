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

#Colors - ref: https://stackoverflow.com/a/5947802
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export LRED='\033[1;31m'
export LGREEN='\033[1;32m'
export LBLUE='\033[1;34m'
export NC='\033[0m' # No Color

# function to print a mgs, kill the script & exit
die(){
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
sayfail(){ 
	echo -e "${LRED} Failed ${NC}" 
}

# check version
echo $VER | grep "master\|.0" || die "Version should have .0 like 12.0 not 12 or master" 9999

echo -e "${LBLUE}
#############################################################
#  Welcome to Odoo installer script by ${LGREEN}Mohamed M. Hagag
#  https://linkedin.com/in/mohamedhagag ${LBLUE}under GPL3 License
#-----------------------------------------------------------
#  Caution: This script For development use only 
#  with ubuntu 19.10+ , Not for production use 
#  You can set odoo version by calling $0 Version
#  Like $0 14.0 to install odoo 14.0
#  It will install Odoo v$VER
#  In $BWS/Odoo_$SFX
#  On success:
#  - you can re/start odoo by running Odoo_Start_$SFX
#  - stop odoo by running Odoo_Stop_$SFX
#  - Odoo config file $ODIR/Odoo_$SFX.conf
#  - Odoo  will be running on http://localhost:80$SFX
############################################################

Press Enter to continue or CTRL+C to exit :
${NC}" && read && sudo ls >/dev/null

# only work on ubuntu
lsb_release -d | grep -i "ubuntu" &>/dev/null || die "Only Ubuntu systems supported" 999

export WKURL="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb"
export OGH="https://github.com/odoo/odoo"
export REQ="https://raw.githubusercontent.com/odoo/odoo/master/requirements.txt"
export RQF=`mktemp`
export CODE="https://go.microsoft.com/fwlink/?LinkID=760868"

# create workspace dir
mkdir -p $BWS && cd $BWS || die "Can not create $BWS folder" 888

# create user's bin and add it to $PATH
mkdir -p $HOME/bin 
cat ~/.bashrc | grep "~/bin\|HOME/bin" &>/dev/null || echo "PATH=~/bin:$PATH" >>~/.bashrc

# echo -n "Updating system ... "
# sudo apt update &>/dev/null && sudo apt -y dist-upgrade &>/dev/null && sayok

echo -n "Installing Dependencies ... "
sudo apt install -y --no-install-recommends wget aptitude postgresql sassc node-less npm libxml2-dev curl libsasl2-dev \
 libldap2-dev libxslt1-dev libjpeg8-dev libpq-dev python3-{dev,pip,virtualenv} gcc g++ make automake cmake autoconf \
 build-essential &>/dev/null && sayok || die "can not install deps" 11 

curl $REQ > $RQF 2>/dev/null || die "can not get $REQ " 22

echo -n "Installing WKHTML2PDF ... "
which wkhtml2pdf &>/dev/null \
  || ( ( ls ./wkhtml*deb &>/dev/null || wget $WKURL &>/dev/null ) && sudo apt -y install ./wkhtml*deb &>/dev/null ) \
	&& sayok || die "can not install wkhtml2pdf" 777 

# link a folder to avoid an error in pip install lxml
sudo ln -s /usr/include/libxml2/libxml /usr/include/ &>/dev/null

echo -n "Creating postgres user for current $USER ..."
sudo su -l postgres -c "psql -qtAc \"\\du\"" | grep $USER &>/dev/null \
&& sayok || ( sudo su -l postgres -c "createuser -d $USER &>/dev/null" && sayok )

# install rtlcss requored for RTL support in Odoo
echo -n "Installing rtlcss... "
which rtlcss &>/dev/null && sayok \
|| ( sudo npm install -g rtlcss &>/dev/null && sayok )

# create VirtualEnv and activate it
echo -n "Creating venv $ODIR ... "
[[ -d $ODIR ]] || ( virtualenv $ODIR &>/dev/null && cd $ODIR && source $ODIR/bin/activate ) \
		&& sayok || die "can not create venv" 33

# get odoo sources from github
cd $ODIR 
echo "Cloning odoo git $VER ... "
[[ -d odoo ]] || git clone -b $VER --single-branch --depth=1 $OGH &>/dev/null \
	|| die "can not download odoo sources" 45 &

echo "Installing & Creating VSCode workspace ... "
rm -f /tmp/code.deb &>/dev/null
which code &>/dev/null \
	|| ( wget -O /tmp/code.deb "$CODE" &>/dev/null && apt -y install /tmp/code.deb &>/dev/null) &

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
workers = 2
limit_time_real = 3600
log_file = ../Odoo.log
dev = all
"> $ODIR/Odoo_$SFX.conf && mkdir -p $ODIR/my_adds

# change some python pkg versions
sed -i -e "s,psycopg2.*,psycopg2,g" $RQF
sed -i -e "s,num2words.*,num2words,g" $RQF
sed -i -e "s,Werkzeug.*,Werkzeug<1.0.0,g" $RQF
echo phonenumbers >> $RQF
echo pyaml >> $RQF
#sed -i -e "s,pytz.*,pytz,g" $RQF
#sed -i -e "s,psutil.*,psutil,g" $RQF
#sed -i -e "s,passlib.*,passlib,g" $RQF
#sed -i -e "s,reportlab.*,reportlab,g" $RQF
#sed -i -e "s,lxml.*,lxml,g" $RQF
#sed -i -e "s,Babel.*,Babel,g" $RQF
#sed -i -e "s,html2text.*,html2text,g" $RQF
#sed -i -e "s,libsass.*,libsass,g" $RQF
#sed -i -e "s,pillow.*,pillow,g" $RQF
#sed -i -e "s,Pillow.*,Pillow,g" $RQF

echo "Installing Python libraries:"
cd $ODIR && source ./bin/activate
while read line 
	do 
		export LMSG=$(echo "$line" | awk '{print $1}')
		echo -n " - Installing $LMSG : "
		pip install "$line" &>/dev/null && sayok \
		|| ( sayfail && die "$LMSG library install error" )
done < $RQF

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
	"folders": [
		{
			"path": ".."
		}
	]
}'>$ODIR/.vscode/Odoo_${SFX}.code-workspace
createdb zt${SFX}d1 &>/dev/null
createdb zt${SFX}d2 &>/dev/null

while $(ps aux | grep git | grep -v grep | grep $OGH &>/dev/null); do sleep 5; done
while $(ps aux | grep wget | grep code | grep -v grep &>/dev/null); do sleep 5; done
which code &>/dev/null && code $ODIR/.vscode/Odoo_${SFX}.code-workspace &

[[ -d $ODIR ]] && [[ -f $ODIR/odoo/odoo-bin ]] && env | grep VIRTUAL &>/dev/null \
&& echo -e "${LGREEN}
#############################################################
#  Looks like everything went well.
#  You should now:
#  - Have Odoo v$VER In $BWS/Odoo_$SFX
#  - you can re/start odoo by running Odoo_Start_$SFX
#  - stop odoo by running Odoo_Stop_$SFX
#  - Odoo config file $ODIR/Odoo_$SFX.conf
#  - You can now access odoo on http://localhost:80$SFX
#############################################################

Good luck, ;) .
${NC}" || die "Installation Failed" 1010
