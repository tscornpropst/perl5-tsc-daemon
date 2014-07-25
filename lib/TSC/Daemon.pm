package TSC::Daemon;

use strict;
use warnings;

use version; our $VERSION = qv('0.0.8');

use Carp qw(croak carp);
use Class::InsideOut qw(:std);
use Cwd;
use File::Basename;
use IO::File;
use POSIX qw(:signal_h setsid :sys_wait_h WNOHANG);

# This doesn't work inside the closure
local $SIG{CHLD} = \&_reap_child;

{
private user_name    => my %user_name;
private group_name   => my %group_name;
private pid_file     => my %pid_file;
private work_dir     => my %work_dir;
private path         => my %path;
private taint_mode   => my %taint_mode;
private pid          => my %pid;
private original_dir => my %original_dir;

my %children;

#-------------------------------------------------------------------------------
sub new {
    my ($class, $arg) = @_;

    my $self = \(my $scalar);
    bless $self, $class;
    register ($self);

    my $base = fileparse($0, qr/\.[^.]*/msx);
    my $pidfile = join '.', $base, 'pid';

    $pid_file{id $self} = $arg->{pid_file} || join '/', '/var/run', $pidfile;
    $original_dir{id $self} = getcwd();
    $user_name{id $self}    = $arg->{user_name}  || 'nobody';
    $group_name{id $self}   = $arg->{group_name} || 'nobody';
    $work_dir{id $self}     = $arg->{work_dir}   || '/';
    $path{id $self}         = $arg->{path}       || '/bin:/usr/bin';
    $taint_mode{id $self}   = $arg->{taint_mode} || undef;

    return $self;
}

#-------------------------------------------------------------------------------
# Object destructor
sub DEMOLISH {
    my ($self) = @_;

    # Make sure we are the new process, not the exiting parent
    if((defined $pid{id $self}) and ($$ == $pid{id $self})) {

        $self->_regain_privileges();

        my $pid = $pid{id $self};
        unlink $pid_file{id $self};
    }

    return;
}

#-------------------------------------------------------------------------------
sub detach {
    my ($self) = @_;

    # Set the pidfile
    my $fh = $self->_create_pid_file();

    # Become a daemon
    # 1. Fork and exit parent process
    croak q{Cannot fork from current session in }, (caller(0))[3]
        unless defined (my $child = fork());

    exit 0 if $child; # parent dies

    # 2. Start a new session with the child as the leader
    POSIX::setsid()
        or croak "Cannot create new session: $! in ", (caller(0))[3];

    # 3. Close STDIN, STDOUT, STDERR
    open(STDIN,  '<', '/dev/null');
    open(STDOUT, '>', '/dev/null');
    open(STDERR, '>', '/dev/null');

    # 3. change the working directory
    my $workdir = $work_dir{id $self};

    chdir $workdir or croak "Could not chdir to $workdir in ", (caller(0))[3];

    # 4. Forget file mode creation mask
    umask(0);

    # 5. Set a safe path
    $ENV{PATH} = $path{id $self};
    delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

    $pid{id $self} = $$;

    # write our pid file
    print ${fh} $$;
    close $fh;

    # Moved outside closure
    # 6. Prevent zombies, execute this if we get a CHLD signal
#    $SIG{CHLD} = sub {
#        while ( (my $child = waitpid(-1, WNOHANG)) > 0 ) {
#            $children{$child}->($child)
#                if ref $children{$child} eq 'CODE';
#    
#            delete $children{$child};
#        }
#    };

    # 7. Change the effective UID but not the real UID
    $self->_change_privileges();

    return $pid{id $self}; # return the process id of the child
}

#-------------------------------------------------------------------------------
sub _reap_child {
    while ( (my $child = waitpid(-1, WNOHANG)) > 0 ) {
        $children{$child}->($child)
            if ref $children{$child} eq 'CODE';

            delete $children{$child};
    }

    return;
}

#-------------------------------------------------------------------------------
# we could possilby add an argument to set the working directory instead of
# assuming the caller wants the child process chrooted same as parent.
sub spawn {
    my ($self, $callback, $chroot_dir) = @_;

    my $signals = POSIX::SigSet->new(SIGINT, SIGCHLD, SIGTERM, SIGHUP);

    # Temporarily block signals until after we fork
    POSIX::sigprocmask(SIG_BLOCK, $signals);

    croak q{Cannot fork in}, (caller(0))[3]
        unless defined (my $child = fork() );

    if($child) {
        # update the child list
        # $callback is executed when the child is reaped
        $children{$child} = $callback || 1;
    }
    else {
        # set child signals to defaults
        $SIG{HUP} = $SIG{INT} = $SIG{CHLD} = $SIG{TERM} = 'DEFAULT';

        if ( $chroot_dir ) {
            local ($>, $<) = ($<, $>); # temporary rootness, regain privs

            chdir $chroot_dir or croak "chdir() to $chroot_dir: $! in ",
                (caller(0))[3];

            chroot $chroot_dir or croak "chroot() to $chroot_dir: $< $> $! in ",
                (caller(0))[3];
        }
    }

    $< = $>; # Set real UID to effective UID

    sigprocmask(SIG_UNBLOCK, $signals); # unblock signals

    return $child;
}

#-------------------------------------------------------------------------------
sub stop {
    my ($self) = @_;

    _kill_children();

    # We shouldn't get here
    exit; # DEMOLISH() will run
}

#-------------------------------------------------------------------------------
sub refresh {
    my ($self) = @_;

    $self->_regain_privileges();

    _kill_children();

    unlink $pid_file{id $self};

    chdir $1 if $original_dir{id $self} =~ m!([./a-zA-Z0-9_-]+)!msx;

    croak 'Bad program name' unless $0 =~ m!([./a-zA-Z0-9_-]+)!msx;

    my $command_line = $1;

    # untaint the @ARGS
    for( @ARGV ) {
        if ( $_ =~ m/^(.*)$/msx ) {
            $command_line = join q{ }, $command_line, $1;
        }
    }

    if ( $taint_mode{id $self} ) {
        exec 'perl', '-T', $command_line or croak "Could not exec: $!\n";
    }
    else {
        exec 'perl', $command_line or croak "Could not exec: $!\n";
    }

    return;
}

#-------------------------------------------------------------------------------
sub get_user_name { my ($self) = @_; return $user_name{id $self}; }

#-------------------------------------------------------------------------------
sub set_user_name {
    my ($self, $name) = @_;
    return $user_name{id $self} = $name;
}

#-------------------------------------------------------------------------------
sub get_group_name { my ($self) = @_; return $group_name{id $self}; }

#-------------------------------------------------------------------------------
sub set_group_name {
    my ($self, $name) = @_;
    return $group_name{id $self} = $name;
}

#-------------------------------------------------------------------------------
sub get_pid_file { my ($self) = @_; return $pid_file{id $self}; }

#-------------------------------------------------------------------------------
sub set_pid_file {
    my ($self, $pid_file) = @_;
    return $pid_file{id $self} = $pid_file;
}

#-------------------------------------------------------------------------------
sub get_work_dir { my ($self) = @_; return $work_dir{id $self}; }

#-------------------------------------------------------------------------------
sub set_work_dir {
    my ($self, $work_dir) = @_;
    return $work_dir{id $self} = $work_dir;
}

#-------------------------------------------------------------------------------
sub get_path { my ($self) = @_; return $path{id $self}; }

#-------------------------------------------------------------------------------
sub set_path { my ($self, $path) = @_; return $path{id $self} = $path; }

#-------------------------------------------------------------------------------
sub get_taint_mode { my ($self) = @_; return $taint_mode{id $self}; }

#-------------------------------------------------------------------------------
sub set_taint_mode {
    my ($self, $mode) = @_;
    return $taint_mode{id $self} = $mode;
}

# Private methods --------------------------------------------------------------
#-------------------------------------------------------------------------------
sub _change_privileges {
    my ($self) = @_;

    my $user = $user_name{id $self};
    my $group = $group_name{id $self};

    my $uid = getpwnam($user)
        or croak "Could not get UID for $user in ", (caller(0))[3] ; 
    my $gid = getgrnam($group)
        or croak "Could not get GID for $group in ", (caller(0))[3];

    # inherit group membership
    my $egids = $gid; # store the primary GID

    # add supplementary gids to string
    while ( my @group_info = getgrent() ) {
        $egids = join q{ }, $egids, $group_info[2]                                            if grep { /petadmin/ } $group_info[3];
    }

    $) = $egids; # must be a space separated string
    $( = $gid;
    $> = $uid; # change the effective UID (but not the real UID)

    return;
}

#-------------------------------------------------------------------------------
sub _create_pid_file {
    my ($self) = @_;

    my $file = $pid_file{id $self};

    if ( -e $file ) {

        if( -s $file > 0 ) {
            my $fh = IO::File->new($file) or return;

            my $pid = <$fh>;

            close $fh;

            croak 'Invalid PID file' unless $pid =~ m/^(\d+)$/msx;
            croak "Server already running with PID $1" if kill 0 => $1;
            carp  "Removing PID file for defunct server process $pid\n";
            croak "Cannot unlink PID $pid file $file" unless -w $file && unlink $file;
        }
        else {
            unlink $file;
        }
    }

    return IO::File->new($file, O_WRONLY|O_CREAT|O_EXCL, oct(644))
        or croak "Cannot create $file: $!\n";

    return;
}

#-------------------------------------------------------------------------------
sub _kill_children {

    # Send a signal to all the kids
    kill TERM => keys %children;

    # wait until they are all dead, loop on the hash while wait pid exexutes
    sleep while %children;

    return;
}

#-------------------------------------------------------------------------------
sub _regain_privileges {
    my ($self) = @_;

    $> = $<;

    return;
}

}

