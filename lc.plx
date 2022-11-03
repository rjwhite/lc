#!/usr/bin/env perl

# lc - list directory and file names in columns
# lc [ -fdbcspan1vh ] [ directory ... ]
#
# I have tried to mimic the behaviour of lc from the old UNIX lc.c
# version I have from the University of Waterloo, fixing some bugs, and
# slightly changed some behavior.  
#
# Written so I'd have a Windows version under Unix tool packages like
# cygwin and to have a quick working version when I set up a new *nix system.
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

my $progname   = $0 ;
$progname      =~ s/^.*\/// ;

my $version = 'v0.6' ;
# want to search for some modules at runtime instead of compile time
# If we do a "use <module>;" and it doesn't exist, our program
# will bomb.  Do the equivalent at run-time.

my @things_we_need = (
    "Term::ReadKey",
    "IO::Interactive",
) ;
my $got_things_we_need = load_modules( \@things_we_need ) ;

my $COLUMN_SIZE         = 14 ;

# flags for printing specific thingies.  Or'ed together
my $C_PRINT_DIRS        = 1 ;
my $C_PRINT_FILES       = 2 ;
my $C_PRINT_PIPES       = 4 ;
my $C_PRINT_BLOCK_SPEC  = 8 ;
my $C_PRINT_CHAR_SPEC   = 16 ;
my $C_PRINT_SYMLINKS    = 32 ;
my $C_PRINT_SOCKETS     = 64 ;

my @directories         = () ;
my @files               = () ;
my @pipes               = () ;
my @block_spec          = () ;
my @char_spec           = () ;
my @unsatisfied         = () ;
my @sockets             = () ;

my @things    = (
    \@directories,
    \@files,
    \@pipes,
    \@block_spec,
    \@char_spec,
    \@unsatisfied,
    \@sockets,
) ;

my @things_title = (
    "Directories:\n",
    "Files:\n",
    "Pipes:\n",
    "Block Spec. Files:\n",
    "Char. Spec. Files:\n",
    "Unsatisfied Symbolic Links:\n",
    "Sockets:\n",
) ;

# Flags OR'ed together to determine what to print.  
# default to nothing.  Fix later if no options given
my $things_print_flags = 0 ;

my @things_print_flag = (
    $C_PRINT_DIRS,
    $C_PRINT_FILES,
    $C_PRINT_PIPES,
    $C_PRINT_BLOCK_SPEC,
    $C_PRINT_CHAR_SPEC,
    $C_PRINT_SYMLINKS,
    $C_PRINT_SOCKETS,
) ;

my $one_per_line_flag      = 0 ;    # if option -1 given
my $print_all_flags        = 0 ;    # if option -a given
my $ok_to_print_flag       = 1 ;    # print if option -n NOT given
my $fcounter               = 0 ;    # non-zero if something would print
my $indent                 = "" ;   # indent if multiple directories given
my @directory_args         = () ;

# process options

