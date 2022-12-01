#!/usr/bin/env perl

# lc - list directory and file names in columns
# lc [ -fdbcspan1vh ] [ directory ]*
#
# Written so I'd have a Windows version under Unix tool packages like
# cygwin and to have a quick working version when I set up a new *nix system.
#
# I have tried to mimic the behaviour of lc from the old UNIX lc.c
# version I have from the University of Waterloo, fixing some bugs, and
# slightly changed some behavior.

# Added some new options:
#   -h (help)
#   -v (version)
#   -S (list sockets)       -s was aleady taken by original lc
# and added as well is support for a LC_COLUMN_WIDTH environment vaiable.
#
# flag options can be grouped together, or separated - like the original lc.
# ie: the following are equivalent:
#    lc -fcb
#    lc -f -cb
#
# requires CPAN Term::ReadKey to handle window resizing.
# Also needs IO::Interactive which no longer seems to be part of a default
# Perl installation.  Otherwise it defaults to a 80-char terminal size.
#
# RJ White
# rj.white@moxad.com

use warnings ;
use strict ;
use File::Spec ;

# Globals
my $G_progname = $0 ;
my $G_version  = 'v0.9' ;

# for column size
my $C_COLUMN_SIZE = 14 ;      # original lc (need to +1 for separator)
my $C_MIN_WIDTH   = 10 ;
my $C_MAX_WIDTH   = 30 ;

# flags for error()
my $C_WARNING     = 0 ;
my $C_FATAL       = 1 ;

# flags for command-line flag options

my $C_FLAG_PRINT_EVERYTHING     = 1 ;    # -a
my $C_FLAG_DONT_PRINT_ANYTHING  = 2 ;    # -n
my $C_FLAG_ONE_PER_LINE         = 3 ;    # -1

# types of files
my $C_DIRECTORIES = 1 ;
my $C_FILES       = 2 ;
my $C_PIPES       = 3 ;
my $C_BLOCK_SPEC  = 4 ;
my $C_CHAR_SPEC   = 5 ;
my $C_SYMLINKS    = 6 ;
my $C_SOCKETS     = 7 ;


# Let er rip...
exit(1) if ( main() ) ;     # exit 1 if any problems
exit(0) ;


# mainline
#
# Returns:
#   0:  OK
#   1:  not OK
# Globals:
#   $G_progname

sub main {
    $G_progname =~ s/ ^ .* \/ //x ;

    # values get set to 1 for each file-type we are interested in printing
    my %file_types = (
        $C_DIRECTORIES => 0,    # -d
        $C_FILES       => 0,    # -f
        $C_PIPES       => 0,    # -p
        $C_BLOCK_SPEC  => 0,    # -b, -s
        $C_CHAR_SPEC   => 0,    # -c, -s
        $C_SYMLINKS    => 0,    # if nothing given
        $C_SOCKETS     => 0,    # if nothing given
    ) ;

    # values get set to 1 if flags given on command-line
    my %options = (
        $C_FLAG_PRINT_EVERYTHING     => 0,      # -a
        $C_FLAG_DONT_PRINT_ANYTHING  => 0,      # -n
        $C_FLAG_ONE_PER_LINE         => 0,      # -1
    ) ;

    # process command-line options

    my @directories = () ;
    if ( process_options( \%file_types, \%options, \@directories )) {
        return(1) ;
    }

    # get number of things we specified we wanted from command-line options

    my $num_things_we_want = 0 ;
    my @p_keys = keys( %file_types ) ;
    foreach my $key ( @p_keys ) {
        $num_things_we_want += $file_types{ $key } ;
    }

    # if no specific print options were given, then give us everything

    if ( $num_things_we_want == 0 ) {
        # we want everything
        foreach my $key ( @p_keys ) {
            $file_types{ $key } = 1 ;
        }
   }

    # If no directories given, default to current directory

    push( @directories, "." ) if ( @directories == 0 ) ;

    return( process_dirs( \@directories, \%file_types, \%options )) ;
}


# process command-line options
#
# We have a hash structure with the key being the command-line
# option (eg: 'f' for wanting files).  The value is an anonymous
# array.  The first element specifies either it being a routine
# to run, or a flag to set: $C_ACTION_CODE or $C_ACTION_SET_FLAG.
#
# If it's code to run, the next element is the reference to the routine
# to run with no arguments.  The next optional element is the whether
# to exit the program after running the routine: $C_EXIT_YES or $C_EXIT_NO.
#
# If it's a flag to set, the next element is the hash reference
# and the following values are the keys to use for that hash to
# set the value to 1.
#
# Args:
#   1: reference to hash of file-types we want to print
#   2: reference to hash of flags we set
#   3: reference to array of directories given on command-line
# Exits
#   number of errors found if we don't exit from FATAL error

