#!/usr/bin/env make

# if changed to a new value, /opt/gms will be a symlink to this value 
# (some code below depends on a hard-coded path and uses /opt/gms during installation sadly)
GMS_HOME=/opt/gms

# data which is too big to fit in the git repository is staged here
#DATASERVER=ftp://genome.wustl.edu:/pub/software/gms/setup/archive-files
DATASERVER=blade12-1-1://gscmnt/sata849/info/gms/setup/archive-files/

# steps which use this path will only work from within TGI
INTERNAL_DATASERVER=wugsc.wustl.edu:/gscmnt/sata849/info/gms/setup/archive-files-internal


all: sw data

apt-mirror-min-ubuntu-12.04/%:
	mkdir -p $@

sw: apt-mirror-min-ubuntu-12.04/var apt-mirror-min-ubuntu-12.04/skel apt-mirror-min-ubuntu-12.04/mirror
	sudo apt-get install apt-mirror
	rm mirror-ubuntu-12.04.config || echo
	cat mirror-ubuntu-12.04.template | perl -ne 's|DIR|$(PWD)|; print' >| mirror-ubuntu-12.04.config
	apt-mirror mirror-ubuntu-12.04.config
	tgz apt-mirror-min-ubuntu-12.04
	mv apt-mirror-min-ubuntu-12.04.tgz ../archive-files/

data: setup/data/dump-db.out setup/data/dump-disk.out

setup/data/dump-db.out:
	# re-dump the database entities needed to prime the schema
	setup/stage/dump-db.pl 1>setup/data/dump-db.out 2>setup/data/dump-db.err

setup/data/dump-disk.out: setup/data/dump-db.out
	# re-tar the disk allocations used by the database dump
	setup/stage/dump-disk.pl 1>setup/data/dump-disk.out 2>setup/data/dump-disk.err

