package Attes::Conf;

use strict;
use warnings;

use Carp;

use Attes::File;
use Attes::Message;
use Attes::Utils;
use Config::Simple;
use File::Basename;
use File::Spec::Functions;

require Exporter;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ('all' => [@EXPORT_OK]);
our $VERSION     = '0.1';

my $SECTION_ATTES   = 'attes';
my $SECTION_SUITES  = 'suites';
my $SECTION_RDBMS   = 'rdbms';
my $SECTION_COLORS  = 'colors';

my $DRY_FIELD        = "$SECTION_ATTES.dry";
my $VERBOSE_FIELD    = "$SECTION_ATTES.verbose";
my $USE_COLORS_FIELD = "$SECTION_COLORS.use_colors";
my $TYPE_FIELD       = "$SECTION_RDBMS.type";
my $HOST_FIELD       = "$SECTION_RDBMS.host";
my $PORT_FIELD       = "$SECTION_RDBMS.port";
my $USER_FIELD       = "$SECTION_RDBMS.user";
my $PASSWORD_FIELD   = "$SECTION_RDBMS.password";
my $START_FIELD      = "$SECTION_RDBMS.command.start";
my $STOP_FIELD       = "$SECTION_RDBMS.command.stop";

my %MANDATORY_FIELDS = (
    $TYPE_FIELD      => 1,
    $HOST_FIELD      => 1,
    $PORT_FIELD      => 1,
    $USER_FIELD      => 1,
    $PASSWORD_FIELD  => 1,
    $START_FIELD     => 1,
    $STOP_FIELD      => 1,
);

my %DEFAULT_VALUES = (
    $DRY_FIELD          => 0,
    $VERBOSE_FIELD      => 0,
    $USE_COLORS_FIELD   => 1,
);

