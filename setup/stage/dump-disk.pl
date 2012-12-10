#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use IO::File;
use Genome;

my $f = File::Basename::dirname(__FILE__) . '/../data/dump-db.out';
die "Failed to find $f!" unless -e $f;

my @dumps = grep { $_ !~ /^#/ } IO::File->new($f)->getlines;

for my $dump (@dumps) {
    my $hash = do {
        no strict;
        no warnings;
        eval $dump;
    };
    die unless $hash;

    my $class = ref($hash);
    my $id = $hash->{id};

    next unless $class eq 'Genome::Disk::Allocation';
    my $d = $class->get($id);
    die unless $d;

    my $path = $d->absolute_path;
    
    my $o = $d->owner;
    if ($o->isa("Genome::Model::Build::RnaSeq")) {
        warn "ignoring rnaseq build data directory $path";
        next;
    }

    my $size = `du -sm $path`;
    chomp $size;
    $size =~ s/\s.*//;

    print "#$size MB owned by " . $o->class . ": " . $o->__display_name__ . "\n";
    print $path,"\n\n";
}