1;

__END__

=pod

=head1 NAME

TSC::Daemon - Simple Unix daemon class

=head1 VERSION

This documentation refers to TSC::Daemon version 0.0.8.

=head1 SYNOPSIS

    use TSC::Daemon;

    # Clear the environment for taint mode
    $ENV{PATH} = '/bin';
    delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

    my $daemon = TSC::Daemon->new({
        user_name  => $username,
        group_name => $groupname,
        pid_file   => '/path/to/daemon.pid',
        work_dir   => '/path/to/working_directory',
        path       => '/bin:/usr/bin',
    });

    # Define some signal handlers
    $SIG{HUP} = $daemon->refresh();
    $SIG{INT} = $SIG{TERM} = $daemon->stop();

    # Fork and detach from the current session
    $daemon->detach();

    # Start a sub process
    $daemon->spawn();

    # Reinitialize
    $daemon->refresh();


=head1 DESCRIPTION

B<TSC::Daemon> provides basic deamon functionality for programs. It creates a pid file and detaches from the terminal, going into the background. It does NOT create any sockets, provide logging facilities or do any other fancy things. These features should come from somewhere else. Simple.

B<TSC::Daemon> expects to be started as root. You should perform any socket creation or other privileged functions before you detach. After you call detach() STDOUT, STDIN, and STDERR are closed. You will only be able to get output to files (i.e. log files) or you can re-open those handles. You probably will only need logging capabilities. See PV::Log::File or Sys::Syslog.

