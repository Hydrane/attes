package Attes::Test;

use strict;
use warnings;

use Carp;

use Attes::Conf;
use Attes::File;
use Attes::Message qw();
use Attes::Utils;
use File::Basename;
use File::Slurp;
use File::Spec::Functions;
use Term::ANSIColor qw(:constants);

require Exporter;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ('all' => [@EXPORT_OK]);
our $VERSION     = '0.1';

my $COMMAND_FILE_NAME  = 'command.txt';
my $RESULT_FILE_NAME   = 'result.txt';
my $EXPECTED_FILE_NAME = 'expected.txt';
my $ERROR_FILE_NAME    = 'errors.txt';
my $QUERY_FILE_NAME    = 'query.txt';

my $EXE_FIELD_NAME      = 'exe';
my $DATABASE_FIELD_NAME = 'database';
my $ACTION_FIELD_NAME   = 'action';
my $FILE_FIELD_NAME     = 'file';
my $CHECK_FIELD_NAME    = 'check';
my $USER_FIELD_NAME     = 'user';
my $PASSWORD_FIELD_NAME = 'password';

my $IF_FAILS_FIELD_NAME = 'if_fails';
my $REGEX_CONTINUE      = 'continue|next';
my $REGEX_STOP          = 'stop|last';
my $REGEX_JUMP_TO       = 'jump_to|jump\s+to';
my $REGEX_EXIT          = 'exit|abort';
my $CONTINUE            = 'continue';
my $STOP                = 'stop';
my $JUMP_TO             = 'jump_to';
my $EXIT                = 'exit';
my $IF_FAILS_DEFAULT    = $STOP;

my $MYSQL      = 'mysql';
my $POSTGRESQL = 'postgresql';
my $ORACLE     = 'oracle';  # not implemented yet
my $SQLITE3    = 'sqlite3'; # not implemented yet

my $START_RDBMS          = 'start_rdbms';
my $STOP_RDBMS           = 'stop_rdbms';
my $CREATE_DATABASE      = 'create_database';
my $DROP_DATABASE        = 'drop_database';
my $SOURCE_FILE          = 'source_file';
my $SOURCE_EXTERNAL_FILE = 'source_external_file';

my $REGEX_MATCH          = 'regex_match';
my $REGEX_NO_MATCH       = 'regex_no_match';
my $REGEX_FILE           = 'regex_file';
my $TRACE_REGEX_MATCH    = 'trace_regex_match';
my $TRACE_REGEX_NO_MATCH = 'trace_regex_no_match';
my $TRACE_REGEX_FILE     = 'trace_regex_file';
my $COMPARE              = 'compare';
my $NONE                 = 'none';

my %ALLOWED_RDBMS = (
    $MYSQL      => 1,
    $POSTGRESQL => 1,
);

my %ALLOWED_ACTIONS = (
    $START_RDBMS          => 1,
    $STOP_RDBMS           => 1,
    $CREATE_DATABASE      => 1,
    $DROP_DATABASE        => 1,
    $SOURCE_FILE          => 1,
    $SOURCE_EXTERNAL_FILE => 1,
);

my %ALLOWED_CHECKS = (
    $REGEX_FILE       => 1,
    $TRACE_REGEX_FILE => 1,
    $COMPARE          => 1,
    $NONE             => 1
);

