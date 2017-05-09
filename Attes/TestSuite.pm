package Attes::TestSuite;

use strict;
use warnings;

use Carp;

use Attes::Conf;
use Attes::File;
use Attes::Message;
use Attes::Test;
use Attes::Utils;
use File::Spec::Functions;
use IO::Handle;
use Term::ANSIColor qw(:constants);
use Time::HiRes;

require Exporter;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ('all' => [@EXPORT_OK]);
our $VERSION     = '0.1';

my $TEST_LIST_FILE_NAME   = 'tests.txt';
my $DEFAULT_EXIT_IF_FAILS = 0;

#-----------------------------------------------------------------------------
sub new {
    my $type       = shift;
    my $name       = shift;
    my $suite_path = shift;
    my $config     = shift;
    my $self       = {};

    bless($self, $type);

    $self->set_is_valid(1);
    $self->set_name($name);
    $self->set_suite_path($suite_path);
    $self->set_config($config);
    $self->set_test_names();

    if (!$self->is_valid()) {
        Attes::Message::print_warning("TestSuite '$name' is not valid and will fail.");
    }
    return $self;
}
#-----------------------------------------------------------------------------
sub run
{
    my $self = shift;
    my $name = $self->get_name();
    if (!$self->is_valid()) {
        Attes::Message::print_error("TestSuite '$name' failed!");
        return;
    }
    my $verbose = $self->get_config()->get_verbose();
    my $tests = $self->get_test_names();
    my $test_count = scalar @$tests;
    my $test_no = 1;
    my $failed_test_count = 0;
    my $jump_to_next_test = 0;
    my $next_test_name = '';

    Attes::Message::print_suite_info("    Suite '$name' consists in $test_count test(s).\n");
    foreach my $test (@$tests) {
        Attes::Message::print_suite_info("        [$test_no] test $test\n");
        $test_no++;
    }
    print("\n");
    $test_no = 0;

    foreach my $test_name (@$tests) {

        $test_no++;

        if ($jump_to_next_test && $test_name ne $next_test_name) {
            next;
        } else {
            $jump_to_next_test = 0;
        }
        Attes::Message::print_suite_number("    [$test_no/$test_count]");
        print(" Test '$test_name'...");
        print("\n") if ($verbose);
        STDOUT->flush();

        my $test_path = catfile($self->get_suite_path(), $test_name);
        my $test = new Attes::Test($test_path, $self->get_config());
        my $error = $test->run();

        if ($verbose) {
            Attes::Message::print_suite_number("    [$test_no/$test_count]");
            print(" Test '$test_name'...");
        }
        if ($error) {
            $failed_test_count++;
            my $result_file_path = $test->get_result_file_path();
            my $error_file_path = $test->get_error_file_path();

            Attes::Message::print_failure(" FAIL\n");
            Attes::Message::print_failure("           Result file: ");
            print("$result_file_path\n");
            Attes::Message::print_failure("           Error file:  ");
            print("$error_file_path\n");

            if ($test->should_exit_if_fails()) {
                $self->set_exit_if_fails(1);
            }
            last if (!$test->should_continue_if_fails());

            if ($test->get_next_test_if_fails()) {
                $jump_to_next_test = 1;
                $next_test_name = $test->get_next_test_if_fails();
            }

        } else {
            Attes::Message::print_success(" OK\n");
        }
    }
    return ($test_count, $failed_test_count);
}
#-----------------------------------------------------------------------------
sub get_test_names
{
    my $self = shift;
    return $self->{'test_names'};
}
#-----------------------------------------------------------------------------
sub set_test_names
{
    my $self = shift;
    my $test_list_path = catfile($self->get_suite_path(), $TEST_LIST_FILE_NAME);

    $self->{'test_names'} = [];

    if (Attes::File::error_if_file_not_readable($test_list_path)) {
        $self->set_is_valid(0);
        Attes::Message::print_warning("Could not read test list '$test_list_path'.");
        return;
    }
    my $opened = open(my $fh, '<', $test_list_path);
    if (!$opened) {
        Attes::Message::print_warning("Could not open test list '$test_list_path'.");
        return;
    }
    my $suite_name = $self->get_name();

    while (my $test_name = <$fh>) {
        $test_name =~ s/#.*$//;
        $test_name = Attes::Utils::trim($test_name);
        if ($test_name) {
            my $test_path = catfile($self->get_suite_path(), $test_name);
            if (Attes::File::error_if_directory_not_readable($test_path)) {
                Attes::Message::print_warning("Could not find test '$test_name' from suite '$suite_name'.");
                $self->set_is_valid(0);
                next;
            }
            push(@{$self->{'test_names'}}, $test_name);
        }
    }
    close($fh);
}
#-----------------------------------------------------------------------------
sub set_exit_if_fails
{
    my $self = shift;
    my $exit_if_fails = shift;
    $self->{'exit_if_fails'} = ($exit_if_fails ? 1 : 0);
}
#-----------------------------------------------------------------------------
sub should_exit_if_fails
{
    my $self = shift;
    return $self->{'exit_if_fails'} // $DEFAULT_EXIT_IF_FAILS;
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
sub set_suite_path
{
    my $self = shift;
    my $path = shift;
    $self->{'suite_path'} = $path;

    if (Attes::File::error_if_directory_not_readable($path)) {
        $self->set_is_valid(0);
        Attes::Message::print_warning("Test suite path $path does not exist.")
    }
}
#-----------------------------------------------------------------------------
sub get_suite_path
{
    my $self = shift;
    return $self->{'suite_path'};
}
#-----------------------------------------------------------------------------

1;

__END__
