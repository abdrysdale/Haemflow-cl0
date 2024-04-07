#! /usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;

my $num_node = 25;
my $init_node = 0;
my $max_node = 250;
my $delay = 3;
my $script_path = 'scripts/physiological_opti_sbatch.sh';
my $debug = 0;

GetOptions ('max=i' => \$max_node,
            'num=i' => \$num_node,
            'init=i' => \$init_node,
            'delay=i' => \$delay,
            'script=s' => \$script_path,
            'debug' => \$debug);

my $cmd = 'sbatch';
if ($debug) {
  $cmd = 'echo';
}

# Checks the number of jobs does not exceed the maximum number of jobs.
if ($init_node + $num_node >= $max_node) {
  $num_node = $max_node - $init_node;
}

my $last_node_idx = $init_node + $num_node - 1;

print "Sending ${num_node} jobs with a ${delay}s delay.\n";
print "Script:\t${script_path}\n\n";

for my $node ($init_node..$last_node_idx) {
  my $job_num = $node + 1;
  print "Sending job ${job_num}/${num_node}\t::\t";

  system($cmd, 
         "--export=ALL,NODE=${node},MAX_NODE=${max_node}",
         $script_path);

  if ($node != $last_node_idx) {
    sleep $delay;
  }
}

print "\nFinished!\n";
