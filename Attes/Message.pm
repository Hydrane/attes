package Attes::Message;

use strict;
use warnings;

use Carp;
use Term::ANSIColor 4.00 qw(:constants colorstrip);

require Exporter;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(use_color colorize print_debug print_warning print_stage fatal_error term_length);
our %EXPORT_TAGS = ('all' => [@EXPORT_OK]);
our $VERSION     = '0.1';

local $Term::ANSIColor::AUTORESET = 1;

our $COLOR_STAGE   = 'yellow';
our $COLOR_NONE    = 'rgb422';
our $COLOR_UNKNOWN = 'rgb422';
our $COLOR_WARNING = 'rgb311';
our $COLOR_DEBUG   = 'rgb135';
our $COLOR_ERROR   = 'rgb511';
our $WINDOW_WIDTH  = 78;
our $colorize_msg  = 1;

our %message_colors = (
    'success'      => 'rgb242',
    'failure'      => 'rgb411',
    'suite_info'   => 'rgb124',
    'suite_header' => 'rgb441',
    'suite_number' => 'rgb441',
    'test_extra'   => 'rgb111',
);

#-----------------------------------------------------------------------------
sub use_color
{
    my $use_color = shift // 0;
    $colorize_msg = ($use_color != 0);
}
#-----------------------------------------------------------------------------
sub colorize
{
    my $msg   = shift;
    my $color = shift;
    if ($colorize_msg) {
        return Term::ANSIColor::colored($msg, $color);
    } else {
        return $msg;
    }
}
#-----------------------------------------------------------------------------
sub set_message_colors
{
    my $config = shift;
    foreach my $color (keys %message_colors) {
        next if (!defined $config->{"colors.$color"});
        if ($config->{"colors.$color"} =~ m/^\s*(rgb)?(\d\d\d)s*$/) {
            $message_colors{$color} = "rgb$2";
        }
    }
}
#-----------------------------------------------------------------------------
sub print_success
{
    my $message = shift // '';
    my $color   = $message_colors{'success'};
    print(Attes::Message::colorize($message, $color));
}
#-----------------------------------------------------------------------------
sub print_failure
{
    my $message = shift // '';
    my $color   = $message_colors{'failure'};
    print(Attes::Message::colorize($message, $color));
}
#-----------------------------------------------------------------------------
sub print_suite_info
{
    my $message = shift // '';
    my $color   = $message_colors{'suite_info'};
    print(Attes::Message::colorize($message, $color));
}
#-----------------------------------------------------------------------------
sub print_suite_header
{
    my $message = shift // '';
    my $color   = $message_colors{'suite_header'};
    print(Attes::Message::colorize($message, $color));
}
#-----------------------------------------------------------------------------
sub print_suite_number
{
    my $message = shift // '';
    my $color   = $message_colors{'suite_number'};
    print(Attes::Message::colorize($message, $color));
}
#-----------------------------------------------------------------------------
sub print_test_extra
{
    my $message = shift // '';
    my $color   = $message_colors{'test_extra'};
    print(Attes::Message::colorize($message, $color));
}
#-----------------------------------------------------------------------------
sub print_debug
{
    my $message = shift;
    chomp($message);
    print(colorize("DEBUG: $message\n", $COLOR_DEBUG));
}
#-----------------------------------------------------------------------------
sub print_warning
{
    my $message = shift;
    chomp($message);
    print(colorize("WARNING: $message\n", $COLOR_WARNING));
}
#-----------------------------------------------------------------------------
sub print_stage
{
    my $message = shift;
    chomp($message);
    print(colorize("$message\n", $COLOR_STAGE));
}
#-----------------------------------------------------------------------------
sub print_error
{
    my $message = shift;
    chomp($message);
    print(STDERR colorize("ERROR: $message\n", $COLOR_ERROR));
}
#------------------------------------------------------------------------------
sub fatal_error
{
    my $message = shift;
    print_error($message);
    exit(-1);
}
#-----------------------------------------------------------------------------
sub term_length
{
    my $string = shift;
    return length(colorstrip($string));
}
#-----------------------------------------------------------------------------

1;

__END__
