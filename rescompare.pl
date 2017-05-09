#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use File::Basename;
use POSIX;

#
# Print debugging message along the way (warning: very verbose!).
#
my $DEBUG = 0;
#
# Stop comparing the file if $MAX_NERRORS_ALLOWED errors are found.
#
my $MAX_NERRORS_ALLOWED = 10;
#
# Default field separator in the input and reference files.
#
my $DEFAULT_FIELD_SEPARATOR = "\t+";
#
# Consider that two floating point numbers are equal if the absolute value
# of their difference is less than $EPSILON_SCALE, their exponent are the same,
# and the absolute value of their mantissa difference is less than
# $EPSILON_MANTISSE.
#
my $EPSILON_MANTISSE = 0.001;
my $EPSILON_SCALE    = 0.005;
#
# Name of the query result file used as an input to compare to a reference file.
#
my $in_file = "";
#
# Name of the reference file. That file can contain regular expressions.
#
my $ref_file = "";
#
# Number of errors found so far.
#
my $nerrors = 0;
#
# Option: field separator used when comparing input and reference files.
#
my $field_separator = $DEFAULT_FIELD_SEPARATOR;
#
# Option: should we handle some fields in the reference file as regex?
#
my $use_regex;
#
# Option: should we discard any difference due to white spaces?
#
my $ignore_white_spaces;
#
# Option: should we print an help message and exit?
#
my $help;

GetOptions(
    "separator|s=s"         => \$field_separator,
    "regex|e"               => \$use_regex,
    "ignore-white-spaces|w" => \$ignore_white_spaces,
    "help|h"                => \$help
);

check_arguments();

my $line_no = 0;     # current non-empty line number being processed
my $in_line_no = 0;  # line number corresponding current line in result file
my $ref_line_no = 0; # line number corresponding current line in reference file

open(IN, "<$in_file") or die("Cannot open result file $in_file!\n");
open(REF, "<$ref_file") or die("Cannot open reference file $ref_file!\n");

while (1) {
    if ($nerrors > $MAX_NERRORS_ALLOWED) {
        last;
    }
    #
    # Get a new line from the input and reference files. Skip empty or
    # comment lines.
    #
    my $in_line = <IN>;
    my $ref_line = <REF>;
    $in_line_no++;
    $ref_line_no++;
    while (&should_skip_line($in_line)) {
        if ($DEBUG) {
            print("skipping line from input file...\n");
        }
        $in_line = <IN>;
        $in_line_no++;
    }
    while (&should_skip_line($ref_line)) {
        if ($DEBUG) {
            print("skipping line from reference file...\n");
        }
        $ref_line = <REF>;
        $ref_line_no++;
    }
    #
    # Here, $in_line is either undefined (end of file reached) or is a
    # non-empty line that should be compared to the reference line.
    #
    # Similarly, $ref_line is either undefined (end of file reached) or
    # non-empty line that should be compared to the input line.
    #
    if (!defined $in_line && !defined $ref_line) {
        last;
    }
    $line_no++;
    if (!defined $in_line) {
        #
        # Continue and increment the error counts.
        #
        &print_field_mismatch(0, "<eof>", "!<eof>");
        $nerrors++;
        next;
    }
    if (!defined $ref_line) {
        #
        # Continue and increment the error counts.
        #
        &print_field_mismatch(0, "!<eof>", "<eof>");
        $nerrors++;
        next;
    }
    if ($DEBUG) {
        printf("Extracted lines:\n");
        printf("    Line in  [".substr($in_line, 0, 50)."]\n");
        printf("    Line ref [".substr($ref_line, 0, 50)."]\n");
    }
    chomp($in_line);
    chomp($ref_line);
    $nerrors += &compare_lines($in_line, $ref_line);
}
close(IN);
close(REF);

if ($nerrors <= $MAX_NERRORS_ALLOWED) {
    print("Found $nerrors errors.\n");
} else {
    print("Found more than $nerrors errors.\n");
}

