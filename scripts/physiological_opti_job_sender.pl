#! /usr/bin/env perl

use v5.10;

use strict;
use warnings;

use List::Util qw( min );
use Getopt::Long;

my $num_node = 1;
my $init_node = 0;
my $max_node = 1;
my $delay = 3;
my $cpus_per_task = 30;
my $script_path = 'scripts/physiological_opti_sbatch.sh';
my $add_to_queue = 0;
my $timeout = 2880;  # (min) 1440 = 24hrs
my $debug = 0;
my $help = 0;

GetOptions ('max=i' => \$max_node,
            'num=i' => \$num_node,
            'init=i' => \$init_node,
            'wait=i' => \$delay,
            'script=s' => \$script_path,
            'cpus=i' => \$cpus_per_task,
            'time=i' => \$timeout,
            'queue' => \$add_to_queue,
            'help' => \$help,
            'debug' => \$debug);

####################################
# Displays help messages and exits #
####################################

if ($help) {
  say "
USAGE: job_sender.pl [OPTIONS]

Options:

-m, --max       Maximum number of nodes.
-n, --num       Number of nodes for this job.
-i, --init      Initial node number.
-w, --wait      Wait time (s) between `sbatch` calls.
-s, --script    Path to sbatch script.
-t, --time      sbatch timeout in minutes.
-q, --queue     If there are not enough cores available for the job request, queue the remainder.
-d, --debug     Print the results instead of calling sbatch.
-h, --help      Display this message.
";
  exit 1;
}

my $cmd = 'sbatch';
if ($debug) {
  $cmd = 'echo';
}

# Checks the number of jobs does not exceed the maximum number of jobs.
if ($init_node + $num_node >= $max_node) {
  $num_node = $max_node - $init_node;
}

########################################################
# Creates a job plan based on current HPC availability #
########################################################

my @partitions = ('compute', 's_gpu_eng', 'accel_ai');
my %part_accounts = (compute => 'scw1706', s_gpu_eng => 'scw1901', accel_ai => 'scw1901');
my @fields = ('NodeName', 'CPUAlloc', 'CPUEfctv', 'State', 'Partitions');
my @up_states = ('ALLOC', 'MIXED', 'IDLE');
my %max_jobs = (compute => 25, accel_ai => 15, s_gpu_eng => 1);
my %remain_jobs;
my $accel_ai_max_cpus = 16;
my $default_compute_cpus = 30;

# Gets the remaining available jobs per partition
my $ttl_remain_jobs = 0;
for my $part (@partitions) {

  $remain_jobs{$part} = $max_jobs{$part};
  $remain_jobs{$part} -= `sacct | grep $part | grep "RUNNING" | wc -l`;
  $remain_jobs{$part} -= `sacct | grep $part | grep "PENDING" | wc -l`;
  $ttl_remain_jobs += $remain_jobs{$part};
}
if ($ttl_remain_jobs == 0) {
  print("No remaing jobs.\n");
  exit 1;
}


my @output = `scontrol show node`;

# Formats the output into an array of hashes
my @nodes;
my $node_info = {};

# Loads all of the relavent scontrol info into an array of hashes
for my $line (@output) {
  my @line_ary = split ' ', $line;
  for my $item (@line_ary) {
    for my $field (@fields) {
      if (index($item, $field) != -1) {
        my @key_val = split '=', $item;
        $node_info->{$field} = $key_val[1];
        if ($field eq $fields[-1]) {
          push @nodes, $node_info;
          $node_info = {};
        }
      }
    }
  }
}

# Gets only the available nodes
my @up_nodes;
for my $i ( 0 .. $#nodes ) {

  my %node = $nodes[$i]->%*;

  # Checks if the node has the correct partition
  for my $part (@partitions) {
    if (index($node{'Partitions'}, $part) == 0) {

       # Checks if node is online
      for my $up_state (@up_states) {
        if ($node{'State'} eq $up_state) {
          push @up_nodes, $nodes[$i];
        }
      }
    }
  }
}

