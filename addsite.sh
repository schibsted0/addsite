#!/bin/bash


# define configuration file
configfile="addsite.ini"

# define new variables
source $configfile

#Define default options
verbose=0
dryrun=0
dev=0
user=""
fqdnDomain=""

usage()
{
cat << EOF

########################################################
########                                      ##########
########     Addsite script - Bash style      ##########
########          V1.0.1 - Ezp-hotel          ##########
########                                      ##########
########################################################


Usage: $0 options -s <sitename>

OPTIONS:
   -h      Show this message
   -s      Sitename (Must be 10 characters)
   -d      Dryrun
   -v      Verbose mode
EOF
}

while getopts "hs:dv" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         s)
             site=$OPTARG
             ;;
         d)
             dryrun=1
             ;;
         v)
             verbose=1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z $site ]]
then
     usage
     exit 1
fi
##################
#Setting variables
fqdn=$site.$domain

###################
# checking sitename

if [ -d "$homeSites/$fqdn" ]; then
	echo "Sorry, site already exist"
	exit 101;
elif grep -v '^[-0-9a-zA-Z]*$' <<< "$site" ; then
	echo "Sitename must be alphanumerical"
	exit 102
elif [ "${#site}" != "10" ]; then
	echo "Sitename must have ten characters"
	exit 103
fi

##################
# Define functions

function ifverbose() {
	if [ "$verbose" == "1" ]; then
	       echo $1
	fi
}
function ifnotdryrun() {
	if [ "$dryrun" != "1" ]; then
		$1
	fi
        if [ "$verbose" == "1" ]; then
               echo "$1"
        fi
}
function randompass() {
        MATRIX="HpZldxsG47f0W9gNa!LRTQjhUwnvPtD5eAzr6k@EyumB3@!KcbOCVSFJoYi2q@MIX8!1"
        PASS=""
        n=1
        i=1
        [ -z "$1" ] && length=10 || length=$1
        [ -z "$2" ] && num=1 || num=$2
        while [ ${i} -le $num ]; do
                while [ ${n} -le $length ]; do
                        PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
                        n=$(($n + 1))
                done
                echo $PASS
                n=1
                PASS=""
                i=$(($i + 1))
        done
}

######################
# creating directories
ifverbose "creating directories"
ifnotdryrun "mkdir $logSites/$fqdn"
ifnotdryrun "mkdir $homeSites/$fqdn"
ifnotdryrun "mkdir $homeSites/$fqdn/tmp"
ifnotdryrun "mkdir $homeSites/$fqdn/www"
ifverbose "--------------------------"

# creating mysql database
password=`randompass`
ifverbose "creating mysql database"
if [ "$dryrun" != "1" ]; then
        mysql --host=$mysqlhost --user=$mysqluser --password=$mysqlpass -e "CREATE DATABASE $site"
        ifverbose "mysql --host=$mysqlhost --user=$mysqluser --password=$mysqlpass -e 'CREATE DATABASE $site;'"
        mysql --host=$mysqlhost --user=$mysqluser --password=$mysqlpass -e "GRANT ALL PRIVILEGES ON $site.* TO '$site'@'%' IDENTIFIED BY '$password';"
        ifverbose "mysql --host=$mysqlhost --user=$mysqluser --password=$mysqlpass -e 'GRANT ALL PRIVILEGES ON $site.* TO '$site'@'%' IDENTIFIED BY '$password';'"
        mysqladmin --host=$mysqlhost --user=$mysqluser --password=$mysqlpass reload
        ifverbose "mysqladmin --host=$mysqlhost --user=$mysqluser --password=$mysqlpass reload"
fi
ifverbose "--------------------------"

# creating vhost file 
ifverbose "Creating vhost file"
ifnotdryrun "touch $vhosts/$fqdn.conf"

if [ "$dryrun" != "1" ]; then
cat <<EOF >> $vhosts/$fqdn.conf
<VirtualHost $ip:80>
ServerName $fqdn

CustomLog "|/usr/sbin/rotatelogs $logSites/$fqdn/www 3600" combined
ErrorLog $logSites/$fqdn/error_log

DocumentRoot "$homeSites/$fqdn/www"

<Directory $homeSites/$fqdn/www>
	Options FollowSymLinks
	AllowOverride None
	Order allow,deny
	Allow from all
</Directory>

<Location />
	php_admin_value upload_tmp_dir $homeSites/$fqdn/tmp
	php_admin_value open_basedir $homeSites/$fqdn:/proc:/usr/bin/convert
	php_admin_value session.save_path $homeSites/$fqdn/tmp
</Location>

