#!/bin/bash
alias rm=rm
export MAKEFLAGS="-j6"
export LC_ALL="C"
export O_LC=$LC_ALL
export PN="ov"
export DOM="example.com"
export MONTH=$(date +%m)
export YEAR=$(date +%y)
export OVER=$(expr $YEAR - 6) #OdooVersion - computed
[[ $MONTH -lt 11 ]] && export OVER=$(expr $OVER - 1) || export OVER=${OVER}


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

read -p "Enter Odoo version you want to install (default $OVER): " UV #UserVersion
read -p "Enter Project Name ex: Hajjaj (default ${PN}): " UPN #ProjectName
read -p "Enter Your Main Domain ex: Hajjaj.pro (default ${DOM}): " UDOM #ProjectName

[[ -n $UPN ]] && export PN=$(echo $UPN | sed "s, ,,g")
[[ -n $UDOM ]] && export DOM=$UDOM

if [[ x$UV != x ]]; then
    [ $UV -eq 0 ] 2>&1 >/dev/null
    if [ $? -eq 2 ]; then
        die "Input is not a number, exiting ..." 33
        elif [[ $UV -gt $OVER ]]; then
        die "version $UV not released yet, exitting ..." 44
    else
        echo $UV | grep '.0' && export OVER=$(echo $UV | sed "s,\.0,,g") || export OVER=$UV
    fi
fi

export AUSR=${PN}$OVER
which apt &>/dev/null && ( useradd -s /bin/bash -m -G adm,sudo $AUSR || die "Failed creating user $AUSR" )
which dnf &>/dev/null && ( useradd -s /bin/bash -m -G wheel $AUSR || die "Failed creating user $AUSR" )
export BWS=$(eval echo ~$AUSR)

{ # Other exports
    export PORT1=1$(id -u $AUSR) #Port for multi install
    export PORT2=2$(id -u $AUSR) #IM Port for multi install
    
    export aria2c='aria2c -c -x4 -s4'
    export OGH="https://github.com/odoo/odoo"
    export RQF=${ODIR}/odoo_requirements.txt
    export DISTS="Ubuntu: xenial bionic focal, Debian: stretch buster bullseye"
    
    ### Config vars
    export SFX=$OVER
    export VER=${OVER}.0
    export ODIR="$BWS/Odoo"             # Odoo dir name
    export LOGFILE="/$ODIR/Install.log"
    mkdir -p $ODIR
    export ODSVC=odoo-$PN$SFX
    
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
}

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
        #  This should work on ${LGREEN}Ubuntu 18.04+, Debian 9+ & RHEL 8.x .${LBLUE}
        #  You can set odoo version by calling ${NC}$0 \${VER}$LBLUE
        #  for ex. $NC# $0 14.0 ${LBLUE}to install odoo v 14.0
        #-----------------------------------------------------------
        #  Now we will install Odoo v.${LRED} $VER $LBLUE
        #  In$LGREEN $ODIR $LBLUE
        #  On success:
        #  - you can re/start odoo by running systemctl start $ODSVC
        #  - stop odoo by systemctl stop $ODSVC
        #  - Odoo config file $LGREEN $ODIR/Odoo.conf $LBLUE
        #  - Odoo  will be running on$LRED http://localhost:$PORT1 $LBLUE
        ############################################################

        Press Enter to continue or CTRL+C to exit :
    ${NC}" | tee -a $LOGFILE && read
}

cat <<EOF >/tmp/ngxcfg
upstream ${ODSVC} {
        server 127.0.0.1:${PORT1};
}
upstream ${ODSVC}-im {
        server 127.0.0.1:${PORT2};
}

server {
    server_name ${PN}.$DOM;

    add_header Access-Control-Allow-Origin *;

    keepalive_timeout 3010;
    keepalive_requests 1024;
    client_header_timeout 3010;
    client_body_timeout 3010;
    send_timeout 3010;
    proxy_read_timeout 3000;
    proxy_connect_timeout 3000;
    proxy_send_timeout 3000;
    client_max_body_size 200G;

    access_log    /var/log/nginx/${ODSVC}-access.log;
    error_log    /var/log/nginx/${ODSVC}-error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forward-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_x_forwarded_host;
    proxy_set_header X-Forwarded-Proto http;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_redirect off;
    proxy_buffering off;

    location /longpolling {
        proxy_pass    http://${ODSVC}-im;
    }

    location / {
        proxy_pass    http://${ODSVC};
    }

    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering    on;
        expires 864000;
        proxy_pass http://${ODSVC};
    }

    gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/x-javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;

    gzip on;

}
EOF

export REQ="https://raw.githubusercontent.com/odoo/odoo/$VER/requirements.txt"


# create user's bin and add it to $PATH
mkdir -p $BWS/bin
cat $BWS/.bashrc | grep "~/bin\|HOME/bin" &>>$LOGFILE || echo "PATH=~/bin:\$PATH:/snap/bin" >>$BWS/.bashrc

cd $BWS

