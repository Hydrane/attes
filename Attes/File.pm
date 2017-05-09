package Attes::File;

use strict;
use warnings;

use Carp;

require Exporter;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(error_if_directory_not_readable
                      error_if_file_not_readable);
our %EXPORT_TAGS = ('all' => [@EXPORT_OK]);
our $VERSION     = '0.1';

#-----------------------------------------------------------------------------
sub error_if_file_not_readable
{
    my $path = shift;
    my $error = error_if_path_not_readable($path);
    if ($error) {
        return $error;
    }
    if (! -f $path) {
        return "Path '$path' is not a regular file.";
    }
}
#-----------------------------------------------------------------------------
sub error_if_directory_not_readable
{
    my $path = shift;
    my $error = error_if_path_not_readable($path);
    if ($error) {
        return $error;
    }
    if (! -d $path) {
        return "Path '$path' is not a directory.";
    }
}
#-----------------------------------------------------------------------------
sub error_if_path_not_readable
{
    my $path = shift;
    if (! -e $path) {
        return "Path '$path' does not exists.";
    }
    if (! -r $path) {
        return "Path '$path' is not readable.";
    }
}
#-----------------------------------------------------------------------------

1;

__END__