# Gets the job plan
my @job_plan;
my $ttl_cpus = 0;
for my $i ( 0 .. $#up_nodes ) {

  my %node = $up_nodes[$i]->%*;
  my $job = {};
  
  my @parts = split ',', $node{'Partitions'};
  my $free_cpus = $node{'CPUEfctv'} - $node{'CPUAlloc'};

  $ttl_cpus += $free_cpus;

  # accel_ai has a max cpu limit
  # this ensures CPU limit is not exceeded
  if ($parts[0] eq 'accel_ai') {
    
    my $cpus_remaining = $free_cpus;
    while ($cpus_remaining > 0) {
      my $plan_cpus = min($cpus_remaining, $accel_ai_max_cpus);

      $job->{'free'} = $plan_cpus;
      $job->{'part'} = $parts[0];
      $job->{'account'} = $part_accounts{$parts[0]};
      push @job_plan, $job;
      $job = {};

      $cpus_remaining -= $plan_cpus;
    }
  } else {
    $job->{'free'} = $free_cpus;
    $job->{'part'} = $parts[0];
    $job->{'account'} = $part_accounts{$parts[0]};
    push @job_plan, $job;
    $job = {};
  }
}
my @sorted_jobs = sort {$b->{free} <=> $a->{free}} @job_plan;

# Filters the sorted jobs to ensure the job limit is not exceeded
my @filtered_jobs;
for my $i ( 0 .. $#sorted_jobs) {

  my %job = $sorted_jobs[$i]->%*;

  if ($remain_jobs{$job{part}} > 0) {
    $remain_jobs{$job{part}} -= 1;
    push @filtered_jobs, $sorted_jobs[$i];
  }
}

my $requested_cpus = $cpus_per_task * $num_node;
if ($ttl_cpus < $requested_cpus and $add_to_queue) {
  print "Requested CPUs ($requested_cpus) exceeds all available CPUs ($ttl_cpus).\n";
  print "Adding remaining jobs to the queue.\n";

  my $cpus_remaining = $requested_cpus - $ttl_cpus;
  while ($cpus_remaining > 0) {
    my $plan_cpus = min($cpus_remaining, $default_compute_cpus);

    my $job = {};
    $job->{'free'} = $plan_cpus;
    $job->{'part'} = 'compute';
    $job->{'account'} = $part_accounts{compute};
    push @filtered_jobs, $job;

    $cpus_remaining -= $plan_cpus;
  }
  @filtered_jobs = sort {$b->{free} <=> $a->{free}} @filtered_jobs;
}

# Proportionally splits the jobs according to number of CPUS
my $ttl_job_cpus = $cpus_per_task * $max_node;
my @start_idx;
my $prev_idx = $init_node * $cpus_per_task;
for my $i ( 0 .. $#filtered_jobs ) {

  my %job = $filtered_jobs[$i]->%*;

  $start_idx[$i] = $prev_idx;

  $prev_idx +=  $job{free};
}


##################
# Sends the jobs #
##################

my $total_jobs = $#filtered_jobs + 1;
print "Sending $total_jobs jobs with a ${delay}s delay.\n";
print "Script:\t${script_path}\n\n";

print "
|-------|-------|---------------|---------------|
| Job   | CPUS  | Partition     | ID            |
|-------|-------|---------------|---------------|
";
for my $i ( 0 .. $#filtered_jobs ) {
  my $job_num = $i + 1;
  my %job = $filtered_jobs[$i]->%*;
  print "| $job_num\t| $job{free}\t| $job{part}\t|";

  my @options = (
                 "--export=ALL,START=$start_idx[$i],NUM=$job{free},TOTAL=$ttl_job_cpus",
                 "--cpus-per-task=$job{free}",
                 "--account=$job{account}",
                 "--partition=$job{part}",
                 "--gres=gpu:0",
                 "--time=$timeout",
                 $script_path,
                );

  my $id = "N/A\t";
  unless ($debug) {
    my $resp = qx/$cmd @options/;
    my @response = split ' ', $resp;
    $id = $response[-1];
  }
  print " $id\t|\n"; 

  if ($job_num < $#filtered_jobs) {
    sleep $delay;
  }
}

say "|-------|-------|---------------|---------------|";
