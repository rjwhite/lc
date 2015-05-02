#!/usr/bin/env perl

# lc - list directory and file names in columns
# lc [ -fdbcspan1 ] [ directory ... ]
#
# I have tried to mimic the behaviour of lc from the 30 year old lc.c
# version I have from the Univesity of Waterloo, fixing some bugs, and
# slightly changed some behavior.  However, not torture-tested nor testing
# all behaviour of old C-version lc (of which I've not looked at the source)
# Best test of it is to point it off to /dev which has lots of
# different file-types.
#
# Written so I'd have a Windows version and to have a quick
# working version when I set up a new *nix system.
#
# requires CPAN Term::ReadKey to handle window resizing.
# Also needs IO::Interactive which no longer seems to be part of a default
# Perl installation
#
# RJ White
# rj@moxad.com


use warnings ;
use strict ;
use File::Spec ;

my $progname   = $0 ;
$progname      =~ s/^.*\/// ;

# want to search for some modules at runtime instead of compile time
# If we do a "use <module>;" and it doesn't exist, our program
# will bomb.  Do the equivalent at run-time.

my @things_we_need = (
    "Term::ReadKey",
    "IO::Interactive",
) ;
my $got_things_we_need = load_modules( \@things_we_need ) ;

my $COLUMNS             = 5 ;
my $COLUMN_SIZE         = 15 ;

my $C_DIRECTORIES       = 0 ;
my $C_FILES             = 1 ;
my $C_BLOCK_SPEC_FILES  = 2 ;
my $C_CHAR_SPEC_FILES   = 3 ;
my $C_SOCKETS           = 4 ;

# flags for printing specific thingies.  Or'ed together
my $C_PRINT_DIRS        = 1 ;
my $C_PRINT_FILES       = 2 ;
my $C_PRINT_BLOCK_SPEC  = 4 ;
my $C_PRINT_CHAR_SPEC   = 8 ;
my $C_PRINT_SOCKETS     = 16 ;
my $C_PRINT_SYMLINKS    = 32 ;
my $C_PRINT_PIPES       = 64 ;

my @directories         = () ;
my @files               = () ;
my @block_spec          = () ;
my @char_spec           = () ;
my @sockets             = () ;
my @pipes               = () ;
my @unsatisfied         = () ;

my @things    = (
    \@directories,
    \@files,
    \@block_spec,
    \@char_spec,
    \@sockets,
    \@pipes,
    \@unsatisfied,
) ;

my @things_title = (
    "Directories:\n",
    "Files:\n",
    "Block Spec. Files:\n",
    "Char. Spec. Files:\n",
    "Sockets:\n",
    "Pipes:\n",
    "Unsatisfied Symbolic Links:\n",
) ;

# Flags OR'ed together to determine what to print.  
# default to nothing.  Fix later if no options given
my $things_print_flags = 0 ;

my @things_print_flag = (
    $C_PRINT_DIRS,
    $C_PRINT_FILES,
    $C_PRINT_BLOCK_SPEC,
    $C_PRINT_CHAR_SPEC,
    $C_PRINT_SOCKETS,
    $C_PRINT_PIPES,
    $C_PRINT_SYMLINKS
) ;

my $one_per_line_flag      = 0 ;
my $print_all_flags        = 0 ;
my $ok_to_print_flag       = 1 ;
my $fcounter               = 0 ;
my $indent                 = "" ;
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
                # print diretories
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

# figure out how many columns we have available for printing
my $total_columns = int( $term_width / $COLUMN_SIZE ) ;

my $column_count = 0 ;
foreach my $dir ( @directory_args ) {
    if ( opendir( DIR, "$dir" )) {
        $column_count++ ;

        @directories    = () ;
        @files          = () ;
        @block_spec     = () ;
        @char_spec      = () ;
        @sockets        = () ;
        @pipes          = () ;
        @unsatisfied    = () ;

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
            my $num_cols = 0 ;
            $index++ ;
            my $pr_flag = $things_print_flag[ $index-1 ] ;

            next if ((  $things_print_flags & $pr_flag ) != $pr_flag );

            my $size = @$thing ;
            if ( $size ) {

                if (( $one_per_line_flag == 0 ) and
                    ( $ok_to_print_flag )) {
                    print "\n" if ( $printed_something ) ;
                    print "$indent$things_title[ $index-1 ]" ;
                }
                $printed_something++ ;
                my $entry_num = 0 ;
                my $need_newline ;
                foreach my $d ( sort( @$thing )) {
                    if ( $one_per_line_flag ) {
                        print "$d\n" if ( $ok_to_print_flag );
                        $fcounter++ ;
                        next ;
                    }

                    my $squeezed_in = 0 ;
                    my $len = length( $d ) ;

                    # need at least a space between
                    $len++ ;

                    my $num_widths = int( $len / $COLUMN_SIZE ) ;
                    $num_widths++ if (($len % $COLUMN_SIZE ) != 0);
                    my $column_size = $num_widths * $COLUMN_SIZE ;

                    $num_cols += $num_widths ;
                    # check to see if enough room
                    if ( $num_cols > $total_columns ) {
                        if (( ( $num_cols - $num_widths ) * $COLUMN_SIZE ) + $len ) {
                            print "\n" ;
                            $num_cols = $num_widths ;
                            $entry_num = 0 ;
                        } else {
                            $column_size = $len ;
                            $squeezed_in = 1 ;
                        }
                    }
                    $entry_num++ ;
                    print "$indent" if ( $entry_num == 1 ) ;
                    my $val = sprintf( "%-${column_size}s", $d );
                    if ( $num_cols >= $total_columns ) {
                        $val =~ s/\s+$// ;
                    }
                    print "$val" ;
                    next if ( $squeezed_in ) ;

                    $need_newline = 1 ;
                    if ( $num_cols == $total_columns ) {
                        print "\n" ;
                        $need_newline = 0 ;
                        $num_cols     = 0 ;
                        $entry_num    = 0 ;
                    }
                }
                print "\n" if ( $need_newline ) ;
            }
        }
    } else {
        print "$dir: No such file or directory\n" ;
        next ;
    }
    print "\n" if (( $column_count < $num_entries ) and ( $ok_to_print_flag )) ;
}
exit(0) if ( $fcounter ) ;
exit(1) ;



# load the modules we need
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

__END__
=head1 NAME

lc - list directory and file names in columns

=head1 SYNOPSIS

lc [ -fdbcspan1 ] [ directory ... ]

=head1 DESCRIPTION

Lc  lists the elements of the given directories.  The elements are divided
into the five basic types (files, directories, character  special  files,
block  special  files,  and pipes)  and  are  printed in alphabetical
order.  They are normally printed 5 to a line, preceeded by a title
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
those  types  of entries; otherwise, all entries are listed.  The options
and their meanings are:

    f      list ordinary files

    d      list directories

    b      list block special files

    c      list character special files

    s      list all special files

    p      list permanent pipes

Lc may be used with the substitution features of the Shell to select
particular kinds of files (eg, directories) to take part in some
processing, for example:

This lists the contents of all sub-directories of the current directory.

=head1 DIAGNOSTICS

Symbolic links are normally followed, and each prints under the category
of the type  of thing  to which it is linked.  If the symbolic link
points to a nonexistent pathname, or if you do not have permission to reso

=cut
