#!/usr/bin/env make

# if changed to a new value, /opt/gms will be a symlink to this value 
# (some code below depends on a hard-coded path and uses /opt/gms during installation sadly)
GMS_HOME=/opt/gms

# data which is too big to fit in the git repository is staged here
DATASERVER=ftp://genome.wustl.edu:/pub/software/gms/setup/archive-files
#DATASERVER=blade12-1-1:/gscmnt/sata849/info/gms/setup/archive-files/

# the tool to use for bulk file transfer
FTP:=$(shell (uname | grep Linux) 1>/dev/null && (which ncftpget || sudo apt-get install ncftp) 1>/dev/null && echo "ncftpget" || echo "ftp")
#FTP=scp

# this is empty for ftp/ncftp but is set to "." for scp and rsync
DOWNLOAD_TARGET=
#DOWNLOAD_TARGET=.

#####

# in a non-VM environment the default target "all" will build the entire system
all: stage-files done/hostinit

# in a VM environment, the staging occurs on the host, and the rest on the VM
vm: stage-files done/vminit
	vagrant ssh -c 'cd /opt/gms && make done/hostinit'


#####

stage-files: done/git-checkouts done/unzip-apps done/unzip-apt-mirror-min-ubuntu-12.04 done/unzip-refdata

done/vminit: 
	#
	# intializing vagrant (VirtualBox) VM...
	#
	(which apt-get >/dev/null) && sudo apt-get install -q -y nfs-kernel-server
	which VirtualBox || (echo "install VirtualBox from https://www.virtualbox.org/wiki/Downloads" && false)
	which vagrant || (echo "install vagrant from http://downloads.vagrantup.com/" && false)
	(vagrant box list | grep '^precise64$$' >/dev/null && echo "found vagrant precise64 box") || (echo "installing vagrant precise64 box" && vagrant box add precise64 http://files.vagrantup.com/precise64.box)
	vagrant up || true # ignore errors on the first init
	vagrant ssh -c 'sudo apt-get update; sudo apt-get install -q - --force-yes nfs-client make'
	vagrant reload
	vagrant ssh -c 'cd /opt/gms; make done/home'
	touch $@
	#
	# 'now run "vagrant ssh", then "cd /opt/gms; make done/hostinit"'
	#
	
done/hostinit: done/account stage-files done/home done/rails done/apache done/db-data

#####

# stage-files 

done/git-checkouts:
	# get UR from github
	git submodule update --init sw/ur
	cd sw/ur; git pull origin master
	# get workflow from github
	git submodule update --init sw/workflow
	cd sw/workflow; git checkout gms-host; git pull origin gms-host
	# get rails from github
	git submodule update --init sw/rails
	cd sw/rails; git pull origin master
	# get the gms-core from github
	git submodule update --init sw/genome	
	cd sw/genome; git checkout gms-host; git pull origin gms-host
	touch $@

setup/archive-files/apps.tgz:
	# download apps which are not packaged as .debs
	cd setup/archive-files; $(FTP) $(DATASERVER)/apps.tgz 
	
done/unzip-apps: setup/archive-files/apps.tgz
	# unzip apps which are not packaged as .debs (publicly available from other sources)
	tar -zxvf $< -C sw
	touch $@ 

setup/archive-files/apt-mirror-min-ubuntu-12.04.tgz:
	# download apps which ARE packaged as .debs as a local apt mirror directory
	cd setup/archive-files/; $(FTP) $(DATASERVER)/apt-mirror-min-ubuntu-12.04.tgz 

done/unzip-apt-mirror-min-ubuntu-12.04: setup/archive-files/apt-mirror-min-ubuntu-12.04.tgz
	# unzip the local apt mirror
	tar -zxvf $< -C sw  
	touch $@ 

setup/archive-files/MANIFEST:
	# download apps which are not packaged as .debs
	cd setup/archive-files; $(FTP) $(DATASERVER)/MANIFEST $(DOWNLOAD_TARGET)

done/download-refdata: setup/archive-files/MANIFEST
	# filesystem primer data (reference data)
	cd setup/archive-files/volumes-refdata-tgz; cat ../MANIFEST | grep volumes | perl -ne 'chomp; print "$(FTP) $(DATASERVER)/$$_ $(DOWNLOAD_TARGET)\n"' | sh
	touch $@

done/unzip-refdata: done/download-refdata
	# unzip disk allocations for reference sequences, etc.
	\ls setup/archive-files/volumes-refdata-tgz/*gz | perl -ne 'chomp; print "tar -zxvf $$_ -C fs/\n" if /\S/' | sh
	touch $@	

#####
# hostinit:
# When using a vagrant vm, this must happen on the VM.
# On a standalone machine it can happen along with the "stage-files" targets, though most will occur after those steps run because they depend on them.

done/account:
	sudo groupadd genome || echo ...
	sudo useradd genome -c 'The GMS System User' -g genome -d $(GMS_HOME) || echo ...

done/home: 
	#
	# copying configuration into the current user's home directory
	# re-run "make home" for any new user...
	#
	ln -s $(PWD)/setup/home/.??* ~ 2>/dev/null || true
	touch $@

/opt/gms: 
	#
	# set /opt/gms
	#
	[ -d /opt ] || sudo mkdir /opt
	[ -e /opt/gms ] || sudo ln -s $(PWD) /opt/gms 

done/apt-config: /opt/gms done/unzip-apt-mirror-min-ubuntu-12.04
	# configure apt to use the GMS repository
	sudo dpkg -i sw/apt-mirror-min-ubuntu-12.04/mirror/repo.gsc.wustl.edu/ubuntu/pool/main/g/genome-apt-config/genome-apt-config_1.0.0-2~Ubuntu~precise_all.deb
	touch $@	

done/etc: done/apt-config 
	#
	# copy all data from setup/etc into /etc
	# 
	/bin/ls setup/etc/ | perl -ne 'chomp; $$o = $$_; s|\+|/|g; $$c = "cp setup/etc/$$o /etc/$$_\n"; print STDERR $$c; print STDOUT $$c' | sudo bash
	touch $@

done/pkgs: done/etc
	#
	# update from the local apt mirror directory
	# 
	sudo apt-get update >/dev/null 2>&1 || true  
	#
	# install primary dependency packages 
	#
	sudo apt-get install -q -y --force-yes git-core vim nfs-common perl-doc genome-snapshot-deps `cat setup/packages.lst`
	#
	# install rails dependency packages
	#
	sudo apt-get install -q -y --force-yes git ruby1.9.1 ruby1.9.1-dev rubygems1.9.1 irb1.9.1 ri1.9.1 rdoc1.9.1 build-essential apache2 libopenssl-ruby1.9.1 libssl-dev zlib1g-dev libcurl4-openssl-dev apache2-prefork-dev libapr1-dev libaprutil1-dev postgresql postgresql-contrib libpq-dev libxslt-dev libxml2-dev genome-rails-prod
	touch $@

done/db-init: done/pkgs 
	#
	# setup the database and user "genome"
	# 
	sudo -u postgres /usr/bin/createuser -A -D -R -E genome || echo 
	sudo -u postgres /usr/bin/createdb -T template0 -O genome genome || echo 
	sudo -u postgres /usr/bin/psql postgres -tAc "ALTER USER \"genome\" WITH PASSWORD 'changeme'"
	sudo -u postgres /usr/bin/psql -c "GRANT ALL PRIVILEGES ON database genome TO \"genome\";"
	#
	# configure how posgres takes connections
	#
	echo 'local   all         postgres                          ident' >| /tmp/pg_hba.conf
	echo 'local   all         all                               password' >> /tmp/pg_hba.conf
	echo 'host    all         all         127.0.0.1/32          password' >> /tmp/pg_hba.conf
	sudo mv /tmp/pg_hba.conf /etc/postgresql/9.1/main/pg_hba.conf
	sudo chown postgres  /etc/postgresql/9.1/main/pg_hba.conf
	#
	# restart postgres
	#
	sudo /etc/init.d/postgresql restart
	touch $@

done/rails: done/pkgs
	#
	# install rails 
	#
	sudo gem install bundler --no-ri --no-rdoc --install-dir=/var/lib/gems/1.9.1
	sudo chown www-data:www-data /var/www
	sudo -u www-data rsync -r sw/rails/ /var/www/gms-webviews
	cd /var/www/gms-webviews && sudo bundle install
	[ -e /var/www/gms-webviews/tmp ] || sudo -u www-data mkdir /var/www/gms-webviews/tmp
	sudo -u www-data touch /var/www/gms-webviews/tmp/restart.txt
	touch $@

done/apache: done/pkgs 
	#
	# install apache
	#
	echo '<VirtualHost *:80>' >| /tmp/gms-webviews.conf
	echo 'ServerName localhost' >> /tmp/gms-webviews.conf 
	echo 'ServerAlias some_hostname some_other_hostname' >> /tmp/gms-webviews.conf 
	echo 'DocumentRoot /var/www/gms-webviews/public' >> /tmp/gms-webviews.conf
	echo 'PassengerHighPerformance on' >> /tmp/gms-webviews.conf
	echo '<Directory /var/www/gms-webviews/public>' >> /tmp/gms-webviews.conf
	echo '  AllowOverride all' >> /tmp/gms-webviews.conf
	echo '  Options -MultiViews' >> /tmp/gms-webviews.conf
	echo '</Directory>' >> /tmp/gms-webviews.conf
	echo 'AddOutputFilterByType DEFLATE text/html text/css text/plain text/xml application/json' >> /tmp/gms-webviews.conf
	echo 'AddOutputFilterByType DEFLATE image/jpeg, image/png, image/gif' >> /tmp/gms-webviews.conf
	echo '</VirtualHost>' >> /tmp/gms-webviews.conf
	#
	sudo mv /tmp/gms-webviews.conf /etc/apache2/sites-available/gms-webviews.conf
	#
	( [ -e /etc/apache2/sites-enabled/000-default ] && sudo rm /etc/apache2/sites-enabled/000-default ) || echo
	[ -e /etc/apache2/sites-enabled/gms-webviews.conf ] || sudo ln -s  /etc/apache2/sites-available/gms-webviews.conf  /etc/apache2/sites-enabled/gms-webviews.conf
	#
	sudo service apache2 restart
	touch $@

done/db-schema: done/db-init
	#
	# create a schema in postgres
	#
	sudo -u postgres psql -d genome -f setup/schema.psql	
	touch $@ 

done/db-driver: done/pkgs
	# DBD::Pg as repackaged has deps which do not work with Ubuntu Precise.  This works around it.
	[ `perl -e 'use DBD::Pg; print $$DBD::Pg::VERSION'` = '2.19.3' ] || sudo cpanm DBD::Pg

done/db-data: done/db-schema
	#
	# import initial data into the RDBMS
	#
	. setup/etc/genome.conf; setup/import-db-data.pl setup/dump-db.out
	touch $@	


#
# The remainder of this Makefile is used for maintenance and to stage new GMS data
#

# maintenance

update-repos:
	ls sw/genome | grep . >/dev/null || git submodule update --init sw/genome
	ls sw/workflow | grep .  >/dev/null || git submodule update --init sw/workflow
	ls sw/ur | grep . >/dev/null || git submodule update --init sw/ur
	ls sw/rails | grep . >/dev/null	|| git submodule update --init sw/rails
	cd sw/genome; git pull origin gms-host
	cd sw/ur; git pull origin master
	cd sw/workflow; git pull origin gms-host
	cd sw/rails; git pull origin master
	[ -d /var/www/gms-webviews ] || sudo mkdir /var/www/gms-webviews
	sudo chown -R www-data:www-data /var/www/gms-webviews/
	sudo -u www-data rsync -r sw/rails/ /var/www/gms-webviews
	sudo service apache2 restart

db-drop:
	sudo -u postgres /usr/bin/dropdb genome
	[ -e drop/db-schema ] && rm drop/db-schema || echo
	[ -e drop/db-data ] && rm drop/db-data || echo

db-rebuild:
	sudo -u postgres /usr/bin/dropdb genome || echo
	[ -e drop/db-schema ] && rm drop/db-schema || echo
	[ -e drop/db-data ] && rm drop/db-data || echo
	sudo -u postgres /usr/bin/createdb -T template0 -O genome genome
	sudo -u postgres /usr/bin/psql -c "GRANT ALL PRIVILEGES ON database genome TO \"genome\";"
	sudo -u postgres psql -d genome -f setup/schema.psql	
	touch done/db-schema
	. setup/etc/genome.conf; setup/import-db-data.pl setup/dump-db.out
	touch done/db-data