#-----------------------------------------------------------------------------
sub new {
    my $type   = shift;
    my $path   = shift;
    my $config = shift;
    my $self   = {};

    bless($self, $type);

    $self->set_is_valid(1);
    $self->set_name(File::Basename::basename($path));
    $self->set_path($path);
    $self->set_config($config);

    if (!$self->is_valid()) {
        my $name = $self->get_name();
        Attes::Message::print_warning("TestSuite '$name' is not valid and will fail.");
    }
    return $self;
}
#-----------------------------------------------------------------------------
sub execute_command
{
    my $self    = shift;
    my $command = shift // '';
    my $dry     = $self->get_config()->get_dry();
    my $result_path = catfile($self->get_path(), $RESULT_FILE_NAME);

    if ($self->get_config()->get_verbose()) {
        Attes::Message::print_test_extra("        $command\n\n");
    }
    if (!$dry) {
        system("$command &> $result_path");
    }
}
#-----------------------------------------------------------------------------
sub run
{
    my $self = shift;

    my $test_name = $self->get_name();
    my $error     = '';

    if (!$self->is_valid()) {
        $error = "Could not run invalid test '$test_name'.";
        goto RETURN;
    }
    my $test_path     = $self->get_path();
    my $command_path  = catfile($self->get_path(), $COMMAND_FILE_NAME);
    my $expected_path = catfile($self->get_path(), $EXPECTED_FILE_NAME);

    if (Attes::File::error_if_file_not_readable($command_path)) {
        $error = "Could not find command file '$command_path' for test '$test_name'.";
        $self->set_is_valid(0);
        goto RETURN;
    }
    if (Attes::File::error_if_file_not_readable($expected_path)) {
        $error = "Could not find command file '$expected_path' for test '$test_name'.";
        $self->set_is_valid(0);
        goto RETURN;
    }
    $self->set_command_params($command_path);

    if (!$self->is_valid()) {
        $error = "Could not run invalid test '$test_name'.";
        goto RETURN;
    }

    $error = $self->execute_test_command();
    if (!$error) {
        $error = $self->check_test_output();
    }

  RETURN:

    return $error;
}
#-----------------------------------------------------------------------------
sub check_test_output
{
    my $self = shift;

    if ($self->get_config()->get_dry()) {
        return '';
    }
    my $exe      = $self->get_exe()     // '';
    my $database = $self->get_database()// '';
    my $action   = $self->get_action()  // '';
    my $file     = $self->get_file()    // '';
    my $check    = $self->get_check()   // '';
    my $error    = '';

    if ($check eq $REGEX_FILE) {
        $error = $self->check_regex_file();
    } elsif ($check eq $TRACE_REGEX_FILE) {
        $error = 'Not implemented';
    } elsif ($check eq $COMPARE) {
        $error = $self->check_compare();
    } elsif ($check eq $NONE) {
        return '';
    }
    return $error;
}
#-----------------------------------------------------------------------------
sub check_regex_file
{
    my $self = shift;

    my $test_path        = $self->get_path();
    my $result_file_path = $self->get_result_file_path();
    my $regex_file_path  = $self->get_expected_file_path();
    my $error_file_path  = $self->get_error_file_path();

    my $errors  = $self->check_regexes_on_file($regex_file_path, $result_file_path);
    my $nerrors = scalar @$errors;

    if ($nerrors > 0) {
        my $ec = save_array_to_file($errors, $error_file_path);
        if ($ec == 0) {
            return "$nerrors error(s) saved to '$error_file_path'";
        } else {
            return "$nerrors error(s) found but unable to save to '$error_file_path'";
        }
    }
    return '';
}
#-----------------------------------------------------------------------------
sub check_compare
{
    my $self = shift;

    my $test_path          = $self->get_path();
    my $result_file_path   = $self->get_result_file_path();
    my $expected_file_path = $self->get_expected_file_path();
    my $error_file_path    = $self->get_error_file_path();

    my $compare         = $self->get_config()->get_compare();
    my $compare_command = "$compare $result_file_path $expected_file_path";
    my $output          = execute_command_and_return_output($compare_command);

    my $nerrors = 1;
    if ($output =~ m/Found\s+(\d+)\s+error/) {
        $nerrors = $1;
    }
    if ($nerrors > 0) {
        my @errors = ($output);
        my $ec = save_array_to_file(\@errors, $error_file_path);
        if ($ec == 0) {
            return "$nerrors error(s) saved to '$error_file_path'";
        } else {
            return "$nerrors error(s) found but unable to save to '$error_file_path'";
        }
    }
    return '';
}
#-----------------------------------------------------------------------------
sub execute_command_and_return_output
{
    my $self    = shift;
    my $command = shift // '';
    my $dry     = $self->get_config()->get_dry();
    my $output  = '';

    if ($self->get_config()->get_verbose()) {
        Attes::Message::print_test_extra("        $command\n\n");
    }
    if (!$dry) {
        $output = `$command 2>&1`;
    }
    return $output;
}
#-----------------------------------------------------------------------------
sub save_array_to_file
{
    my $aref      = shift;
    my $file_path = shift;

    if (-e $file_path) {
        unlink($file_path);
    }
    if (open(my $fd, '>', $file_path)) {
        foreach my $item (@$aref) {
            chomp($item);
            print($fd "$item\n");
        }
        close($fd);
        return 0;
    }
    return 1;
}
#-----------------------------------------------------------------------------
sub execute_test_command
{
    my $self = shift;

    my $verbose  = $self->get_config()->get_verbose();
    my $exe      = $self->get_exe()     // '';
    my $database = $self->get_database()// '';
    my $action   = $self->get_action()  // '';
    my $file     = $self->get_file()    // '';
    my $check    = $self->get_check()   // '';
    my $error    = '';

    if ($verbose) {
        print("\n");
        print("             exe = $exe     \n");
        print("        database = $database\n");
        print("          action = $action  \n");
        if ($action eq $SOURCE_FILE || $action eq $SOURCE_EXTERNAL_FILE) {
            print("            file = $file    \n");
        }
        print("           check = $check   \n");
        print("\n");
    }

    if ($action eq $START_RDBMS) {
            $error = $self->run_start_rdms();

    } elsif ($action eq $STOP_RDBMS) {
        $error = $self->run_stop_rdms();

    } elsif ($action eq $CREATE_DATABASE) {
        $error = $self->run_create_database();

    } elsif ($action eq $DROP_DATABASE) {
        $error = $self->run_drop_database();

    } elsif ($action eq $SOURCE_FILE) {
        my $test_path = $self->get_path();
        my $path = $self->get_file();
        if (!file_name_is_absolute($path)) {
            $path = catfile($test_path, $path);
        }
        $error = $self->run_source_file($path);

    } elsif ($action eq $SOURCE_EXTERNAL_FILE) {
        my $test_path  = $self->get_path();
        my $source_dir = $self->get_config()->get_source_dir_path();
        my $path = $self->get_file();
        if (!file_name_is_absolute($path)) {
            if ($source_dir) {
                $path = catfile($source_dir, $path);
            } else {
                $path = catfile($test_path, $path);
            }
        }
        $error = $self->run_source_file($path);
    }
    return $error;
}
#-----------------------------------------------------------------------------
sub get_start_command
{
    my $self = shift;
    my $command = $self->get_config()->get_rdbms_start();
    return $command;
}
#-----------------------------------------------------------------------------
sub get_stop_command
{
    my $self = shift;
    my $command = $self->get_config()->get_rdbms_stop();
    return $command;
}
#-----------------------------------------------------------------------------
sub get_create_database_command
{
    my $self = shift;

    my $exe       = $self->get_exe();
    my $database  = $self->get_database();

    my $type      = $self->get_config()->get_rdbms_type();
    my $host      = $self->get_config()->get_rdbms_host();
    my $port      = $self->get_config()->get_rdbms_port();
    my $user      = $self->get_user();
    my $password  = $self->get_password();

    my $command   = "$exe";

    if ($type eq $MYSQL) {
        if ($host)     { $command .= " --host $host"; }
        if ($port)     { $command .= " --port $port"; }
        if ($user)     { $command .= " --user $user"; }
        if ($password) { $command .= " --password $password"; }
        $command = "echo \"CREATE DATABASE IF NOT EXISTS $database;\" | $command";

    } elsif ($type eq $POSTGRESQL) {
        if ($host)     { $command .= " --host $host"; }
        if ($port)     { $command .= " --port $port"; }
        if ($user)     { $command .= " --username $user"; }
        if ($password) { $command  = "export PGPASSWORD='$password'; $command"; }
        $command = "$command -c 'CREATE DATABASE IF NOT EXISTS $database;'";

    } else {
        Attes::Message::print_warning("RDBMS $type is not handled for the time being.");
    }
    return $command;
}
#-----------------------------------------------------------------------------
sub get_drop_database_command
{
    my $self = shift;

    my $exe       = $self->get_exe();
    my $database  = $self->get_database();

    my $type      = $self->get_config()->get_rdbms_type();
    my $host      = $self->get_config()->get_rdbms_host();
    my $port      = $self->get_config()->get_rdbms_port();
    my $user      = $self->get_user();
    my $password  = $self->get_password();

    my $command   = "$exe";

    if ($type eq $MYSQL) {
        if ($host)     { $command .= " --host $host"; }
        if ($port)     { $command .= " --port $port"; }
        if ($user)     { $command .= " --user $user"; }
        if ($password) { $command .= " --password $password"; }
        $command = "echo \"DROP DATABASE IF EXISTS $database;\" | $command";
    } elsif ($type eq $POSTGRESQL) {
        if ($host)     { $command .= " --host $host"; }
        if ($port)     { $command .= " --port $port"; }
        if ($user)     { $command .= " --username $user"; }
        if ($password) { $command  = "export PGPASSWORD='$password'; $command"; }
        $command = "$command -c 'DROP DATABASE IF EXISTS $database;'";

    } else {
        Attes::Message::print_warning("RDBMS $type is not handled for the time being.");
    }
    return $command;
}
#-----------------------------------------------------------------------------
sub get_source_file_command
{
    my $self      = shift;
    my $path = shift;

    my $exe       = $self->get_exe();
    my $database  = $self->get_database();

    my $type      = $self->get_config()->get_rdbms_type();
    my $host      = $self->get_config()->get_rdbms_host();
    my $port      = $self->get_config()->get_rdbms_port();
    my $user      = $self->get_user();
    my $password  = $self->get_password();

    my $command   = "$exe";

    if ($type eq $MYSQL) {
        if ($host)     { $command .= " --host $host"; }
        if ($port)     { $command .= " --port $port"; }
        if ($user)     { $command .= " --user $user"; }
        if ($password) { $command .= " --password $password"; }
        if ($database) { $command .= " --database $database"; }
        #
        # Use '--force' to continue processing the file even if an error
        # occured. This makes it possible to check for several (intended)
        # errors.
        #
        $command .= " --force < $path";

    } elsif ($type eq $POSTGRESQL) {
        if ($host)     { $command .= " --host $host"; }
        if ($port)     { $command .= " --port $port"; }
        if ($user)     { $command .= " --username $user"; }
        if ($password) { $command  = "export PGPASSWORD='$password'; $command"; }
        $command = "$command --file $path";

    } else {
        Attes::Message::print_warning("RDBMS $type is not handled for the time being.");
    }
    return $command;
}
#-----------------------------------------------------------------------------
sub run_start_rdms
{
    my $self = shift;
    my $command = $self->get_start_command();
    $self->execute_command($command);
    return '';
}
#-----------------------------------------------------------------------------
sub run_stop_rdms
{
    my $self = shift;
    my $command = $self->get_stop_command();
    $self->execute_command($command);
    return '';
}
#-----------------------------------------------------------------------------
sub run_create_database
{
    my $self = shift;
    my $command = $self->get_create_database_command();
    $self->execute_command($command);
    return '';
}
#-----------------------------------------------------------------------------
sub run_drop_database
{
    my $self = shift;
    my $command = $self->get_drop_database_command();
    $self->execute_command($command);
    return '';
}
#-----------------------------------------------------------------------------
sub run_source_file
{
    my $self = shift;
    my $path = shift;
    if (!-e $path) {
        my $error_file_path = $self->get_error_file_path();
        my $error = "Could not read file $path";
        my $errors = [$error];
        save_array_to_file($errors, $error_file_path);
        return $error;
    }
    my $command = $self->get_source_file_command($path);
    $self->execute_command($command);
    return '';
}
#-----------------------------------------------------------------------------
sub set_command_params
{
    my $self = shift;
    my $command_path = shift;

    my $opened = open(my $fh, '<', $command_path);
    if (!$opened) {
        Attes::Message::print_warning("Could not open command file '$command_path'.");
        return;
    }
    while (my $line = <$fh>) {
        $line =~ s/#.*$//;
        $line = Attes::Utils::trim($line);
        if ($line =~ m/$EXE_FIELD_NAME\s*=\s*(.*)$/i) {
            $self->set_exe($1);
        } elsif ($line =~ m/$DATABASE_FIELD_NAME\s*=\s*(.*)$/i) {
            $self->set_database($1);
        } elsif ($line =~ m/$ACTION_FIELD_NAME\s*=\s*(.*)$/i) {
            $self->set_action($1);
        } elsif ($line =~ m/$CHECK_FIELD_NAME\s*=\s*(.*)$/i) {
           $self->set_check($1);
        } elsif ($line =~ m/$FILE_FIELD_NAME\s*=\s*(.*)$/i) {
           $self->set_file($1);
        } elsif ($line =~ m/$USER_FIELD_NAME\s*=\s*(.*)$/i) {
           $self->set_user($1);
        } elsif ($line =~ m/$PASSWORD_FIELD_NAME\s*=\s*(.*)$/i) {
           $self->set_password($1);
        } elsif ($line =~ m/$IF_FAILS_FIELD_NAME\s*=\s*(.*)$/i) {
           $self->set_if_fails($1);
        }
    }
    my $exe = $self->get_exe();
    if (!$exe) {
        Attes::Message::print_warning("Field 'exe' not specified.");
        $self->set_is_valid(0);
    }
    my $action = $self->get_action();
    if (!$action) {
        Attes::Message::print_warning("Field 'action' not specified.");
        $self->set_is_valid(0);
    }
    if ($action ne $START_RDBMS && $action ne $STOP_RDBMS) {
        my $database = $self->get_database();
        if (!$database) {
            Attes::Message::print_warning("Field 'database' not specified.");
            $self->set_is_valid(0);
        }
    }
    my $check = $self->get_check();
    if (!$check) {
        Attes::Message::print_warning("Field 'check' not specified.");
        $self->set_is_valid(0);
    }
    my $path = $self->get_file();
    if (!$path) {
        $self->set_file($QUERY_FILE_NAME);
    }
    my $user = $self->get_user();
    if (!$user) {
        $self->set_user($self->get_config()->get_rdbms_user());
    }
    my $password = $self->get_password();
    if (!$password) {
        $self->set_password($self->get_config()->get_rdbms_password());
    }
    close($fh);
}
#-----------------------------------------------------------------------------
sub set_if_fails
{
    my $self = shift;
    my $action = shift;

    $self->{'if_fails'} = $IF_FAILS_DEFAULT;

    if ($action =~ m/$REGEX_CONTINUE/) {
        $self->{'if_fails'} = $CONTINUE;
    } elsif ($action =~ m/$REGEX_STOP/) {
        $self->{'if_fails'} = $STOP;
    } elsif ($action =~ m/$REGEX_JUMP_TO\s+(.*)$/) {
        $self->{'if_fails'} = $JUMP_TO;
    } elsif ($action =~ m/$REGEX_EXIT\s+(.*)$/) {
        $self->{'if_fails'} = $EXIT;
    }
    if ($self->{'if_fails'} eq $CONTINUE) {
        $self->set_continue_if_fails(1);
        $self->set_exit_if_fails(0);
    } elsif ($self->{'if_fails'} eq $STOP) {
        $self->set_continue_if_fails(0);
        $self->set_exit_if_fails(0);
    } elsif ($self->{'if_fails'} eq $JUMP_TO) {
        $self->set_continue_if_fails(1);
        $self->set_exit_if_fails(0);
        $self->set_next_test_if_fails($1);
    } elsif ($self->{'if_fails'} eq $EXIT) {
        $self->set_continue_if_fails(0);
        $self->set_exit_if_fails(1);
    }
}
#-----------------------------------------------------------------------------
sub set_next_test_if_fails
{
    my $self = shift;
    my $next = shift // '';
    $self->{'next_test_if_fails'} = $next;
}
#-----------------------------------------------------------------------------
sub get_next_test_if_fails
{
    my $self = shift;
    return $self->{'next_test_if_fails'} // '';
}
#-----------------------------------------------------------------------------
sub set_user
{
    my $self = shift;
    my $user = shift // $self->get_config()->get_rdbms_user();
    if (ref $user) {
        $self->{'user'} = '';
    } else {
        $self->{'user'} = $user;
    }
}
#-----------------------------------------------------------------------------
sub get_user
{
    my $self = shift;
    return $self->{'user'};
}
#-----------------------------------------------------------------------------
sub set_password
{
    my $self = shift;
    my $password = shift // $self->get_config()->get_rdbms_password();
    if (ref $password) {
        $self->{'password'} = '';
    } else {
        $self->{'password'} = $password;
    }
}
#-----------------------------------------------------------------------------
sub get_password
{
    my $self = shift;
    return $self->{'password'};
}
#-----------------------------------------------------------------------------
sub set_exit_if_fails
{
    my $self = shift;
    my $exit = shift;
    $self->{'exit_if_fails'} = ($exit ? 1 : 0);
}
#-----------------------------------------------------------------------------
sub should_exit_if_fails
{
    my $self = shift;
    if (!defined $self->{'exit_if_fails'}) {
        $self->set_if_fails($IF_FAILS_DEFAULT);
    }
    return ($self->{'exit_if_fails'} ? 1 : 0);
}
#-----------------------------------------------------------------------------
sub set_continue_if_fails
{
    my $self = shift;
    my $continue = shift // 0;
    $self->{'continue_if_fails'} = ($continue ? 1 : 0);
}
#-----------------------------------------------------------------------------
sub should_continue_if_fails
{
    my $self = shift;
    if (!defined $self->{'continue_if_fails'}) {
        $self->set_if_fails($IF_FAILS_DEFAULT);
    }
    return ($self->{'continue_if_fails'} ? 1 : 0);
}
#-----------------------------------------------------------------------------
sub set_is_valid
{
    my $self = shift;
    my $is_valid = shift;
    $self->{'is_valid'} = $is_valid;
}
#-----------------------------------------------------------------------------
sub is_valid
{
    my $self = shift;
    return $self->{'is_valid'};
}
#-----------------------------------------------------------------------------
sub set_config
{
    my $self = shift;
    my $config = shift;
    $self->{'config'} = $config;
}
#-----------------------------------------------------------------------------
sub get_config
{
    my $self = shift;
    return $self->{'config'};
}
#-----------------------------------------------------------------------------
sub set_exe
{
    my $self = shift;
    my $exe = shift;
    $self->{$EXE_FIELD_NAME} = $exe;
}
#-----------------------------------------------------------------------------
sub get_exe
{
    my $self = shift;
    return $self->{$EXE_FIELD_NAME};
}
#-----------------------------------------------------------------------------
sub set_database
{
    my $self = shift;
    my $database = shift;
    $self->{$DATABASE_FIELD_NAME} = $database;
}
#-----------------------------------------------------------------------------
sub get_database
{
    my $self = shift;
    return $self->{$DATABASE_FIELD_NAME};
}
#-----------------------------------------------------------------------------
sub set_action
{
    my $self   = shift;
    my $action = shift // '';

    if (!exists $ALLOWED_ACTIONS{$action}) {
        Attes::Message::print_warning("Invalid action '$action'.");
        $self->set_is_valid(0);
    }
    $self->{$ACTION_FIELD_NAME} = $action;
}
#-----------------------------------------------------------------------------
sub get_action
{
    my $self = shift;
    return $self->{$ACTION_FIELD_NAME};
}
#-----------------------------------------------------------------------------
sub set_check
{
    my $self  = shift;
    my $check = shift // '';
    if (!exists $ALLOWED_CHECKS{$check}) {
        Attes::Message::print_warning("Invalid check '$check'.");
        $self->set_is_valid(0);
    }
    $self->{$CHECK_FIELD_NAME} = $check;
}
#-----------------------------------------------------------------------------
sub get_check
{
    my $self = shift;
    return $self->{$CHECK_FIELD_NAME};
}
#-----------------------------------------------------------------------------
sub set_file
{
    my $self = shift;
    my $file = shift;
    $self->{$FILE_FIELD_NAME} = $file;
}
#-----------------------------------------------------------------------------
sub get_file
{
    my $self = shift;
    return $self->{$FILE_FIELD_NAME};
}
#-----------------------------------------------------------------------------
sub set_name
{
    my $self = shift;
    my $name = shift;
    $self->{'name'} = $name;
}
#-----------------------------------------------------------------------------
sub get_name
{
    my $self = shift;
    return $self->{'name'};
}
#-----------------------------------------------------------------------------
sub set_path
{
    my $self = shift;
    my $path = shift;

    $self->{'path'} = $path;

    if (Attes::File::error_if_directory_not_readable($path)) {
        my $name = $self->get_name();
        $self->set_is_valid(0);
        Attes::Message::print_warning("Test $name does not exist.")
    }
}
#-----------------------------------------------------------------------------
sub get_path
{
    my $self = shift;
    return $self->{'path'};
}
#-----------------------------------------------------------------------------
sub get_result_file_path
{
    my $self = shift;
    my $test_path = $self->get_path();
    my $result_file_path = catfile($test_path, $RESULT_FILE_NAME);
    return $result_file_path;
}
#-----------------------------------------------------------------------------
sub get_expected_file_path
{
    my $self = shift;
    my $test_path = $self->get_path();
    my $expected_file_path = catfile($test_path, $EXPECTED_FILE_NAME);
    return $expected_file_path;
}
#-----------------------------------------------------------------------------
sub get_error_file_path
{
    my $self = shift;
    my $test_path = $self->get_path();
    my $error_file_path = catfile($test_path, $ERROR_FILE_NAME);
    return $error_file_path;
}
#-----------------------------------------------------------------------------
sub check_regexes_on_file
{
    my $self          = shift;
    my $regexes_file  = shift;
    my $file_to_check = shift;

    my @errors  = ();
    my $verbose = $self->get_config()->get_verbose();
    my @lines   = read_file($file_to_check, err_mode => 'quiet');
    my $content = join('', @lines);

    if ($verbose) {
        Attes::Message::print_test_extra("        checking regexes from '$regexes_file' on file '$file_to_check'\n");
    }
    if (open(my $fd, '<', $regexes_file)) {
        while (my $line = <$fd>) {
            next if ($line =~ m/^\s*$/);  # skip empty lines
            next if ($line =~ m/^\s*\#/); # skip comments


            $line = Attes::Utils::trim($line);

            if ($line =~ m/^\s*((content_|line_)?should_(not_)?match)\s*[:=]\s*(.*)$/i) {
                my $criterion = $1;
                my $context_is_content = 1;
                if ($2 && $2 eq 'line_') {
                    $context_is_content = 0;
                }
                my $should_match = 1;
                if ($3 && $3 eq 'not_') {
                    $should_match = 0;
                }
                my $regex = Attes::Utils::trim($4);
                my $ok = 1;
                my $match = 0;

                if ($context_is_content) {
                    $match = ($content =~ m/$regex/) ? 1 : 0;
                } else {
                    foreach my $line (@lines) {
                        if ($line =~ m/$regex/) {
                            $match = 1;
                            last;
                        }
                    }
                }
                if ($should_match) {
                    if (!$match) {
                        $ok = 0;
                        push(@errors, "File $file_to_check does not satisfy: $criterion ($regex)\n");
                    }
                } else {
                    if ($match) {
                        $ok = 0;
                        push(@errors, "File $file_to_check does not satisfy: $criterion ($regex)\n");
                    }
                }
                if ($verbose) {
                    if ($ok) {
                        Attes::Message::print_success("            [v]");
                    } else {
                        Attes::Message::print_failure("            [X]");
                    }
                    Attes::Message::print_test_extra(" $criterion: $regex\n");
                }
            }
        }
        close($fd);
    } else {
        push(@errors, "Could not open file $file_to_check\n");
    }
    print("\n") if ($verbose);

    return \@errors;
}
#-----------------------------------------------------------------------------
sub get_allowed_rdbms_hash
{
    my %allowed_rdbms = %ALLOWED_RDBMS;
    return \%allowed_rdbms;
}
#-----------------------------------------------------------------------------

1;

__END__