my $num_errs = 0 ;
for ( my $i = 0 ; $i <= $#ARGV ; $i++ ) {
    if (  $ARGV[ $i ] =~ /^-/ ) {
        my $option = $ARGV[ $i ] ;
        $option =~ s/^-// ;
        my @options = split( //, $option ) ;

        foreach my $opt ( @options ) {
            if ( $opt eq "a" ) {
                # print special enties . and ..
                $print_all_flags++ ;
            } elsif ( $opt eq "f" ) {
                # print files
                $things_print_flags |= $C_PRINT_FILES ;
            } elsif ( $opt eq "d" ) {
                # print directories
                $things_print_flags |= $C_PRINT_DIRS ;
            } elsif ( $opt eq "c" ) {
                # print Character special files
                $things_print_flags |= $C_PRINT_CHAR_SPEC ;
            } elsif ( $opt eq "b" ) {
            # print Block Special files
                $things_print_flags |= $C_PRINT_BLOCK_SPEC ;
            } elsif ( $opt eq "p" ) {
                # print Named Pipes
                $things_print_flags |= $C_PRINT_PIPES ;
            } elsif ( $opt eq "s" ) {
                # print special files (char and block )
                $things_print_flags = $things_print_flags | 
                    $C_PRINT_BLOCK_SPEC |
                    $C_PRINT_CHAR_SPEC ;
            } elsif ( $opt eq "1" ) {
                # print one per line
                $one_per_line_flag++ ;
            } elsif ( $opt eq "n" ) {
                # dont print anything
                $ok_to_print_flag = 0 ;
                $one_per_line_flag++ ;
            } elsif ( $opt eq "v" ) {
                print "version: $version\n" ;
                exit(0) ;
            } elsif ( $opt eq "h" ) {
                usage() ;
                exit(0) ;
            } else {
                printf STDERR "$progname: Unknown flag: $opt\n" ;
                $num_errs++ ;
            }
        }
    } else {
        push( @directory_args, $ARGV[ $i ] ) ;
    }
}
exit(1) if ( $num_errs ) ;

# if no specific print options were given 
if ( $things_print_flags == 0 ) {
    $things_print_flags = $C_PRINT_DIRS | $C_PRINT_FILES |
        $C_PRINT_BLOCK_SPEC | $C_PRINT_CHAR_SPEC | 
        $C_PRINT_SOCKETS | $C_PRINT_SYMLINKS | $C_PRINT_PIPES ;
}

# If no directories given, default to current directory
push( @directory_args, "." ) if ( @directory_args == 0 ) ;

my $num_entries = @directory_args  ;
if ( $num_entries > 1 ) {
    $indent = "    " ;
}

# check to see if STDOUT attached to terminal.
# If so, and we loaded our optional modules ok, then
# go get the terminal width size and use it

my $term_width = 80 ;
my $column_width = $COLUMN_SIZE + 1 ;

if ( $got_things_we_need ) {
    my @term_size = () ;
    my $fd = *STDOUT ;
    if ( IO::Interactive::is_interactive($fd) ) {
        @term_size = Term::ReadKey::GetTerminalSize $fd ;
    }
    if ( @term_size != 0 ) {
        $term_width = $term_size[0] ;
    } 
} 

# We indent if printing multiple directories.
# Account for that
$term_width -= length( $indent ) ;

my $column_count = 0 ;
foreach my $dir ( @directory_args ) {
    if ( opendir( DIR, "$dir" )) {
        $column_count++ ;

        @directories    = () ;
        @files          = () ;
        @pipes          = () ;
        @block_spec     = () ;
        @char_spec      = () ;
        @unsatisfied    = () ;
        @sockets        = () ;

        while ( my $f = readdir( DIR )) {
            if ( $print_all_flags == 0 ) {
                next if ( $f eq "." ) ;
                next if ( $f eq ".." ) ;
            }
            my $pathname = File::Spec->catfile( "$dir", "$f" ) ;
            if ( -d "$pathname" ) {
                push( @directories, $f ) ;
            } elsif ( -f "$pathname" ) {
                push( @files, $f ) ;
            } elsif ( -S "$pathname" ) {
                push( @sockets, $f ) ;
            } elsif ( -b "$pathname" ) {
                push( @block_spec, $f ) ;
            } elsif ( -c "$pathname" ) {
                push( @char_spec, $f ) ;
            } elsif ( -p "$pathname" ) {
                push( @pipes, $f ) ;
            } else {
                # If we made it to here and it's a symlink,
                # then it must be unsatisfied
                if ( -l "$pathname" ) {
                    push( @unsatisfied, $f ) ;
                }
            }
        }
        closedir( DIR ) ;

        print "${dir}:\n" if ( $num_entries > 1 ) ;

        my $index = 0 ;
        my $printed_something = 0 ;
        foreach my $thing ( @things ) {
            $index++ ;
            # see if we want this filetype

            my $pr_flag = $things_print_flag[ $index-1 ] ;
            next if (( $things_print_flags & $pr_flag ) != $pr_flag );

            # if we found some stuff for this filetype

            my $size = @$thing ;
            if ( $size ) {
                if ( $ok_to_print_flag ) {
                    if ( $one_per_line_flag == 0 ) {
                        print "\n" if ( $printed_something ) ;
                        print "$indent$things_title[ $index-1 ]" ;
                    } else {
                        print "\n" if ( $printed_something ) ;
                    }
                }
                $printed_something++ ;

                my $print_line = "" ;
                my $print_line_len = 0 ;

                foreach my $item ( sort( @$thing )) {
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
                        $print_line =~ s/\s+$// ;   # strip trailing spaces
                        print "$indent$print_line\n" ;

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
                    $print_line =~ s/\s+$// ;        # strip trailing spaces
                    print "$indent$print_line\n" ;
                    $fcounter++ ;
                }
            }
        }
    } else {
        print "$dir: No such file or directory\n" ;
        next ;
    }
    if (( $column_count < $num_entries ) and ( $ok_to_print_flag )) {
        print "\n" ;
    }
}
exit(0) if ( $fcounter ) ;
exit(1) ;


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
        my @parts = split( /::/, $thing ) ;
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
        return(0) ;     #failure
    }
}


sub usage {
    print "usage: [ -option ]* [ directory ]*\n" .
        "    a    print special entries as well (. and ..)\n" .
        "    b    list block special files\n" .
        "    c    list character special files\n" .
        "    d    list directories\n" .
        "    f    list ordinary files\n" .
        "    h    print usage and exit\n" .
        "    n    turn off all output\n" .
        "    p    list permanent pipes\n" .
        "    s    list all special files\n" .
        "    v    print version and exit\n" .
        "    1    print 1 entry per line\n" ;

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

=head1 DIAGNOSTICS

Symbolic links are normally followed, and each prints under the category
of the type  of thing  to which it is linked.  If the symbolic link
points to a nonexistent pathname, or if you do not have permission to
resolve the pathname, lc will list the link under the category
"Unresolved Symbolic Links".

=cut
