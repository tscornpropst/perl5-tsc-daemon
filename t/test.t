#!/usr/bin/perl
#===============================================================================
#         FILE:  test.t
#
#  DESCRIPTION:  Test TSC::Daemon
#
#       AUTHOR:  Trevor S. Cornpropst, <tscornpropst@tscornpropst@gmail.com>
#      COMPANY:  TSC
#      VERSION:  0.0.8
#      CREATED:  06/16/2007 23:23:18 EDT
#===============================================================================

use strict;
use warnings;

use Test::More tests => 34;
use Test::Strict;

BEGIN {
    use_ok('TSC::Daemon');
}

# List all module methods/subroutines
my $module = 'TSC::Daemon';
my @methods = qw(
    new
    get_user_name
    set_user_name
    get_group_name
    set_group_name
    get_pid_file
    set_pid_file
    get_work_dir
    set_work_dir
    get_path
    set_path
    get_taint_mode
    set_taint_mode
    detach
    refresh
    spawn
    stop
    _kill_children
    _change_privileges
    _create_pid_file
    _regain_privileges
);

strict_ok($module);
warnings_ok($module);
syntax_ok($module);

# Test default constructor
ok(my $obj = TSC::Daemon->new(), 'default constructor');
isa_ok($obj, $module);
can_ok($obj, @methods);

is(
    $obj->get_user_name(),
    'nobody',
    'default user_name correct',
);

is(
    $obj->get_group_name(),
    'nobody',
    'default group_name correct',
);

is(
    $obj->get_work_dir(),
    '/',
    'default work_dir correct',
);

is(
    $obj->get_pid_file(),
    '/var/run/test.pid',
    'default pid_file correct',
);

is(
    $obj->get_path(),
    '/bin:/usr/bin',
    'default path correct',
);

is(
    $obj->get_taint_mode(),
    undef,
    'default taint mode correct',
);

# Test constructor
ok(my $obj1 = TSC::Daemon->new({
    user_name  => 'jack',
    group_name => 'jack',
    pid_file   => './jack.pid',
    work_dir   => './',
    path       => '/bin',
    taint_mode => 1,
}), 'constructor with custom args');

# Test inheritence
isa_ok($obj1, $module);

# Test methods, quick
can_ok($obj1, @methods);

is(
    $obj1->get_user_name(),
    'jack',
    'get_user_name() from new()',
);

is(
    $obj1->set_user_name('pf'),
    'pf',
    'set_user_name() returns the last user name',
);

is(
    $obj1->get_user_name(),
    'pf',
    'correct user_name after set_user_name()',
);

is(
    $obj1->get_group_name(),
    'jack',
    'get_user_name() from new()',
);

is(
    $obj1->set_group_name('pf'),
    'pf',
    'set_group_name() returns the last group name',
);

is(
    $obj1->get_group_name(),
    'pf',
    'correct group_name after set_group_name()',
);

is(
    $obj1->get_pid_file(),
    './jack.pid',
    'get_pid_file() from new()',
);

is(
    $obj1->set_pid_file('./pf_daemon.pid'),
    './pf_daemon.pid',
    'set_pid_file() returns last pid_file',
);

is(
    $obj1->get_pid_file(),
    './pf_daemon.pid',
    'correct pid_file after set_pid_file()',
);

is(
    $obj1->get_work_dir(),
    './',
    'custom work_dir'
);

is(
    $obj1->set_work_dir('/jack'),
    '/jack',
    'set_work_dir() returns last work_dir',
);

is(
    $obj1->get_work_dir(),
    '/jack',
    'correct work_dir after set_work_dir()',
);

is(
    $obj1->get_path(),
    '/bin',
    'correct path from custom constructor'
);

is(
    $obj1->set_path('/bin:/usr/bin'),
    '/bin:/usr/bin',
    'set_path() returns last path',
);

is(
    $obj1->get_path(),
    '/bin:/usr/bin',
    'correct path after set_path()'
);

is(
    $obj1->get_taint_mode(),
    1,
    'correct taint_mode from custom constructor',
);

is(
    $obj1->set_taint_mode(undef),
    undef,
    'turn off taint_mode',
);

is(
    $obj1->get_taint_mode(),
    undef,
    'taint_mode after set_taint_mode()',
);