sub process_options {
    my $print_ref = shift ;
    my $flags_ref = shift ;
    my $dirs_ref  = shift ;

    my $i_am = (caller(0))[3] . "()" ;
    my $num_errs = 0 ;

    my $C_ACTION_CODE     = 1 ;
    my $C_ACTION_SET_FLAG = 2 ;

    my $C_EXIT_YES = 1 ;
    my $C_EXIT_NO  = 2 ;

    my %options = (
        'b' => [ $C_ACTION_SET_FLAG, $print_ref, $C_BLOCK_SPEC ],
        'c' => [ $C_ACTION_SET_FLAG, $print_ref, $C_CHAR_SPEC ],
        'd' => [ $C_ACTION_SET_FLAG, $print_ref, $C_DIRECTORIES ],
        'f' => [ $C_ACTION_SET_FLAG, $print_ref, $C_FILES ],
        'p' => [ $C_ACTION_SET_FLAG, $print_ref, $C_PIPES ],
        's' => [ $C_ACTION_SET_FLAG, $print_ref, $C_CHAR_SPEC, $C_BLOCK_SPEC ],
        'a' => [ $C_ACTION_SET_FLAG, $flags_ref, $C_FLAG_PRINT_EVERYTHING ],
        'n' => [ $C_ACTION_SET_FLAG, $flags_ref, $C_FLAG_DONT_PRINT_ANYTHING ],
        '1' => [ $C_ACTION_SET_FLAG, $flags_ref, $C_FLAG_ONE_PER_LINE ],
        'h' => [ $C_ACTION_CODE, \&usage, $C_EXIT_YES ],
        'v' => [ $C_ACTION_CODE, \&print_version, $C_EXIT_YES ],
        'S' => [ $C_ACTION_SET_FLAG, $print_ref, $C_SOCKETS ],
    ) ;

    for ( my $i = 0 ; $i <= $#ARGV ; $i++ ) {
        if (  $ARGV[ $i ] =~ / ^- /x ) {
            my $option = $ARGV[ $i ] ;
            $option =~ s/ ^- //x ;
            my @options = split( //, $option ) ;

            foreach my $opt ( @options ) {
                # see if an invalid option
                if ( not defined( $options{ $opt } )) {
                    error( "unknown flag: $opt", $C_WARNING ) ;
                    $num_errs++ ;
                    next ;
                }

                my $action = $options{ $opt }[0] ;
                if ( $action eq $C_ACTION_CODE ) {
                    my $ref = ref( $options{ $opt }[1] ) ;
                    if (( not defined( $ref )) or ( $ref ne 'CODE' )) {
                        my $err = "bad routine supplied for option \'$opt\'" ;
                        error( "$i_am: $err", $C_FATAL ) ;
                    }
                    &{$options{ $opt }[1]} ;        # run routine
                    my $exit_type = $options{ $opt }[2] ;
                    $exit_type = $C_EXIT_NO if ( not defined( $exit_type )) ;
                    exit(0) if ( $exit_type eq $C_EXIT_YES ) ;

                } elsif ( $action eq $C_ACTION_SET_FLAG ) {
                    my $hash_ref = $options{ $opt }[1] ;
                    my $ref = ref( $hash_ref ) ;
                    if (( not defined( $ref )) or ( $ref ne 'HASH' )) {
                        my $err = "bad HASH ref supplied for option \'$opt\'" ;
                        error( "$i_am: $err", $C_FATAL ) ;
                    }
                    # get the keys to use in hash to set flag
                    my @args = @{$options{ $opt }} ;
                    @args = @args[2..$#args] ;
                    foreach my $key ( @args ) {
                        ${$hash_ref}{ $key } = 1 ;  # set flag
                    }
                } else {
                    error( "$i_am: unknown action: \'$action\'", $C_FATAL ) ;
                }
            }
        } else {
            push( @{$dirs_ref}, $ARGV[ $i ] ) ;     # directories we want
        }
    }
    return( $num_errs ) ;
}


# get the file-type of a pathname
#
# Args:
#   1:  pathname
# Returns:
#   key to use in hash to specify a file-type we want
#   undef if can't get a file-type

sub get_file_type {
    my $pathname = shift ;

    return( $C_DIRECTORIES )  if ( -d "$pathname" ) ;
    return( $C_FILES )        if ( -f "$pathname" ) ;
    return( $C_BLOCK_SPEC )   if ( -b "$pathname" ) ;
    return( $C_CHAR_SPEC )    if ( -c "$pathname" ) ;
    return( $C_PIPES )        if ( -p "$pathname" ) ;
    return( $C_SOCKETS )      if ( -S "$pathname" ) ;

    # If we made it to here and it's a symlink,
    # then it must be unsatisfied
    return( $C_SYMLINKS )     if ( -l "$pathname" ) ;

    return( undef ) ;
}


# process a list of directories
#
# Note that we turn off perlcritic complaining about it having
# a "high complexity score (31)" - which is greater than the default
# of 20 at Level 3 (harsh).
# ie:  "perlcritic --harsh lc.plx" will now pass with this exception.
#
# Args:
#   1:  reference to array of directories we are interested in
#   2:  reference to hash of file-types we are interested in
#   3:  deference to hash of options set on command-line
# Returns:
#   0:  if something printed or would have printed if -n not given
#   1:  nothing printed or would have printed

sub process_dirs {   ## no critic (ProhibitExcessComplexity)
    my $dirs_ref          = shift ;
    my $print_flags_ref   = shift ;
    my $options_ref       = shift ;

    my $i_am = (caller(0))[3] ;

    # set some short-cut flags

    my $print_all_flag    = ${$options_ref}{ $C_FLAG_PRINT_EVERYTHING } ;
    my $one_per_line_flag = ${$options_ref}{ $C_FLAG_ONE_PER_LINE  } ;
    my $ok_to_print_flag  = 1 - ${$options_ref}{ $C_FLAG_DONT_PRINT_ANYTHING } ;

    my %file_list = (
        $C_DIRECTORIES => [],
        $C_FILES       => [],
        $C_PIPES       => [],
        $C_BLOCK_SPEC  => [],
        $C_CHAR_SPEC   => [],
        $C_SYMLINKS    => [],
        $C_SOCKETS     => [],
    ) ;

    my %file_titles = (
        $C_DIRECTORIES => "Directories",
        $C_FILES       => "Files",
        $C_PIPES       => "Pipes",
        $C_BLOCK_SPEC  => "Block Spec. Files",
        $C_CHAR_SPEC   => "Char. Spec. Files",
        $C_SYMLINKS    => "Unsatisfied Symbolic Links",
        $C_SOCKETS     => "Sockets",
    ) ;

    # order of file types we want printed
    my @file_type_order = ( $C_DIRECTORIES,     $C_FILES,       $C_PIPES,
                             $C_BLOCK_SPEC,     $C_CHAR_SPEC,   $C_SYMLINKS,
                             $C_SOCKETS,
    ) ;

    my $fcounter = 0 ;    # non-zero if something would print
    my $indent   = "" ;   # indent if multiple directories given

    my @dirs = @{$dirs_ref} ;
    my $num_entries = @dirs ;
    if ( $num_entries > 1 ) {
        $indent = "    " ;
    }

    my $term_width   = get_term_width() ;
    my $column_width = get_column_width() ;

    # We indent if printing multiple directories.
    # Account for that
    $term_width -= length( $indent ) ;

    my $column_count = 0 ;
    foreach my $dir ( @dirs ) {
        if ( ! opendir( DIR, "$dir" )) {
            error( "cannot open $dir: $!", $C_WARNING ) ;
            next ;
        }
        $column_count++ ;

        # zero out our lists
        foreach my $file_type ( @file_type_order ) {
            @{$file_list{ $file_type }} = () ;
        }

        while ( my $f = readdir( DIR )) {
            if ( $print_all_flag == 0 ) {
                next if ( $f eq "." ) ;
                next if ( $f eq ".." ) ;
            }
            my $pathname = File::Spec->catfile( "$dir", "$f" ) ;

            my $f_type = get_file_type( $pathname ) ;
            if ( defined( $f_type )) {
                # see if we even want this filetype
                my $want = ${$print_flags_ref}{ $f_type } ;
                if ( $want ) {
                    push( @{$file_list{ $f_type }}, $f ) ;
                }
            }
        }
        closedir( DIR ) ;

        if (( $num_entries > 1 ) and $ok_to_print_flag ) {
            print "${dir}:\n" ;
        }

        my $printed_something = 0 ;
        foreach my $file_type ( @file_type_order ) {
            # see if we want this filetype
            my $want = ${$print_flags_ref}{ $file_type } ;
            next if ( $want == 0 ) ;

            # if we found some stuff for this filetype
            my $title = $file_titles{ $file_type } ;
            my $size = @{$file_list{ $file_type }} ;
            next if ( $size == 0 ) ;

            # print any line separator and title

            if ( $ok_to_print_flag ) {
                print "\n" if ( $printed_something ) ;
                if ( $one_per_line_flag == 0 ) {
                    print "${indent}${title}:\n" ;
                }
            }
            $printed_something++ ;

            # now ready to start printing a line

            my $print_line = "" ;
            my $print_line_len = 0 ;

            foreach my $item ( sort( @{$file_list{ $file_type }} )) {
                if ( $one_per_line_flag ) {
                    print "$item\n" if ( $ok_to_print_flag );
                    $fcounter++ ;
                    next ;
                }

                my $item_len = length( $item ) ;
                $print_line_len = length( $print_line ) ;

                if ((( $print_line_len + $item_len ) < $term_width ) and
                (( $term_width - $print_line_len ) > $column_width )) {
                    # we have room to add to this line
                    $print_line .= $item ;      # add item to what we have
                } else {
                    # no room to add more.  print the line and reset
                    $print_line =~ s/ \s+ $ //x ;   # strip trailing spaces
                    print "$indent$print_line\n" if ( $ok_to_print_flag ) ;

                    $print_line = $item ;       # set our new column
                    $fcounter++ ;
                }

                # add on the spaces we need to fill the column
                my $num_columns = int( $item_len / $column_width ) + 1  ;
                my $num_spaces = ( $num_columns * $column_width ) - $item_len ;
                $print_line .= ' ' x $num_spaces ;
            }

            # print last lingering data collected
            if ( $print_line ne "" ) {
                $print_line =~ s/ \s+ $ //x ;        # strip trailing spaces
                print "$indent$print_line\n" if ( $ok_to_print_flag ) ;
                $fcounter++ ;
            }
        }
        if (( $column_count < $num_entries ) and ( $ok_to_print_flag )) {
            print "\n" ;
        }
    }
    return(0) if ( $fcounter ) ;    # OK if something printed or would print
    return(1) ;
}


# Get the terminal width
#
# Args:
#   none
# Returns:
#   terminal width.  default to 80

sub get_term_width {
    my $term_width = 80 ;

    # want to search for some modules at runtime instead of compile time
    # If we do a "use <module>;" and it doesn't exist, our program
    # will bomb.  Do the equivalent at run-time.

    my @things_we_need = (
        "Term::ReadKey",
        "IO::Interactive",
    ) ;
    my $got_things_we_need = load_modules( \@things_we_need ) ;

    # check to see if STDOUT attached to terminal.
    # If so, and we loaded our optional modules ok, then
    # go get the terminal width size and use it

    if ( $got_things_we_need ) {
        my @term_size = () ;
        my $fd = *STDOUT ;
        if ( IO::Interactive::is_interactive( $fd ) ) {
            @term_size = Term::ReadKey::GetTerminalSize( $fd ) ;
        }
        if ( @term_size != 0 ) {
            $term_width = $term_size[0] ;
        }
    }
    return( $term_width ) ;
}


# get the column width we want to use
#
# The default is $C_COLUMN_SIZE, to which we add 1 for a separator space.
# But the user can over-ride the width by setting the environment variable
# LC_COLUMN_WIDTH
#
# Args:
#   none
# Returns:
#   column width.  default = $C_COLUMN_SIZE + 1

sub get_column_width {
    my $column_width = $C_COLUMN_SIZE + 1 ;   # default

    # see if we want a different column width via an environment variable

    my $LCW = 'LC_COLUMN_WIDTH' ;
    my $width = $ENV{ $LCW } ;
    if ( defined( $width )) {
        if ( $width eq "" ) {
            error( "environment variable $LCW is an empty string", $C_FATAL ) ;
        }
        if ( $width !~ / ^ \d+ $ /x ) {
            my $err = "environment variable $LCW contains non-digits: '$width'" ;
            error( $err, $C_FATAL ) ;
        }
        if (( $width < $C_MIN_WIDTH ) || ( $width > $C_MAX_WIDTH )) {
            my $err = "environment variable $LCW is not in range $C_MIN_WIDTH " .
                      "to $C_MAX_WIDTH: '$width'" ;
            error( $err, $C_FATAL ) ;
        }
        $column_width = $width + 1 ;    # +1 for space separator
    }
    return( $column_width ) ;
}


# load the modules we need
#
# Args:
#   1:  reference to array of modules (this::that::blah)
# Returns:
#   1:  success
#   0:  was not able to load some of the modules

sub load_modules {
    my $modules_ref = shift ;

    my $modules_we_found = 0 ;           # counter
    my $modules_we_need  = @{$modules_ref} ;

    foreach my $thing ( @${modules_ref} ) {
        my @parts = split( / :: /x, $thing ) ;
        $parts[-1] .= ".pm" ;

        my $found = 0 ;
        foreach my $path ( @INC ) {
            my $f = File::Spec->catfile( $path, @parts ) ;
            # check if the module exists
            if ( -f $f ) {
                require $f ;
                $found++ ;
                $modules_we_found++ ;
                last ;
            }
        }
        return(0) if ( $found == 0 ) ;
    }
    if ( $modules_we_need == $modules_we_found ) {
        return(1) ;     # success
    } else {
        return(0) ;     # failure
    }
}


# print an error.  exit if flag is $C_FATAL
#
# Args:
#   1:  string to print
#   2:  optional flag, default $C_FATAL.  exit if $C_FATAL
# Returns:
#   0:  if not $C_FATAL, otherwise exit(1)
# Globals:
#   $G_progname

sub error {
    my $err  = shift ;
    my $flag = shift ;

    $flag = $C_FATAL if ( not defined( $flag )) ;

    print STDERR "$G_progname: $err\n" ;

    exit(1) if ( $flag eq $C_FATAL ) ;
    return(0) ;
}


# Print our version
#
# Args:
#   none
# Returns:
#   0
# Globals:
#   $G_version

sub print_version {
    print "version: $G_version\n" ;
    return(0) ;
}


# print the usage
#
# Args:
#   none
# Returns:
#   0
# Globals:
#   $G_progname
#   $G_version

sub usage {
    print "usage: $G_progname [ -option ]* [ directory ]*\n" .
        "    a    print special entries as well (. and ..)\n" .
        "    b    list block special files\n" .
        "    c    list character special files\n" .
        "    d    list directories\n" .
        "    f    list ordinary files\n" .
        "    h    print usage and exit\n" .
        "    n    turn off all output\n" .
        "    p    list permanent pipes\n" .
        "    s    list all special files\n" .
        "    v    print version and exit ($G_version)\n" .
        "    1    print 1 entry per line\n" .
        "    S    list sockets\n" ;

    return(0) ;
}

__END__
=head1 NAME

lc - list directory and file names in columns

=head1 SYNOPSIS

lc [ -fdbcspan1hv ] [ directory ... ]

=head1 DESCRIPTION

Lc  lists the elements of the given directories.  The elements are divided
into the five basic types (files, directories, character  special  files,
block  special  files,  and pipes)  and  are  printed in alphabetical
order.  They are normally printed 5 to a line, preceded by a title
indicating the type, but the -1 option can be used to force single-column
untitled output.

If no argument is given, the current working directory is used by default.
The contents of all directories named in the argument list are  displayed.
while  all  other  names (i.e.  non-directories)  are  ignored.
This feature allows one to use a shell's pattern matching abilities to
generate the arguments without having to worry about non-directory names
that might also be matched (e.g.  would do an lc of all the non-hidden
directories in one's home directory).

The special entries and are normally not listed; the -a option causes
them to be  listed as well.

The  -n option turns off all output; this is useful when only the exit
status is wanted.  (The exit status is 0 if something would have been
printed, 1 otherwise.)

If any of the following option arguments  are  given,  lc  lists  only
those  types  of entries; otherwise, all entries are listed.
The options and their meanings are:

    b    list block special files
    c    list character special files
    d    list directories
    f    list ordinary files
    n    turn off all output
    p    list permanent pipes
    s    list all special files

The following additional options have been added:

    h    print usage and exit
    v    print version and exit

Options may be given separately or combined.  For example, the following
are all equivalent:

    lc -b -p -c
    lc -bp -c
    lc -bpc

Lc may be used with the substitution features of the Shell to select
particular kinds of files (eg, directories) to take part in some
processing, for example:

for example:

    ls -l `lc -1d`

This lists the contents of all sub-directories of the current directory.

=head1 SYMBOLIC LINKS

Symbolic links are normally followed, and each prints under the category
of the type  of thing  to which it is linked.  If the symbolic link
points to a nonexistent pathname, or if you do not have permission to
resolve the pathname, lc will list the link under the category
"Unsatisfied Symbolic Links".

=head1 ENVIRONMENT VARIABLES

LC_COLUMN_WIDTH can be set to change the default 14 character width of
items to be printed.  It can  be  between  (and  including)  10  and
30 characters, by setting the environment variable LC_COLUMN_WIDTH.
This does not exist with the original B and C versions.

=cut
