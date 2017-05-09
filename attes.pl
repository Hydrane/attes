#!/usr/bin/perl -w

use strict;
use warnings 'FATAL';

use Attes::File;
use Attes::Message;
use Attes::TestSuite;

use Config::Simple;
use Data::Dumper;
use File::Basename;
use File::Spec::Functions;
use Getopt::Long;
use POSIX;
use Term::ANSIColor qw(:constants);

local $Term::ANSIColor::AUTORESET = 1;

my $NAME = 'attes';
my $SEPARATOR = "-" x 78;

my $DEFAULT_CONFIG_FILE_PATH = 'attes.conf';
my $DEFAULT_PREFIX = '.';
my $DEFAULT_SOURCE_DIR = '.';
my $DEFAULT_DRY = 0;

my $config_file_path = $DEFAULT_CONFIG_FILE_PATH;
my $suite_dir  = undef;
my $dry        = undef;
my $source_dir = undef;
my $verbose    = undef;
my $use_colors = undef;
my $help       = 0;

GetOptions(
    'c|config=s'   => \$config_file_path,
    'dry|d'        => \$dry,
    'suitedir|t=s' => \$suite_dir,
    'srcdir|s=s'   => \$source_dir,
    'verbose|v'    => \$verbose,
    'colors!'      => \$use_colors,
    'help|h'       => \$help
) or die("$!\n");

my $config = process_options_and_exit_if_error();
my $suites = get_test_suites($config);
my @suite_names_to_run = (sort {$suites->{$a}->{'priority'} <=> $suites->{$b}->{'priority'}} keys %$suites);
my $suite_count = scalar @suite_names_to_run;
my $failed_suite_count = 0;
my $suite_no = 0;

print_intro_message(\@suite_names_to_run);
foreach my $name (@suite_names_to_run) {
    my $suite = Attes::TestSuite->new($name, $suites->{$name}->{'path'}, $config);
    $suite_no++;
    print_suite_header($suite_no, $suite_count, $name);
    my ($test_count, $failed_test_count) = $suite->run();
    if ($failed_test_count > 0) {
        $failed_suite_count++;
        Attes::Message::print_failure("\n>> Test suite '$name' failed");
        if ($suite->should_exit_if_fails()) {
            Attes::Message::print_failure("\n>> Will not perform further testing");
            last;
        }
    }
}
print_summary($suite_count, $failed_suite_count);

if ($verbose) {
    display_configuration($config);
}
exit(0);