apt_do(){
    echo "Updating system ... "
    apt-get update &>>$LOGFILE

    echo -n "Installing base tools ..."
    apt-get install -y --no-install-recommends tcsh snapd nginx aria2 git wget curl python3-{dev,pip,venv} &>>$LOGFILE && sayok || die "Deps. install Failed"
    snap install certbot --classic &>/dev/null &

    cd $BWS
    $aria2c -o wkhtml.deb "$WKURL" &>>$LOGFILE #|| die "Download WKHTML2PDF failed" &

    echo -n "Installing Dependencies ... "
    apt-get install -y postgresql sassc node-less npm libxml2-dev libsasl2-dev libldap2-dev \
    libxslt1-dev libjpeg-dev libpq-dev cython3 gcc g++ make automake cmake autoconf \
    build-essential &>>$LOGFILE && sayok || die "can not install deps" 11

    while $(ps aux | grep wkhtml | grep aria2 &>/dev/null); do sleep 5; done
    echo "Installing WKHTML2PDF ... "
    which wkhtmltopdf &>>$LOGFILE ||  apt-get -y install $BWS/wkhtml.deb &>>$LOGFILE
    #which wkhtmltopdf &>>$LOGFILE || die "can not install wkhtml2pdf" 777

    rm /etc/nginx/sites-enabled/default
    cp /tmp/ngxcfg /etc/nginx/sites-available/$ODSVC
    ln -s /etc/nginx/sites-available/$ODSVC /etc/nginx/sites-enabled/
    systemctl restart nginx &>/dev/null
}

pgdg_el8(){
cat /etc/passwd | grep postgres &>/dev/null \
|| (
  dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
  && dnf -qy module disable postgresql \
  && dnf install -y postgresql14-server \
  && /usr/pgsql-14/bin/postgresql-14-setup initdb \
  && systemctl enable postgresql-14 \
  && systemctl start postgresql-14
 )
}

dnf_do(){
    source /etc/os-release
	echo "INSTALLING GIT ...." && dnf -y install git
    echo $ID_LIKE $VERSION| grep centos | grep 8\. &>/dev/null \
        && echo "Configuring Centos" yum install bash-completion telnet dnf-plugins-core && yum config-manager --set-enabled powertools \
        && yum -y update && dnf -y module enable nodejs:16 &&  dnf -y module enable python39 \
        && dnf -y install tcsh python39-{devel,pip,wheel} && dnf remove -y python3

    echo -n "Installing base tools ..."
    dnf install -y epel-release
    dnf install -y nginx aria2 wget curl &>>$LOGFILE && sayok || die "Failed"

    cd $BWS
    $aria2c -o wkhtml.rpm "$WKURL" &>>$LOGFILE || die "Download WKHTML2PDF failed" &

    echo -n "Installing Dependencies ... "
    echo $ID_LIKE $VERSION| grep centos | grep 8\. &>/dev/null && pgdg_el8 || die "Postgres install Fialed" 
    dnf install -y libpq-devel sassc npm libxml2-devel libgsasl-devel openldap-devel \
    libxslt-devel libjpeg-devel gcc gcc-c++ make automake cmake autoconf \
    &>>$LOGFILE && sayok || die "can not install deps" 11

    echo -n "Setting up postgres ..."
    systemctl status --no-pager postgres*  &>>$LOGFILE && sayok || \
    (  /usr/bin/postgresql*setup initdb &>>$LOGFILE &&  systemctl enable --now postgresql &>>$LOGFILE && sayok ) \
    || die "Postgres setup failed"

    while $(ps aux | grep wkhtml | grep aria2 &>/dev/null); do sleep 5; done
    echo "Installing WKHTML2PDF ... "
    which wkhtmltopdf &>>$LOGFILE ||  dnf -y install $BWS/wkhtml.rpm &>>$LOGFILE
    which wkhtmltopdf &>>$LOGFILE || die "can not install wkhtml2pdf" 777

    rm -f /etc/nginx/conf.d/default
    sed -i -e "s,server_name.*,server_name xxx\;,g" /etc/nginx/nginx.conf
    sed -i -e "s,default_server,,g" /etc/nginx/nginx.conf
    cp /tmp/ngxcfg /etc/nginx/conf.d/${ODSVC}.conf

}

which apt-get &>>$LOGFILE && apt_do
which dnf &>>$LOGFILE && dnf_do

echo -n "Creating venv $BWS ... "
which apt &>/dev/null && ( python3 -m venv $BWS || die "can not create VENV in $BWS" )
which dnf &>/dev/null && ( python3.9 -m venv $BWS || die "can not create VENV in $BWS" )

echo "Cloning odoo git $VER ... "
cd $ODIR || die "$ODIR"
[[ -d odoo ]] || git clone -b $VER --single-branch --depth=1 $OGH &>>$LOGFILE \
|| die "can not download odoo sources" 45 &

curl $REQ | grep -v ==\ \'win32 | sed "s,\#.*,,g" | sort | uniq >$RQF || die "can not get $REQ " 22

