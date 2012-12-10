#!/usr/bin/env perl
BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
}

use Genome;
use strict;
use warnings;

my $sanitize_file = "/gscuser/ssmith/bin/sanitize.csv";
unless (-e $sanitize_file) {
    die "expected file $sanitize_file to exist to sanitize data";
}

my %clean;
my @rows = IO::File->new($sanitize_file)->getlines;
chomp @rows;
for my $row (@rows) {
    next unless $row;
    my ($old,$new) = split(/,/,$row);
    $clean{$old} = $new;
}

# a print function to log output
my $depth = 0;
sub p {
    for my $m (@_) {
        print STDERR ((" " x $depth),$m, "\n");
    }
}

# this is called recursively on the root build to get all of its deps
my %build_ids;
my %diskalloc_ids;
my @all_build_inputs;
my @all_build_input_values;
sub get_build {
    my $b = shift;
    my $build_id = $b->id; 
    if ($build_ids{$build_id}) {
        return;
    }

    p("got build " . $b->__display_name__);
    $build_ids{$build_id} = $b;
 
    $depth++;
    
    #my @sr = $b->results;
    #for my $sr (@sr) {
    #    get_sr($sr);
    #}

    my $m = $b->model;

    if ($m->isa("Genome::Model::ReferenceAlignment") or $m->isa("Genome::Model::SomaticVariation") or $m->isa("Genome::Model::ClinSeq" or $m->isa("Genome::Model::RnaSeq"))) {
        p("ignoring filesystem data for pipeline models");
        $b->status("Dummy");
        my $e = $b->the_master_event;
        die unless $e->event_status eq "Dummy";
        $e->{db_committed}{event_status} = "Dummy";
    }
    else {
        my @disks = Genome::Disk::Allocation->get(owner_id => $build_id);
        for my $d (@disks) {
            p("got disk " . $d->__display_name__);
            get_diskalloc($d)
        }
    }

    my @i = $b->inputs;
    for my $i (@i) {
        my $v = $i->value;
        if ($v->isa("Genome::Model")) {
            print "model? $v\n";
        }
        #p("got input " . $v->__display_name__);
        if ($v->isa("Genome::Model::Build")) {
            get_build($v);
        }
        else {
            my @disks;
            @disks = Genome::Disk::Allocation->get(owner_id => $v->id) if $v->id ne '1';
            if (@disks) {
                p("got input with disk " . ref($v) . " " . $v->__display_name__);
                for my $d (@disks) {
                  get_diskalloc($d);
                }
            }
        }
        push @all_build_inputs, $i;
        push @all_build_input_values, $v;
    }

    $depth--;
}

sub get_diskalloc {
    my $diskalloc = shift;
    my $diskalloc_id = $diskalloc->id;
    if ($diskalloc_ids{$diskalloc_id}) {
        return;
    }

    p("got diskalloc " . ref($diskalloc) . " " . $diskalloc->__display_name__);
    $diskalloc_ids{$diskalloc_id} = $diskalloc;
}

# this is hard-coded to an example clinseq build for now
my $build_id = 126198496;
my $b = Genome::Model::Build->get($build_id);
get_build($b);

# pull down related data for each build 
my @all_build_ids = sort keys %build_ids;

my @all_builds = values %build_ids;
my @all_events = Genome::Model::Event->get(build_id => [keys %build_ids]);

my @all_model_ids = map { $_->model_id } @all_builds;
my @all_models = Genome::Model->get(\@all_model_ids);
my @all_model_inputs = Genome::Model::Input->get("model_id" => \@all_model_ids);

my @all_pp_ids = map { $_->processing_profile_id } @all_models;
my @all_profiles = Genome::ProcessingProfile->get(\@all_pp_ids);

my @all_ppp = Genome::ProcessingProfile::Param->get("processing_profile_id" => \@all_pp_ids);
my @some_disk_allocations = values %diskalloc_ids;

my @all_instdata_attr;
my @all_subject_attr;
for (my $n = 0; $n < $#all_build_input_values; $n++) {
    my $v = $all_build_input_values[$n];
    my $parent;
    if ($v->isa("Genome::InstrumentData")) {
        $parent = $v->library;
        my @a = $v->attributes;
        p("got " . scalar(@a) . " attributes for " . $v->__display_name__);
        push @all_instdata_attr, @a;
    }
    elsif ($v->isa("Genome::Library")) {
        $parent = $v->sample;
    }
    elsif ($v->isa("Genome::Sample")) {
        $parent = $v->source;
    }
    elsif ($v->isa("Genome::Individual")) {
        $parent = $v->taxon;
    }
    elsif ($v->isa("Genome::PopulationGroup")) {
        $parent = $v->taxon;
    }

    if ($parent) {
        p("got parent " . $parent->__display_name__ . " for " . $v->__display_name__);
        push @all_build_input_values, $parent;
    }

    if ($v->isa("Genome::Subject")) {
        my @a = $v->attributes;
        p("got " . scalar(@a) . " attributes for " . $v->__display_name__);
        push @all_subject_attr, @a;
    }
}

my %disk_meta;
for my $disk_alloc (@some_disk_allocations) {
    my $group = $disk_alloc->group;
    my $volume = $disk_alloc->volume;
    my @assignments = $volume->assignments;
    for my $o ($group, $volume, @assignments) {
        $disk_meta{$o->class}{$o->id} = $o;
    }
}

my @disk_meta;
for my $c (values %disk_meta) {
    for my $o (values %$c) {
        push @disk_meta, $o;
    }
}

my @todo = (
    'builds' => \@all_builds,
    'events' => \@all_events,
    'build input bridges' => \@all_build_inputs,
    'build input values' => \@all_build_input_values,
    'models' => \@all_models,
    'model input bridges' => \@all_model_inputs,
    'profiles' => \@all_profiles,
    'profile params' => \@all_ppp,
    'disk allocations' => \@some_disk_allocations,
    'disk meta' => \@disk_meta,
    'instdata attr' => \@all_instdata_attr,
    'subject_attr' => \@all_subject_attr,
); 

my %done;
while (@todo) {
    my $label = shift @todo;
    my $list  = shift @todo;

    print "# $label\n"; 
    for my $o (@$list) {
        my $class = ref($o);
        my $id = $o->id;
        next if $done{$class}{$id};
        $done{$class}{$id} = 1;
        my $txt = UR::Util::d($o),"\n";
        for my $old (keys %clean) {
            my $new = $clean{$old};
            if ($txt =~ s/$old/$new/g) {
                print STDERR "cleaned $old to $new\n";
            }
        }
        print $txt,"\n";
    }
}


