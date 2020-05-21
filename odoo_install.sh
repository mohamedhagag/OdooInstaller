#!/bin/bash
# you can set odoo version as 1st argument
export VER=13.0		 # set odoo version - should work with any version after 11.0 - tested with 12 & 13
[[ -n $1 ]] && export VER="$1"
### Config vars - you may change these - but defaults are good 
export SFX=$(echo $VER | awk -F\. '{print $1}')	 # Odoo folder suffix version without ".0"
export BWS="$HOME/workspace"		 # Base workspace folder default ~/workspace
export ODIR="$BWS/Odoo_$SFX"		 # Odoo dir name, default ~/workspace/Odoo13

# function to print a mgs, kill the script & exit
die(){
	export MSG=$1; export ERR=$2; 
	echo "Error: $MSG" #error msg
	[[ -n $ERR ]] && exit $ERR || exit 9
}
# check version
echo $VER | grep '.0' || die "Version should have .0 like 12.0 not 12" 9999

##### DO Not change below this line
echo -e "
#############################################################
#  Welcome to Odoo installer script by Mohamed M. Hagag
#  https://linkedin.com/in/mohamedhagag under GPL3 License
#-----------------------------------------------------------
#  Caution: This script For development use only 
#  Not for production use 
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

Press any key to continue or CTRL+C to exit :
" && read

export WKURL="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb"
export OGH="http://github.com/odoo/odoo"



# only work on ubuntu
lsb_release -d | grep -i "ubuntu" &>/dev/null || die "Only Ubuntu systems supported" 999

# create workspace dir
mkdir -p $BWS && cd $BWS || die "Can not create $BWS folder" 888

# create user's bin and add it to $PATH
mkdir -p $HOME/bin 
cat ~/.bashrc | grep "~/bin\|HOME/bin" &>/dev/null || echo "PATH=~/bin:$PATH" >>~/.bashrc

# install some deps
sudo apt update && sudo apt -y dist-upgrade
sudo apt install -y --no-install-recommends aptitude postgresql sassc node-less npm libxml2-dev \
	libsasl2-dev libldap2-dev libxslt1-dev libjpeg8-dev libpq-dev python3-{dev,pip,virtualenv}

# link a folder to avoid an error in pip install lxml
sudo ln -s /usr/include/libxml2/libxml /usr/include/

# check if we have wkhtmltopdf or install it
aptitude search wkhtmlto | grep ^i || (wget $WKURL && sudo apt -y install ./wkhtml*deb ) \
	|| die "can not install wkhtml2pdf" 777

# install compiler & dev tools
sudo apt install -y gcc g++ make automake cmake autoconf build-essential

# apt-file will help you find which non-installed pkg can provide a file 
# sudo apt -y install apt-file && sudo apt-file update

# create postgres user for current $USER
sudo su -l postgres -c "createuser -d $USER"

# install rtlcss requored for RTL support in Odoo
sudo npm install -g rtlcss

# create VirtualEnv and activate it
[[ -d $ODIR ]] || ( virtualenv $ODIR && cd $ODIR && source $ODIR/bin/activate ) \
		|| die "can not create venv" 33

# Ensure that venv is active or activate it or die );
env | grep VIRTUAL || ( cd $ODIR && source $ODIR/bin/activate ) \
	|| die "can not activate venv" 44

# get odoo sources from github
cd $ODIR 
[[ -d odoo ]] || git clone -b $VER --single-branch --depth=1 $OGH \
	|| die "can not download odoo sources" 45

# create re/start script
echo "#!/bin/bash
find $ODIR/ -type f -name \"*pyc\" -delete
for prc in \$(ps aux | grep -v grep | grep -i \$(basename $ODIR) | grep python | awk '{print \$2}'); do kill -9 \$prc &>/dev/null; done
cd $ODIR && source bin/activate && cd odoo && ./odoo-bin -c ../Odoo_$SFX.conf \$@
" > $ODIR/.start.sh \
	&& chmod u+x $ODIR/.start.sh \
	&& cp $ODIR/.start.sh ~/bin/Odoo_Start_$SFX \
	|| die "can not create start script"

# create stop script
head -3 $ODIR/.start.sh > $ODIR/.stop.sh && chmod u+x $ODIR/.stop.sh \
	&& cp $ODIR/.stop.sh ~/bin/Odoo_Stop_$SFX \
	|| die "can not create STOP script"

# create odoo config file
echo "[options]
addons_path = ./odoo/addons,./addons,../my_adds
xmlrpc_port = 80$SFX
longpolling_port = 70$SFX
workers = 2
limit_time_real = 3600
log_file = ../Odoo.log
dev = all
"> $ODIR/Odoo_$SFX.conf && mkdir -p $ODIR/my_adds

# change some python pkg versions
sed -i -e "s,Babel.*,Babel,g" $ODIR/odoo/requirements.txt
sed -i -e "s,html2text.*,html2text,g" $ODIR/odoo/requirements.txt
sed -i -e "s,libsass.*,libsass,g" $ODIR/odoo/requirements.txt
sed -i -e "s,pytz.*,pytz,g" $ODIR/odoo/requirements.txt
sed -i -e "s,psutil.*,psutil,g" $ODIR/odoo/requirements.txt
sed -i -e "s,passlib.*,passlib,g" $ODIR/odoo/requirements.txt
sed -i -e "s,reportlab.*,reportlab,g" $ODIR/odoo/requirements.txt
sed -i -e "s,pillow.*,pillow,g" $ODIR/odoo/requirements.txt
sed -i -e "s,Pillow.*,Pillow,g" $ODIR/odoo/requirements.txt
sed -i -e "s,psycopg2.*,psycopg2-binary,g" $ODIR/odoo/requirements.txt
sed -i -e "s,lxml.*,lxml,g" $ODIR/odoo/requirements.txt
sed -i -e "s,num2.*,num2words,g" $ODIR/odoo/requirements.txt
sed -i -e "s,Werkzeug.*,Werkzeug<1.0.0,g" $ODIR/odoo/requirements.txt

# install python pkgs
cd $ODIR && source bin/activate
while read line; do pip install "$line" ; done < $ODIR/odoo/requirements.txt

# restore original req. file
cd $ODIR/odoo && rm requirements.txt && git checkout requirements.txt

[[ -d $ODIR ]] && [[ -f $ODIR/odoo/odoo-bin ]] && env | grep VIRTUAL \
&& echo -e "
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
" || echo -e "Something went wrong, Try re-running the installation again.
You may delete $ODIR before restarting."