B<TSC::Daemon> processes can be started the same as other UNIX daemons using the init or rc sub-systems.

Daemons created with TSC::Daemon run as nobody/nobody by default.

Daemons should change to a safe working directory. TSC::Daemon daemons use / by default.

Daemons should set a safe PATH environment. TSC::Daemon daemons use an undefined path by default. Remember to use enough path for any external programs you may call.

Steps to create a daemon process:

=over

=item * Forks a child, parent exits

=item * Child becomes the session leader

=item * Close STDIN, STDOUT, STDERR

=item * Changes working directory

=item * Chroot the working directory

=item * Clear the umask

=item * Set a safe environment for taint mode (deletes ENV, etc)

=item * Set a safe path

=item * Write a pid file

=item * Change privileges to 'nobody'/nobody

=back

You should perform any operations that require special privileges, such as creating a socket, before you call detach().

If you call any of the set_* methods, you will need to call refresh() to reinitialize the daemon.

B<TSC::Daemon> takes care of managing pid files for you. The default pid file is /var/run/program_name.pid where program_name is the value returned from $0 with any extension stripped off.

Child processes created through the spawn() method chroot to the directory named in the constructor parameter work_dir. The default work_dir is /.

B<TSC::Daemon> attempts to perform all steps necessary to run in taint mode. It sets a default undefined path which may be overridden with the path contructor parameter. It also deletes 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' from the environment. If the constructor parameter taint_mode is true and the refresh() method is called, TSC::Daemon attempts to restart the program with the original command line arguments. Minimal checking is performed for taintedness.