echo -n "Creating postgres user for $AUSR ..."
su -s /bin/tcsh -l postgres -c "psql -qtAc \"\\du\"" | grep $AUSR &>>$LOGFILE \
&& sayok || (  su -s /bin/tcsh -l postgres -c "createuser -d $AUSR " &>>$LOGFILE && sayok ) || die "Postgres user creation failed"

# install rtlcss requored for RTL support in Odoo
echo -n "Installing rtlcss... "
for pkg in less rtlcss less-plugin-clean-css; do
    which $pkg &>>$LOGFILE && sayok || (  npm install -g $pkg &>>$LOGFILE && sayok )
done

echo "Creating start/stop scripts"
echo "#!/bin/bash
find $ODIR/ -type f -name \"*pyc\" -delete
for prc in \$(ps aux | grep -v grep | grep -i \$(basename $ODIR) | grep python | awk '{print \$2}'); do kill -9 \$prc &>/dev/null; done
cd $ODIR && source $BWS/bin/activate && ./odoo/odoo-bin --without-demo=all -c $ODIR/Odoo.conf \$@
" > $ODIR/.start.sh && chmod +x $ODIR/.start.sh || die "can not create start script"


echo "Creating odoo config file ..."
cat <<EOF >$ODIR/Odoo.conf
[options]
addons_path = $ODIR/odoo/odoo/addons,$ODIR/odoo/addons,$ODIR/my_adds,$ODIR/my_adds/community,$ODIR/my_adds/enterprise
admin_passwd = 123@admin
xmlrpc_port = ${PORT1}
longpolling_port = ${PORT2}
limit_time_cpu = 1800
limit_time_real = 3600
log_level = warn
workers = 4
EOF

mkdir -p $ODIR/my_adds/{enterprise,community}

echo asn1crypto >> $RQF
echo phonenumbers >> $RQF
echo pyaml >> $RQF
echo pylint >> $RQF

# link a folder to avoid an error in pip install lxml
ln -sf /usr/include/libxml2/libxml /usr/include/ &>>$LOGFILE
# fix python-ldap build
ln -s /usr/lib64/libldap.so /usr/lib64/libldap_r.so &>/dev/null

echo "Installing Python libraries:"
source $BWS/bin/activate || die "VENV Failed"
which python3; sleep 3

python3 -m pip install --upgrade pip &>/dev/null

while read line
do
    export LMSG=$(echo "$line" | awk '{print $1}')
    echo -n " - Installing $LMSG : "
    python3 -m pip install "$line" &>>$LOGFILE && sayok || echo Failed\?
    # || ( die "$LMSG library install error" )
    ls &>/dev/null # To avoid asking for passwd again
done < $RQF


export shmmax=$(expr $(free | grep Mem | awk '{print $2}') / 2)000
export shmall=$(expr $shmmax / 4096)

cat /etc/sysctl.conf | grep "kernel.shmmax = $shmmax" &>>$LOGFILE \
|| echo "############ Odoo Postgress #########
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
" |  tee -a /etc/sysctl.conf &>>$LOGFILE;  sysctl -p &>>$LOGFILE

cat <<EOF >/etc/systemd/system/${ODSVC}.service
[Unit]
Description=$ODSVC
After=network.target

[Service]
Restart=always
RestartSec=5
User=$AUSR
Group=$AUSR
ExecStart=$ODIR/.start.sh
ExecReload=/bin/kill -USR1 \$MAINPID
KillMode=mixed
KillSignal=SIGQUIT
TimeoutStopSec=5s

[Install]
WantedBy=multi-user.target
EOF

source $BWS/bin/activate; pip freeze | grep psycopg2 &>/dev/null || \
(echo "Installing psycopg2" && pip3 install psycopg2-binary &>/dev/null)

chown -R $AUSR: ~$BWS &>/dev/null
systemctl daemon-reload && systemctl enable --now $ODSVC && systemctl restart nginx

ps aux | grep git | grep odoo &>>$LOGFILE && echo "Waiting for git clone ..."
while $(ps aux | grep git | grep clone | grep odoo &>>$LOGFILE); do sleep 5; done
which dnf && dnf -y remove python3 &>/dev/null


chown -R $AUSR: $BWS && source $BWS/bin/activate && [[ -d $ODIR ]] && [[ -f $ODIR/odoo/odoo-bin ]] &>>$LOGFILE \
&& echo -e "${LGREEN}
#############################################################
#  Looks like everything went well.
#  You should now:
#  - Have Odoo v$VER In $LRED $ODIR $LGREEN
#  - To re/start odoo run systemctl restart $ODSCV
#  - To re/start odoo run systemctl stop $ODSCV
#  - Odoo config file $ODIR/Odoo.conf
#  - Odoo addons dirs $ODIR/my_adds for project addons
#  - $ODIR/my_adds/community for 3rd party addons
#  - $ODIR/my_adds/enterprise for EE addons
#  - Then access odoo on domain if DNS configured $LRED http://${PN}.${DOM} $LGREEN
#  - or using IP:PORT $LRED http://$(curl http://ifconfig.me):$PORT1 $LGREEN
#############################################################
${LBLUE}***For best results restart this Server now***$LGREEN
Good luck, ;) .
${NC}" || die "Installation Failed" 1010