#------------------------------------------------------------------------------
#                            Functions
#------------------------------------------------------------------------------
sub compare_lines
{
    #
    # Compares the two lines ($in_line from the input file and $ref_line from
    # the reference file).
    #
    my $in_line = shift;
    my $ref_line = shift;

    my @in_fields = split(/$field_separator/, $in_line);
    my @ref_fields = split(/$field_separator/, $ref_line);

    if ($#in_fields != $#ref_fields) {
        &print_size_mismatch($#in_fields, $#ref_fields);
        return 1;
    }
    my $errors = 0;
    for (my $i = 0; $i <= $#in_fields; $i++) {
        my $err = compare_field($in_fields[$i], $ref_fields[$i]);
        if ($err) {
            print_field_mismatch($i+1, $in_fields[$i], $ref_fields[$i]);
            $errors++;
        }
    }
    return $errors;
}
#------------------------------------------------------------------------------
sub compare_field
{
    #
    # Compare two fields, the first one from the input result file, the
    # second from the reference file. Return 0 if the fields are considered
    # equal, 1 otherwise.
    #
    my $in_field = &trim(shift);
    my $ref_field = &trim(shift);

    if ($ignore_white_spaces) {
        $in_field =~ s/\s+//g;
        $ref_field =~ s/\s+//g;
    }

    if ($DEBUG) {
        printf("Comparing:\n");
        printf("    [".substr($in_field, 0, 40)."]\n");
        printf("    [".substr($ref_field, 0, 40)."]\n");
    }

    #
    # Compare with a string
    #
    if ($in_field eq $ref_field) {
        return 0;
    }
    #
    # Match with a regular expression
    #
    if ($use_regex) {
        if ($ref_field =~ /\/(.*)\//) {
            my $regex = $1;
            if ($in_field =~ /$regex/) {
                return 0;
            } else {
                return 1;
            }
        }
    }
    #
    # Compare with a (possibly floating-point) number.
    #
    $! = 0;
    my ($ref_num, $ref_n_unparsed) = POSIX::strtod($ref_field);
    my $ref_is_number = 1;
    if ($ref_n_unparsed != 0 || $!) {
        $ref_is_number = 0;
    }
    if ($ref_is_number) {
        $! = 0;
        my ($in_num, $in_n_unparsed) = POSIX::strtod($in_field);
        if ($in_n_unparsed != 0 || $!) {
            #
            # $in_field is not a number.
            #
            return 1;
        }
        return &compare_floats($in_field, $in_num, $ref_field, $ref_num);
    }
    #
    # Compare with a date
    #
    if ($ref_field =~ /\d\d\d\d[-\/]\d\d[-\/]\d\d/) {
        $ref_field =~ s/[-\/]//g;
        $in_field =~ s/[-\/]//g;
        if ($in_field eq $ref_field) {
            return 0;
        } else {
            return 1;
        }
    }
    #
    # Add your favorite format here! :-)
    #
    return 1;
}
#------------------------------------------------------------------------------
sub compare_floats
{
    #
    # $str_x is the input string representation of a float, $num_x is its
    # conversion to floating-point using POSIX::strtod.
    #
    my $str_a = shift;
    my $num_a = shift;
    my $str_b = shift;
    my $num_b = shift;

    my ($mant_a, $exp_a) = POSIX::frexp($str_a);
    my ($mant_b, $exp_b) = POSIX::frexp($str_b);

    if ($exp_a == $exp_b) {
        my $delta_mantisse = abs($mant_a - $mant_b);
        my $delta_scale = abs($num_a - $num_b);
        if ($delta_mantisse < $EPSILON_MANTISSE && $delta_scale < $EPSILON_SCALE) {
            return 0;
        }
    }
    return 1;

    #
    # Alternatively, we could just use sprintf, but the accuracy may be
    # difficult to tune.
    #
    #my $ACCURACY = 6;
    #my $sa = sprintf("%.${ACCURACY}g", $num_a);
    #my $sb = sprintf("%.${ACCURACY}g", $num_b);
    #
    #if ($sa eq $sb) {
    #    return 0;
    #} else {
    #    return 1;
    #}
}
#------------------------------------------------------------------------------
sub print_field_mismatch
{
    #
    # Print this message if a field differs between the input file and the
    # reference file.
    #
    my $col_no = shift;
    my $in_field = shift;
    my $ref_field = shift;
    print("difference at line $line_no (left: $in_line_no, right: $ref_line_no), col $col_no: left=[$in_field], right=[$ref_field]\n");
}
#------------------------------------------------------------------------------
sub print_size_mismatch
{
    #
    # Print this message if the number of fields on a line differs between
    # the input file and the reference file.
    #
    my $n_in = shift;
    my $n_ref = shift;
    print("difference at line $line_no  (left: $in_line_no, right: $ref_line_no): left has $n_in while right has $n_ref\n");
}
#------------------------------------------------------------------------------
sub should_skip_line
{
    #
    # Should we ignore a given line and keep reading from the input file?
    #
    my $line = shift;
    if (!defined $line) {
        return 0;
    }
    if ($line =~ m/^\s*$/) {
        #
        # Skip empty lines
        #
        return 1;
    }
    if ($line =~ m/^\s*\-\-/) {
        #
        # Skip SQL comments
        #
        return 1;
    }
    return 0;
}
#------------------------------------------------------------------------------
sub trim
{
    #
    # Trim a string, i.e. remove leading and trailing white spaces.
    #
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}
#------------------------------------------------------------------------------
sub check_arguments
{
    #
    # Check the arguments provided to the script and exit with an help
    # message if needed.
    #
    if ($help) {
        print_help();
        exit(-1);
    }
    my $nargs = $#ARGV + 1;
    if ($nargs < 2) {
        print("ERROR: Not enough argument provided.\n\n");
        print_help();
        exit(-1);
    }
    #
    # Find the input and reference file names.
    #
    for (my $i = 0; $i < $nargs; $i++) {
        my $arg = $ARGV[$i];
        if ($arg !~ m/\-/) {
            if (length($in_file) == 0) {
                $in_file = $arg;
            } elsif (length($ref_file) == 0) {
                $ref_file = $arg;
            }
        }
    }
    #
    # Some sanity checks on the files.
    #
    if (length($in_file) == 0) {
        print("ERROR: No result file provided.\n\n");
        print_help();
        exit(-1);
    }
    if (length($ref_file) == 0) {
        print("ERROR: No reference file provided.\n\n");
        print_help();
        exit(-1);
    }
    if (!-e $in_file) {
        print("ERROR: result file $in_file does not exist.\n\n");
        print_help();
        exit(-1);
    }
    if (!(-r $in_file && -f $in_file)) {
        print("ERROR: can not read file $in_file.\n\n");
        print_help();
        exit(-1);
    }
    if (!-e $ref_file) {
        print("ERROR: reference file $ref_file does not exist.\n\n");
        print_help();
        exit(-1);
    }
    if (!(-r $ref_file && -f $ref_file)) {
        print("ERROR: can not read file $ref_file.\n\n");
        print_help();
        exit(-1);
    }
}
#------------------------------------------------------------------------------
sub print_help
{
    my $name  = basename($0);
    my $title = "$name - Compare query result with a reference file";
    my $line  = '-' x length($title);
    print << "EOF";
$title
$line
    The $name script is used to compare two files in a given field separated
    format.

Usage:

    $name [options] <result_file> <reference_file>

Available options:

  -s, --separator <pattern>
      Use the provided pattern as field separator. Patterns can be
      a character, a string, or a Perl compatible regular expression,
      e.g.: "\s*,\s*" to compare CSV files.
      Default: \"$DEFAULT_FIELD_SEPARATOR\".

  -e, --regex
      Interpret some fields from the reference_file as a Perl compatible
      regular expression. The regular expression fields should follow the
      format /REGEX/, for example: /\\d+.{2,4}/ or /^\\w{16}\$/.
      Default: no.

  -w, --ignore-white-spaces
      Ignore white spaces.
      Default: no.

  -h, --help
      Print this help message.
EOF
}
#------------------------------------------------------------------------------
