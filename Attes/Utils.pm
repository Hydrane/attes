package Attes::Utils;

use strict;
use warnings;

use Carp;
use Term::ANSIColor qw(:constants);

require Exporter;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(trim get_random_string may_be_a_number);
our %EXPORT_TAGS = ('all' => [@EXPORT_OK]);
our $VERSION     = '0.1';

#-----------------------------------------------------------------------------
sub trim
{
    #
    # Remove leading and trailing whitespace from a string.
    #
    my $a = shift;
    $a =~ s/\s+$//;
    $a =~ s/^\s+//;
    return $a;
}
#-----------------------------------------------------------------------------
sub get_random_string
{
    my $length = shift;
    if (! defined $length || $length <= 0) {
       $length = 8;
   }
    my @chars = ('A'..'Z', 'a'..'z', '0'..'9');
    my $string = '';
    $string .= $chars[rand($#chars + 1)] for 1..$length;

    return $string;
}
#-----------------------------------------------------------------------------
sub may_be_a_number
{
    my $n = shift;
    if ($n =~ m/^[+-]?(\d+\.?\d*|\d*\.?\d+)([eE][+-]?\d+)?$/) {
        return 1;
    }
    return 0;
}
#-----------------------------------------------------------------------------
sub file_content_matches_regex
{
    my $file  = shift;
    my $regex = shift;
    my $content = eval { read_file($file); };
    if (defined $content) {
        if ($content =~ m/$regex/) {
            return 1;
        }
    }
    return 0;
}
#-----------------------------------------------------------------------------
sub file_has_line_that_matches_regex
{
    my $file  = shift;
    my $regex = shift;

    my $fd;
    if (open($fd, "<$file")) {
        while (my $line = <$fd>) {
            next if ($line =~ m/^\s*$/);
            $line = Attes::Utils::trim($line);
            if ($line =~ m/$regex/) {
                return 1;
            }
        }
        close($fd);
    }
    return 0;
}
#-----------------------------------------------------------------------------

1;

__END__
