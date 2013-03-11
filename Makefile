#!/usr/bin/env make

# if changed to a new value, /opt/gms will be a symlink to this value 
# (some code below depends on a hard-coded path and uses /opt/gms during installation sadly)
GMS_HOME=/opt/gms

# data which is too big to fit in the git repository is staged here
DATASERVER=ftp://genome.wustl.edu/pub/software/gms
#DATASERVER=blade12-1-1:/gscmnt/sata102/info/ftp-staging/pub/software/gms

# the tool to use for bulk file transfer
FTP:=$(shell (uname | grep Linux) 1>/dev/null && (which ncftpget || sudo apt-get install ncftp) 1>/dev/null && echo "ncftpget" || echo "ftp")
#FTP=scp

# this is empty for ftp/ncftp but is set to "." for scp and rsync
DOWNLOAD_TARGET=
#DOWNLOAD_TARGET=.

IP:=$(shell ifconfig | grep 'inet addr' | perl -ne '/inet addr:(\S+)/ && print $$1,"\n"' | grep -v 127.0.0.1)
HOSTNAME:=$(shell hostname)

#####

# in a non-VM environment the default target "all" will build the entire system
all: stage-files done/hostinit

# in a VM environment, the staging occurs on the host, and the rest on the VM
vm: stage-files done/vminit
	vagrant ssh -c 'cd /opt/gms && make done/hostinit'


#####

stage-files: update-20130310 done/git-checkouts done/unzip-apps done/unzip-java done/unzip-apt-mirror-min-ubuntu-12.04 done/unzip-refdata done/openlava-download

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
	vagrant ssh -c 'cd /opt/gms && make done/home && make done/account && make done/group'
	touch $@
	#
	# 'now run "vagrant ssh", then "cd /opt/gms; make done/hostinit"'
	#
	
done/hostinit: done/account done/group stage-files done/home done/rails done/apache done/db-data done/openlava-install

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
	# 
	git submodule update --init sw/genome	
	cd sw/genome; git checkout gms-host; git pull origin gms-host
	touch $@

done/openlava-download:
	# get openlava OSS LSF
	git submodule update --init sw/openlava
	cd sw/openlava; git checkout 2.0-release; git pull origin 2.0-release 
	touch $@ 

done/hosts:
	echo "$(IP) GMS_HOST" | setup/bin/findreplace-gms | sudo bash -c 'cat - >>/etc/hosts'
	touch $@ 

setup/archive-files/apps.tgz:
	# download apps which are not packaged as .debs
	cd setup/archive-files; $(FTP) $(DATASERVER)/apps.tgz 
	
setup/archive-files/apps-2013-03-10.tgz:
	# download apps which are not packaged as .debs
	cd setup/archive-files; $(FTP) $(DATASERVER)/apps-2013-03-10.tgz 

setup/archive-files/java.tgz:
	# download java which are not packaged as .debs
	cd setup/archive-files; $(FTP) $(DATASERVER)/java.tgz 

done/unzip-apps: setup/archive-files/apps.tgz
	# unzip apps which are not packaged as .debs (publicly available from other sources)
	tar -zxvf $< -C sw
	touch $@ 