=head1 SUBROUTINES/METHODS

=over

=item new()

Object constructor.

=over

=item * user_name defaults to 'nobody'

=item * group_name defaults to 'nobody'

=item * work_dir defaults to /

=item * path defaults to undefined

=item * pid_file automatically created or overridden

=item * taint_mode defaults to off

=back

=item detach()

Follows the steps above to create a daemon process. This method will close STDOUT so, make sure you have some method of logging for output. This is also the point where the process will change privileges. Perform any actions requiring special privileges before you detach.

=item spawn()

This will fork to create a new worker process. The child pid is stored for reaping. The method takes a code reference as and argument for a callback when the child process is reaped. This is useful for any cleanup actions you want taken after the child is reaped.

Child processes are chroot'd.

See B<EXAMPLES>.

=item refresh()

Kills all children and forks a new parent process. This is useful to place in a signal handler for HUP.

=item stop()

This is a method you can assign to a signal handler for TERM or INT. It will kill the child processes and exit.

=item get_user_name()

Returns the user name for the daemon process.

=item set_user_name()

Set the user name for the daemon process. The process will use this for user permissions. Ensure this account is defined in /etc/passwd. The default is nobody.

=item get_group_name()

Returns the group name for the daemon process.

=item set_group_name()

Set the group name for the daemon process. The process will use this for group permissions. Ensure this group exists in /etc/groups. The default is nobody.

=item get_pid_file()

Get the fully qualified name of the pid file.

=item set_pid_file()

The the pid file name and path. The default is to create a pid file in /var/run with the basename of the program and an extension of .pid. For example: /var/run/daemon.pid.

=item get_work_dir()

Returns the working directory of the process.

=item set_work_dir()

Set the working directory of the process. The process will chroot to this directory when detach() or spawn() is called.

=item get_path()

Get the current environment path used by the process.

=item set_path()

Set the environment path for the process.

=item get_taint_mode()

Returns the status of taint mode.

=item set_taint_mode()

Enable taint mode with a true value. Disable with undef or zero.

=back

=head1 EXAMPLES

This is a sample startup script:

    #!/bin/sh
    
    name="test"
    command="/home/tsc/src/perl/daemon/${name}.pl"
    pid_file="/var/run/${name}.pid"
    
    if [ -f $pid_file ]; then
        read pid _junk < $pid_file
    fi
    
    case $1 in
        stop)
            kill $pid
            return 1
            ;;
        start)
            $command
            return 1
            ;;
        restart)
            kill -HUP $pid
            return 1
            ;;
    esac

The proper way to spawn a child process

    my $child = $daemon->spawn();

    # $child is true for the parent
    unless ( $child ) {
        # we are in the child process
        ... do your stuff ...

        # be sure to call exit or the new process will live forever
        exit 0;
    }


=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

TSC::Daemon requires no configuration files or environment variables.

=head1 DEPENDENCIES

=over

=item * Carp

=item * Class::InsideOut

=item * Cwd;

=item * File::Basename

=item * IO::File

=item * POSIX

=item * version

=back

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

Although this module is based on Class::InsideOut, it uses a global, unkeyed hash to store child pids.

Taint mode has not been thorougly tested. The automated tests are very limited. Most testing was completed manually.

No bugs have been reported.

Please report any issues or feature requests to Trevor S. Cornpropst tscornpropst@gmail.com. Patches are welcome.

=head1 SEE ALSO

Network Programming with Perl, Lincoln D. Stein

perldoc perlipc

=head1 AUTHOR

Trevor S. Cornpropst C<tscornpropst@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007, Trevor S. Cornpropst. All rights reserved.

This module is free software. It may be used, redistributed and/or modified under the terms of The Artistic License 2.0.

=head1 DISCLAIMER OF WARRANTY

THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS "AS
IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL
LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

