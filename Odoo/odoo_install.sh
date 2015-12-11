#!/bin/bash
################################################################################
#
# Script for Installation: Odoo server on "fresh" Ubuntu 14.04 LTS
# Author: Openies Services India
#-------------------------------------------------------------------------------
#  A Simple Script to install Odoo on the Fresh ubuntu 14.04 Server
#-------------------------------------------------------------------------------
#
################################################################################
 
#openerp
OE_USER="odoo"
OE_HOME="/opt/$OE_USER"
OE_HOME_EXT="/opt/$OE_USER"

#default odoo port
OE_PORT="8069"

#change the version to checkout "8.0" branch from github
OE_VERSION="9.0"

#Change the super admin password
OE_SUPERADMIN="odoo_super_admin_password"
OE_CONFIG="$OE_USER-server"

#--------------------------------------------------
# Update & Upgrade Server
#--------------------------------------------------
echo -e "\n Updating & Upgrading Server ----"
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Instaling PostgreSQL Server ----"
sudo apt-get install postgresql -y
	
echo -e "\n---- PostgreSQL $PG_VERSION Settings  ----"
sudo sed -i s/"#listen_addresses = 'localhost'"/"listen_addresses = '*'"/g /etc/postgresql/9.3/main/postgresql.conf

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n---- Installing tool packages ----"
sudo apt-get install wget subversion git python-pip gdebi-core -y
	
echo -e "\n---- Installing required packages ----"
sudo apt-get install python-pip python-dev gdata libevent-dev gcc libxml2-dev libxslt-dev node-less libldap2-dev libssl-dev libsasl2-dev

echo -e "\n---- Installing python Packages from requirements.txt ----"
sudo wget -O /tmp/requirements.txt https://raw.githubusercontent.com/odoo/odoo/9.0/requirements.txt && sudo pip install -r /tmp/requirements.txt

echo -e "\n---- Downloading wkhtmltopdf ----"
if [ "`getconf LONG_BIT`" == "64" ];then
	sudo -O /tmp/odoo_webkit.deb http://download.gna.org/wkhtmltopdf/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
else
	sudo -O /tmp/odoo_webkit.deb http://download.gna.org/wkhtmltopdf/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-i386.deb
fi
echo -e "\n---- Downloading wkhtmltopdf ----"
sudo dpkg -i /tmp/odoo_webkit.deb
sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin

	
echo -e "\n---- Creating System user odoo ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
sudo adduser $OE_USER sudo

echo -e "\n---- Creating Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo git clone https://www.github.com/odoo/odoo --depth 1 --branch $OE_VERSION --single-branch $OE_HOME_EXT/


echo -e "\n---- Creating custom module directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "\n---- Creating server config file ----"
sudo cp $OE_HOME_EXT/debian/openerp-server.conf /etc/$OE_CONFIG.conf
sudo chown $OE_USER:$OE_USER /etc/$OE_CONFIG.conf
sudo chmod 640 /etc/$OE_CONFIG.conf

echo -e "\n---- Creating log file ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER


echo -e "\n---- Change server config file ----"
sudo sed -i s/"db_user = .*"/"db_user = $OE_USER"/g /etc/$OE_CONFIG.conf
sudo sed -i s/"; admin_passwd.*"/"admin_passwd = $OE_SUPERADMIN"/g /etc/$OE_CONFIG.conf
sudo su root -c "echo 'logfile = /var/log/$OE_USER/$OE_CONFIG.log' >> /etc/$OE_CONFIG.conf"
sudo su root -c "echo 'addons_path = $OE_HOME_EXT/addons,$OE_HOME/custom/addons' >> /etc/$OE_CONFIG.conf"
sudo su root -c "echo 'xmlrpc_port = $OE_PORT' >> /etc/$OE_CONFIG.conf"

echo -e "* Creating bash file to start the server with configuration"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/openerp-server --config=/etc/$OE_CONFIG.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh


echo -e "* Createing odoo init file"
cat <<EOF > ~/$OE_CONFIG

#!/bin/bash
### BEGIN INIT INFO
# Provides:          odoo.py
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start odoo daemon at boot time
# Description:       Enable service provided by daemon.
# X-Interactive:     true
### END INIT INFO
## more info: http://wiki.debian.org/LSBInitScripts

. /lib/lsb/init-functions

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
DAEMON=/usr/bin/odoo.py
NAME=odoo
DESC=odoo
CONFIG=/etc/openerp-server.conf
LOGFILE=/var/log/odoo/odoo-server.log
PIDFILE=/var/run/${NAME}.pid
USER=odoo
export LOGNAME=$USER

test -x $DAEMON || exit 0
set -e

function _start() {
    start-stop-daemon --start --quiet --pidfile $PIDFILE --chuid $USER:$USER --background --make-pidfile --exec $DAEMON -- --config $CONFIG --logfile $LOGFILE
}

function _stop() {
    start-stop-daemon --stop --quiet --pidfile $PIDFILE --oknodo --retry 3
    rm -f $PIDFILE
}

function _status() {
    start-stop-daemon --status --quiet --pidfile $PIDFILE
    return $?
}


case "$1" in
        start)
                echo -n "Starting $DESC: "
                _start
                echo "ok"
                ;;
        stop)
                echo -n "Stopping $DESC: "
                _stop
                echo "ok"
                ;;
        restart|force-reload)
                echo -n "Restarting $DESC: "
                _stop
                sleep 1
                _start
                echo "ok"
                ;;
        status)
                echo -n "Status of $DESC: "
                _status && echo "running" || echo "stopped"
                ;;
        *)
                N=/etc/init.d/$NAME
                echo "Usage: $N {start|stop|restart|force-reload|status}" >&2
                exit 1
                ;;
esac

exit 0

EOF


echo -e "* Configuring Odoo init"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG


echo -e "* Adding Odoo Init on Server Startup"
sudo update-rc.d $OE_CONFIG defaults
 
sudo service $OE_CONFIG start
echo "Odoo Installtion Completed! "
echo "you can..."
echo "Check the status of Odoo server with: service $OE_CONFIG status"
echo "Start Odoo server with: service $OE_CONFIG start"
echo "Restart Odoo server with: service $OE_CONFIG restart"
echo "Stop Odoo server with: service $OE_CONFIG stop"