done/unzip-apps-2013-03-10: done/unzip-apps setup/archive-files/apps-2013-03-10.tgz
	# unzip apps which are not packaged as .debs (publicly available from other sources)
	tar -zxvf $< -C sw
	cd apps; ln -s ../apps-2013-03-10/* .
	touch $@ 

done/unzip-java: setup/archive-files/java.tgz
	# unzip java classes which are not packaged as .debs 
	tar -zxvf $< -C sw
	touch $@ 

setup/archive-files/apt-mirror-min-ubuntu-12.04.tgz:
	# download apps which ARE packaged as .debs as a local apt mirror directory
	cd setup/archive-files/; $(FTP) $(DATASERVER)/apt-mirror-min-ubuntu-12.04.tgz 

done/unzip-apt-mirror-min-ubuntu-12.04: setup/archive-files/apt-mirror-min-ubuntu-12.04.tgz
	# unzip the local apt mirror
	tar -zxvf $< -C sw  
	touch $@ 

setup/archive-files/volumes-refdata-tgz/%.tgz:
	# ftp down refdata: $@
	cd setup/archive-files/volumes-refdata-tgz; $(FTP) $(DATASERVER)/volumes-refdata-tgz/`basename $@` $(DOWNLOAD_TARGET)

done/download-refdata: setup/archive-files/volumes-refdata-tgz/ams1102+info+feature_list+-1305149794-1102-10002.tgz setup/archive-files/volumes-refdata-tgz/ams1102+info+feature_list+linus129.gsc.wustl.edu-19229-1293604984-1293605049-3550-10002.tgz setup/archive-files/volumes-refdata-tgz/ams1102+info+model_data+2771411739.tgz setup/archive-files/volumes-refdata-tgz/ams1102+info+model_data+2772828715.tgz setup/archive-files/volumes-refdata-tgz/ams1102+info+model_data+2869585698.tgz setup/archive-files/volumes-refdata-tgz/ams1102+info+model_data+2874849802.tgz setup/archive-files/volumes-refdata-tgz/ams1127+info+build_merged_alignments+detect-variants--blade14-4-11.gsc.wustl.edu-tmooney-9412-11760428.tgz setup/archive-files/volumes-refdata-tgz/gc4096+info+model_data+2857786885.tgz setup/archive-files/volumes-refdata-tgz/gc4096+info+model_data+2868377411.tgz 	setup/archive-files/volumes-refdata-tgz/gc8001+info+build_merged_alignments+detect-variants--blade14-4-11.gsc.wustl.edu-tmooney-9412-117603728.tgz 

done/unzip-%: setup/archive-files/volumes-refdata-tgz/%
	# unzip refdata: $<
	tar -zxvf $< -C fs/
	touch $@

done/unzip-refdata: done/download-refdata done/unzip-ams1102+info+feature_list+-1305149794-1102-10002.tgz done/unzip-ams1102+info+feature_list+linus129.gsc.wustl.edu-19229-1293604984-1293605049-3550-10002.tgz done/unzip-ams1102+info+model_data+2771411739.tgz done/unzip-ams1102+info+model_data+2772828715.tgz done/unzip-ams1102+info+model_data+2869585698.tgz done/unzip-ams1102+info+model_data+2874849802.tgz done/unzip-ams1127+info+build_merged_alignments+detect-variants--blade14-4-11.gsc.wustl.edu-tmooney-9412-11760428.tgz done/unzip-gc4096+info+model_data+2857786885.tgz done/unzip-gc4096+info+model_data+2868377411.tgz 	done/unzip-gc8001+info+build_merged_alignments+detect-variants--blade14-4-11.gsc.wustl.edu-tmooney-9412-117603728.tgz 

done/annotation:
	# extra annotation data sets
	git clone https://github.com/genome/tgi-misc-annotation.git --branch human-build37-20130113 db/tgi-misc-annotation/human-build37-20130113
	git clone https://github.com/genome/tgi-cancer-annotation.git --branch human-build37-20130113 db/tgi-cancer-annotation/human-build37-20130113
	touch $@

done/annotation-20130310: done/annotation
	mkdir -p db/dbsnp/human || echo ".."
	git clone https://github.com/genome-vendor/genome-db-dbsnp-human.git --branch 132 db/dbsnp/human/132
	mkdir -p db/ensembl/human || echo ".."
	git clone https://github.com/genome-vendor/genome-db-ensembl-human.git --branch 67_37l_v2 db/ensembl/human/67_37l_v2
	cd db/tgi-misc-annotation/human-build37-20130113; git pull origin db/tgi-misc-annotation/human-build37-20130113
	touch $@

update-20130310: done/annotation-20130310 done/unzip-apps-2013-03-10

#####
# hostinit:
# When using a vagrant vm, this must happen on the VM.
# On a standalone machine it can happen along with the "stage-files" targets, though most will occur after those steps run because they depend on them.

done/account:
	sudo groupadd genome || echo ...
	sudo useradd genome -c 'The GMS System User' -g genome -d $(GMS_HOME) || echo ...

done/group: done/account
	sudo usermod -a -G genome $(USER) || echo ...
	
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
	#
	# install unpackaged Perl modules
	#
	curl https://raw.github.com/miyagawa/cpanminus/master/cpanm >| setup/bin/cpanm
	chmod +x setup/bin/cpanm
	sudo setup/bin/cpanm Getopt::Complete

done/openlava-install: done/openlava-download done/hosts done/etc done/pkgs
	cd sw/openlava && ./bootstrap.sh && make && make check && sudo make install 
	sudo chown -R genome:root /opt/openlava-2.0/work/  
	sudo chmod +x /etc/init.d/openlava
	sudo update-rc.d openlava defaults 98 02 || echo ...
	sudo cp setup/openlava-config/lsb.queues /opt/openlava-2.0/etc/lsb.queues
	cat setup/openlava-config/lsf.cluster.openlava | setup/bin/findreplace-gms > /tmp/lsf.cluster.openlava
	sudo cp /tmp/lsf.cluster.openlava /opt/openlava-2.0/etc/lsf.cluster.openlava
	sudo /etc/init.d/openlava start || sudo /etc/init.d/openlava restart
	sudo /etc/init.d/openlava status
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
	source setup/etc/genome.conf; setup/import-db-data.pl setup/dump-db.out
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
	cd db/tgi-misc-annotation/human-build37-20130113; git pull origin
	cd db/tgi-cancer-annotation/human-build37-20130113; git pull origin
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

