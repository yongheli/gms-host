#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use IO::File;
use Genome;

my $f = shift;
die "No database dump file specified!" unless $f;
die "Failed to find $f!" unless -e $f;

my @dumps = grep { $_ !~ /^#/ } IO::File->new($f)->getlines;

my $err = sub { };

my %loaded;
for my $dump (@dumps) {
    my $hash = do {
        no strict;
        no warnings;
        eval $dump;
    };
    die "NO HASH?: $dump" unless $hash;

    my $class = ref($hash);
    my $id = $hash->{id};

    eval "use $class";

    next if $class->isa("UR::Value");

    my $dbc = delete $hash->{db_committed};
    die unless $dbc;

    for my $key (keys %$dbc) {
        no warnings;
        unless ($hash->{$key} eq $dbc->{$key}) {
            die "data discrepancy: $hash with ID $hash->{id} has key $key with value $hash->{$key} but db_committed is $dbc->{$key}\n";
        }
        
        if ($hash->{$key} =~ m|gscmnt|) {
            if ($hash->{$key} =~ s|gscmnt|opt/gms/fs|) {
                print STDERR "updated $class $id $key to $hash->{$key}\n";
            }
            else {
                die "error updating $class $id $key gscmnt content!";
            }
        }
    }


    $loaded{$class}{$id} = $hash;

    #$UR::Context::all_objects_loaded->{$class}{$id} = $hash;
  
    my $entity = UR::Context->_construct_object($class,%$hash, id => $id);
    die "failed create for $class $id\n" unless $entity;
    $entity->__signal_change__('create');
    $entity->{'__get_serial'} = $UR::Context::GET_COUNTER++;
    $UR::Context::all_objects_cache_size++;

    print ">>> $hash $entity\n";
}

print "\n\nFABRICATED\n\n";
$ENV{UR_DBI_MONITOR_SQL} = 1;
for my $c (keys %loaded) {
    do {
        no strict;
        no warnings;
        my $m = $c . '::__errors__';
        *$m = $err;
    };

    my $h = $loaded{$c};
    for my $i (keys %$h) {
        my $o = $c->get($i);
        print "$c $i $o\n";
    }
}

print "\n\nFABRICATED\n\n";
UR::Context->commit;