#-----------------------------------------------------------------------------
sub new {
    my $type = shift;
    my $path = shift;
    my $self = {};

    bless($self, $type);

    $self->set_path($path);
    $self->set_default_values();
    $self->load_from_configuration_file();

    return $self;
}
#-----------------------------------------------------------------------------
sub set_default_values
{
    my $self = shift;
    foreach my $key (keys %DEFAULT_VALUES) {
        my $value = $DEFAULT_VALUES{$key};
        $self->{$key} = $value;
    }
}
#-----------------------------------------------------------------------------
sub load_from_configuration_file
{
    my $self = shift;
    my $config_file_path = $self->get_path();
    my $config = {};

    Config::Simple->import_from($config_file_path, $config);

    my $error = Config::Simple->error();
    if ($error) {
        $self->add_error("Could not read configuration file $config_file_path\n$error");
    }
    for my $field (keys %MANDATORY_FIELDS) {
        if (!exists $config->{$field}) {
            $self->add_error("Mandatory field $field missing in configuration file $config_file_path");
        }
    }
    $config->{$TYPE_FIELD} = lc($config->{$TYPE_FIELD});

    foreach my $key (keys %$config) {
        my $value = $config->{$key};
        $self->{$key} = $value;
    }
}
#-----------------------------------------------------------------------------
sub set_path
{
    my $self = shift;
    my $path = shift // '';
    $self->{'path'} = $path;
}
#-----------------------------------------------------------------------------
sub get_path
{
    my $self = shift;
    my $path = $self->{'path'} // '';
    return $path;
}
#-----------------------------------------------------------------------------
sub set_suite_dir_path
{
    my $self = shift;
    my $suite_dir_path = shift // '';
    $self->{"$SECTION_ATTES.suite_dir_path"} = $suite_dir_path;
}
#-----------------------------------------------------------------------------
sub get_suite_dir_path
{
    my $self = shift;
    return $self->{"$SECTION_ATTES.suite_dir_path"};
}
#-----------------------------------------------------------------------------
sub set_source_dir_path
{
    my $self = shift;
    my $source_dir_path = shift // '';
    $self->{"$SECTION_ATTES.source_dir_path"} = $source_dir_path;
}
#-----------------------------------------------------------------------------
sub get_source_dir_path
{
    my $self = shift;
    return $self->{"$SECTION_ATTES.source_dir_path"};
}
#-----------------------------------------------------------------------------
sub set_verbose
{
    my $self = shift;

    my $field   = "$SECTION_ATTES.verbose";
    my $verbose = shift // $DEFAULT_VALUES{$field};

    $self->{$field} = ($verbose ? 1 : 0);
}
#-----------------------------------------------------------------------------
sub get_verbose
{
    my $self = shift;
    return $self->{"$SECTION_ATTES.verbose"};
}
#-----------------------------------------------------------------------------
sub set_use_colors
{
    my $self = shift;

    my $field   = "$SECTION_COLORS.use_colors";
    my $use_colors = shift // $DEFAULT_VALUES{$field};

    $self->{"$SECTION_COLORS.use_colors"} = ($use_colors ? 1 : 0);
}
#-----------------------------------------------------------------------------
sub get_use_colors
{
    my $self = shift;
    return $self->{"$SECTION_COLORS.use_colors"};
}
#-----------------------------------------------------------------------------
sub set_dry
{
    my $self = shift;

    my $field = "$SECTION_ATTES.dry";
    my $dry   = shift // $DEFAULT_VALUES{$field};

    $self->{"$SECTION_ATTES.dry"} = ($dry ? 1 : 0);
}
#-----------------------------------------------------------------------------
sub get_dry
{
    my $self = shift;
    return $self->{"$SECTION_ATTES.dry"};
}
#-----------------------------------------------------------------------------
sub get_rdbms_type
{
    my $self = shift;
    return $self->{$TYPE_FIELD};
}
#-----------------------------------------------------------------------------
sub set_rdbms_type
{
    my $self = shift;
    my $type = shift;
    $self->{$TYPE_FIELD} = $type;
}
#-----------------------------------------------------------------------------
sub get_rdbms_host
{
    my $self = shift;
    return $self->{$HOST_FIELD};
}
#-----------------------------------------------------------------------------
sub set_rdbms_host
{
    my $self = shift;
    my $host = shift // '';
    $self->{$HOST_FIELD} = $host;
}
#-----------------------------------------------------------------------------
sub get_rdbms_port
{
    my $self = shift;
    return $self->{$PORT_FIELD};
}
#-----------------------------------------------------------------------------
sub set_rdbms_port
{
    my $self = shift;
    my $port = shift // '';
    $self->{$PORT_FIELD} = $port;
}
#-----------------------------------------------------------------------------
sub get_rdbms_user
{
    my $self = shift;
    return $self->{$USER_FIELD};
}
#-----------------------------------------------------------------------------
sub set_rdbms_user
{
    my $self = shift;
    my $user = shift // '';
    $self->{$USER_FIELD} = $user;
}
#-----------------------------------------------------------------------------
sub get_rdbms_password
{
    my $self = shift;
    return $self->{$PASSWORD_FIELD};
}
#-----------------------------------------------------------------------------
sub set_rdbms_password
{
    my $self = shift;
    my $password = shift // '';
    $self->{$PASSWORD_FIELD} = $password;
}
#-----------------------------------------------------------------------------
sub get_rdbms_start
{
    my $self = shift;
    return $self->{$START_FIELD};
}
#-----------------------------------------------------------------------------
sub set_rdbms_start
{
    my $self  = shift;
    my $start = shift // '';
    $self->{$START_FIELD} = $start;
}
#-----------------------------------------------------------------------------
sub get_rdbms_stop
{
    my $self = shift;
    return $self->{$STOP_FIELD};
}
#-----------------------------------------------------------------------------
sub set_rdbms_stop
{
    my $self = shift;
    my $stop = shift // '';
    $self->{$STOP_FIELD} = $stop;
}
#-----------------------------------------------------------------------------
sub get_compare
{
    my $self = shift;
    return $self->{"$SECTION_ATTES.compare"};
}
#-----------------------------------------------------------------------------
sub set_compare
{
    my $self = shift;
    my $compare = shift // '';
    $self->{"$SECTION_ATTES.compare"} = $compare;
}
#-----------------------------------------------------------------------------
sub get_errors
{
    my $self = shift;
    return $self->{'errors'};
}
#-----------------------------------------------------------------------------
sub add_error
{
    my $self = shift;
    my $error = shift;
    push(@{$self->{'errors'}}, $error);
}
#-----------------------------------------------------------------------------
sub set_errors
{
    my $self = shift;
    my $errors_aref = shift // '';
    if (ref($errors_aref) eq 'ARRAY') {
        $self->{'errors'} = $errors_aref;
    } else {
        $self->{'errors'} = [];
    }
}
#-----------------------------------------------------------------------------
sub get_test_suites
{
    my $self = shift;

    my $suites = {};
    my @mandatory_fields = ('path', 'priority');

    foreach my $key (keys %$self) {
        my $value = $self->{$key};
        if ($key =~ m/^$SECTION_SUITES\.([^\.]+)\.([^\.]+)$/) {
            my $name = $1;
            my $field = $2;
            $suites->{$name}->{$field} = $value;
        }
    }
    my $config_file_path = $self->get_path();
    foreach my $name (keys %$suites) {
        for my $field (@mandatory_fields) {
            if (!exists $suites->{$name}->{$field}) {
                Attes::Message::fatal_error("Mandatory field $SECTION_SUITES.$name.$field missing in configuration file $config_file_path");
            }
        }
    }
    return $suites;
}
#-----------------------------------------------------------------------------
sub get_suite_path
{
    my $self = shift;
    my $name = shift // '';
    return $self->{"$SECTION_SUITES.$name.path"} // '';
}
#-----------------------------------------------------------------------------
sub get_suite_priority
{
    my $self = shift;
    my $name = shift // '';
    return $self->{"$SECTION_SUITES.$name.priority"} // (1 << 31);
}
#-----------------------------------------------------------------------------

1;

__END__