# Rewrites for eZ Publish
        RewriteEngine On

        RewriteRule content/treemenu/?\$ /index_treemenu.php [L]
        Rewriterule ^/var/storage/.* - [L]
        Rewriterule ^/var/[^/]+/storage/.* - [L]
        RewriteRule ^/var/cache/texttoimage/.* - [L]
        RewriteRule ^/var/[^/]+/cache/texttoimage/.* - [L]
        RewriteRule ^/var/[^/]+/cache/public/.* - [L]
        Rewriterule ^/design/[^/]+/(stylesheets|images|javascript)/.* - [L]
        Rewriterule ^/share/icons/.* - [L]
        Rewriterule ^/extension/[^/]+/design/[^/]+/(stylesheets|images|javascript|javascripts|flash|lib?)/.* - [L]
        Rewriterule ^/packages/styles/.+/(stylesheets|images|javascript)/[^/]+/.* - [L]
        RewriteRule ^/packages/styles/.+/thumbnail/.* - [L]
        RewriteRule ^/favicon\.ico - [L]
        RewriteRule ^/robots\.txt - [L]
        RewriteRule ^/phpinfo.php - [L]
        # Uncomment the following lines when using popup style debug.
        # RewriteRule ^/var/cache/debug\.html.* - [L]
        # RewriteRule ^/var/[^/]+/cache/debug\.html.* - [L]

        RewriteCond \%{REQUEST_URI} !^/(awstats|phpmyadmin|webmail|error)/.*\$
        RewriteCond \%{REQUEST_URI} !^/(awstats|phpmyadmin|webmail|error).*\$

        RewriteRule .* /index.php

</VirtualHost>
EOF
fi
ifverbose "--------------------------"

# extracting ez files
ifverbose "Extracting Ez Publish files"

if [ -d "$eztmppath/$ezunpacked" ];then
	ifnotdryrun "rm -rf $eztmppath/$ezunpacked"
fi

ifnotdryrun "tar -zxf $ezfile --directory=$eztmppath"
ifnotdryrun "cp -r $eztmppath/$ezunpacked/* $homeSites/$fqdn/www/"
ifverbose "--------------------------"

# creating kickstart configuration file 
ifverbose "Creating kickstart configuration file"
ifnotdryrun "touch $homeSites/$fqdn/www/kickstart.ini"

if [ "$dryrun" != "1" ]; then
cat <<EOF >> $homeSites/$fqdn/www/kickstart.ini
[email_settings]
Continue=true
Type=mta

[database_choice]
Continue=true
Type=mysqli

[database_init]
Continue=true
Server=$mysqlhost
Database=$site
User=$site
Password=$password

[language_options]
Continue=false
Primary=eng-GB
EnableUnicode=true

[site_types]
Continue=true
Site_package=ezwebin_site

[site_access]
Continue=true
Access=url

[site_details]
Continue=true
Access=site
AdminAccess=siteadmin
Database=$site

[site_admin]
Continue=true
FirstName=Admin
LastName=Administrator
Email=nospam\@ez.no
Password=$password

[security]
Continue=true

[registration]
Continue=true
Send=true
EOF
fi
ifverbose "--------------------------"

#Setting up crontab
ifverbose "Setting up crontab"

if [ "$dryrun" != "1" ]; then
hour=$((RANDOM%24))
hour2=$((RANDOM%24))
min=$((RANDOM%60))
min2=$((RANDOM%60))
min3=$((RANDOM%15+15))

cat <<EOF >> $cronTabs/$wwwuser
#Main 
$min $hour * * * cd '$homeSites/$fqdn/www' && $phpcli runcronjobs.php -q 2>&1

#Infrequent
$min2 $hour2 * * * cd '$homeSites/$fqdn/www' && $phpcli runcronjobs.php infrequent -q 2>&1

#Frequent
$min3 * * * * cd '$homeSites/$fqdn/www' && $phpcli runcronjobs.php frequent -q 2>&1

EOF
fi
ifverbose "--------------------------"

# Setting up permissions
ifverbose "Setting up permissions"
ifnotdryrun "chown -R $siteowner.$siteowner $homeSites/$fqdn/*"
ifnotdryrun "chown -R $wwwuser.$siteowner $homeSites/$fqdn/www/var $homeSites/$fqdn/www/design $homeSites/$fqdn/www/extension $homeSites/$fqdn/www/settings"
ifnotdryrun "chmod o+rx $homeSites/$fqdn/www"
ifnotdryrun "chmod -R 775 $homeSites/$fqdn/*"
ifverbose "--------------------------"

# Reloading apache settings
ifverbose "Reloading Apache"
ifnotdryrun "/etc/init.d/httpd graceful"
ifverbose "--------------------------"

# Information about the account
ifverbose "Information about the account"

cat <<EOF 
Site-Summary
-------------
IP/port:$ip:80

Site URL: http://$fqdn

phpmyadmin/mysql: http://$fqdn/phpmyadmin
user: $site
pass: $password
EOF