#------------------------------------------------------------------------------
sub print_help
{
    my $name  = basename($0);
    my $title = "$name - A Test Tool Ersatz for SQL";
    my $line  = '-' x length($title);
    print << "EOF";

$title
$line
    Attes is a basic, toy-framework to test SQL statements.

Usage:

    $name [options] <suite1 suite2 ... suiteN>

Arguments:

    The list of test suites to run. If not provided, all suites mentioned
    in the configuration file will be run.

Available options:

  -c, --config <path>
      Path to the configuration file.
      Default: $DEFAULT_CONFIG_FILE_PATH.

  -d, --dry
      Dry run: only list the test suites that would be run.

  --no-colors
      Do not colorize the output.

  -s, --srcdir <path>
      Path to the directory holding additional SQL files to test.

  -t, --suitedir <path>
      Path to the directory holding the test suites.
      Default: current directory.

  -v, --verbose
      Display additional information.

  -h, --help
      Print this help message.

EOF
    return 1;
}
#-----------------------------------------------------------------------------
sub display_configuration
{
    my $config = shift // {};
    print("\n");
    print("Test suites run with following configuration\n");
    print("--------------------------------------------\n");
    for my $key (sort keys %$config) {
        my $value = $config->{$key};
        printf("%28s = $value\n", $key);
    }
    return 1;
}
#-----------------------------------------------------------------------------
sub print_intro_message
{
    my $suite_names_aref = shift;
    my $suite_count = scalar @$suite_names_aref;

    Attes::Message::print_suite_info("$SEPARATOR\n");
    if ($dry) {
        Attes::Message::print_suite_info("[Dry run] $suite_count test suite(s) to run:\n");
    } else {
        Attes::Message::print_suite_info("$suite_count test suite(s) to run:\n");
    }
    Attes::Message::print_suite_info("$SEPARATOR\n");
    for (my $i = 1; $i <= $suite_count; $i++) {
        my $name = $$suite_names_aref[$i-1];
        Attes::Message::print_suite_info("    [$i] suite '$name'\n");
    }
    print("\n");
    return 1;
}
#-----------------------------------------------------------------------------
sub print_summary
{
    my $suite_count = shift;
    my $failed_suite_count = shift;
    if (!$dry) {
        Attes::Message::print_suite_info("\n$SEPARATOR\n");
        Attes::Message::print_suite_info("Ran $suite_count test suites\n");
        if ($failed_suite_count == 0) {
            Attes::Message::print_success(">>  All test suites ran successfully\n");
        } else {
            Attes::Message::print_failure(">> $failed_suite_count test suites failed\n");
        }
    }
    return 1;
}
#-----------------------------------------------------------------------------
sub print_suite_header
{
    my $suite_no = shift;
    my $suite_count = shift;
    my $suite_name = shift;

    Attes::Message::print_suite_header("$SEPARATOR\n");
    if ($dry) {
        Attes::Message::print_suite_header("[Dry run] [Suite $suite_no/$suite_count] Would run test suite '$suite_name'\n");
    } else {
        Attes::Message::print_suite_header("[Suite $suite_no/$suite_count] Running test suite '$suite_name'\n");
    }
    Attes::Message::print_suite_header("$SEPARATOR\n");
    return 1;
}
#-----------------------------------------------------------------------------
sub exit_if_file_not_readable
{
    my $filename = shift;
    my $error = Attes::File::error_if_file_not_readable($filename);
    if ($error) {
        Attes::Message::fatal_error($error);
    }
    return 1;
}
#-----------------------------------------------------------------------------
sub exit_if_directory_not_readable
{
    my $dirname = shift;
    my $error = Attes::File::error_if_directory_not_readable($dirname);
    if ($error) {
        Attes::Message::fatal_error($error);
    }
    return 1;
}
#-----------------------------------------------------------------------------
sub process_options_and_exit_if_error
{
    if ($help) {
        print_help();
        exit(-1);
    }
    exit_if_file_not_readable($config_file_path);

    $config = Attes::Conf->new($config_file_path);
    my $errors = $config->get_errors();
    if ($errors) {
        if (ref($errors) eq 'ARRAY') {
            my $count = scalar @$errors;
            my $message = "Found $count error(s) while loading configuration:\n";
            foreach my $error (@$errors) {
                $message .= "$error\n";
            }
            Attes::Message::fatal_error($message);
        } else {
            Attes::Message::fatal_error("Could not load configuration.");
        }
    }
    if ($suite_dir) {
        exit_if_directory_not_readable($suite_dir);
    } else {
        $suite_dir = $DEFAULT_PREFIX;
    }
    $suite_dir = File::Spec::Functions::rel2abs($suite_dir);

    if ($source_dir) {
        exit_if_directory_not_readable($source_dir);
    } else {
        $source_dir = $DEFAULT_SOURCE_DIR;
    }
    $source_dir = File::Spec::Functions::rel2abs($source_dir);

    if (defined $suite_dir)  { $config->set_suite_dir_path($suite_dir) };
    if (defined $source_dir) { $config->set_source_dir_path($source_dir) };
    if (defined $dry)        { $config->set_dry($dry); }
    if (defined $verbose)    { $config->set_verbose($verbose); }
    if (defined $use_colors) { $config->set_use_colors($use_colors); }

    $suite_dir  = $config->get_suite_dir_path();
    $source_dir = $config->get_source_dir_path();
    $dry        = $config->get_dry();
    $verbose    = $config->get_verbose();
    $use_colors = $config->get_use_colors();

    my $type = $config->get_rdbms_type();
    my $allowed_rdbms = Attes::Test::get_allowed_rdbms_hash();

    if (!exists $allowed_rdbms->{$type}) {
        Attes::Message::fatal_error("Unknown RDBMS type $type.");
    }
    Attes::Message::use_color($use_colors);
    Attes::Message::set_message_colors($config);

    return $config;
}
#-----------------------------------------------------------------------------
sub get_test_suites
{
    my $config = shift;

    my $suites = $config->get_test_suites();
    my %suite_names_to_run = ();

    if (scalar @ARGV == 0) {
        @suite_names_to_run{keys %$suites} = (1) x (keys %$suites);
    } else {
        @suite_names_to_run{@ARGV} = (1) x (@ARGV);
    }
    foreach my $suite (keys %$suites) {
        if (!exists $suite_names_to_run{$suite}) {
            delete $suites->{$suite};
            next;
        }
        my $path = $suites->{$suite}->{'path'};
        if (!file_name_is_absolute($path)) {
            $path = catfile($suite_dir, $path);
        }
        my $error = Attes::File::error_if_directory_not_readable($path);
        if ($error) {
            Attes::Message::fatal_error("Test directory $path does not exists.");
        }
        $suites->{$suite}->{'path'} = $path;
    }
    foreach my $suite (@ARGV) {
        if (!exists $suites->{$suite}) {
            Attes::Message::print_warning("Ignoring unspecified test suite '$suite'.");
        }
    }
    return $suites;
}
#-----------------------------------------------------------------------------


