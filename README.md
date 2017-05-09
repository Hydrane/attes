#Attes — A Testing Tool Ersatz for SQL

*This is a work in progress. A more comprehensive documentation is on the
way.*

##What it is

``Attes`` is a small prototype for a developer-oriented SQL test framework.
This small tool still has quite a few rough edges, however it is now mostly
functional.

``Attes`` was developed at [BidMotion](http://www.bidmotion.com) to fill
a very specific need, namely testing various SQL queries, potentially for
different relational database management systems, with an emphasis on
[MySQL](https://www.mysql.com) and [PostgreSQL](https://www.postgresql.org).

Be warned that its goals are very modest: ``Attes`` is not meant to be
a professional SQL unit testing framework.

##License

``Attes`` is distributed under the terms of the
[3-Clause BSD license](https://opensource.org/licenses/BSD-3-Clause).

##What's in there?

Not much to be honest as ``Attes`` is just a [Perl 5](https://www.perl.org)
script together with a few small Perl modules.

###The ``attes.pl`` script

This script launches SQL test suites from the current directory.

Type ``./launch_suites.pl --help`` for more information.

A test suite is simply a list of test. Each suite is given by a directory
which should exhibit the following structure:

    <suite_name>/
        tests.txt  # A text file listing the tests to perform
        <test_a>/  # Several test directories, listed in the file tests.txt
        <test_b>/
        <test_c>/

Each test directory should contain the following files:

       command.txt   # A file describing the command to launch
       query.txt     # Optional: the SQL query to perform
       expected.txt  # The expected result

A proper documentation remains to be written. In the meantime, please
have a look at the suite ``example_suite`` for a full-featured example.

##How to use it?

To run the test suites, use the command:

    ./attes.pl [options] <suite_1> <suite_2> ... <suite_n>

in the current directory. A full synopsis together with the list of options
can be obtained using the ``--help`` option.

##Need more information?

For the time being, the only thing resembling even remotely to a documentation
are [these slides](docs/attes.pdf)

That's it for now. Feel free to drop me a line at <jm@bidmotion.com> if you
have comments or questions.
