# lc - a ls alternative
lc (list catalog) is an alternate to ls which separates files, directories, and
other special file types.

## Description
lc is an alternative to ls.

The original lc was on a Honeywell running GECOS at the University of
Waterloo in the mid 1970's.  From there it migrated to UNIX and was
written in C.  This open-source version is written in Perl and is based
on the man-page and the behavior of the original UNIX version lc command.
It will also work on Windows systems that use Unix tool packages like Cygwin.

lc separates out directories, special files, ordinary files, etc.
It dynamically loads modules, if available, to better handle line-lengths
of the terminal window.  It would prefer that the following modules be installed
that can be obtained from CPAN:

        Term::ReadKey  
        IO::Interactive

The behavior of this Perl version is similar to the original UW lc version
except for the usage which has been made more friendly, a version option added,
and there are a few options that original version has that are not implemented 
here (like special MPX Microsoft file types)

You can change the default maximum size of the pathnames from the original C version
from 14 to anything between 10 and 30 (inclusive) by setting the environment
variable LC_COLUMN_WIDTH.  It's my belief that the average filename length has
increased since the days the original lc was written almost a half century ago.
I personally like setting LC_COLUMN_WIDTH to 20.

The original man page for the UW lc has been included but the C code version is not,
since it's unclear if that would violate the University of Waterloo copyright.

There is also perldoc of the program which is based more on the original man-page
than the rewritten man-page now provided, as of version 0.7.  The (mostly) original
man-page is now under lc-uw.1 and is not installed with the Makefile.

## Examples
    # default listing of current directory
    server5> lc
       Directories:
       .git           
   
       Files:
       LICENSE.txt  README.md   RELEASE-NOTES    lc.1     lc.plx

    # options can be grouped together.  ie: -p and -b can also be given as -pb
    server5> lc -pb /dev
       Block Spec. Files:
       cdrom          cdrw           dvd            dvdrw          loop0
       loop1          loop2          loop3          loop4          loop5
       loop6          loop7          md127          sda            sda1
       sdb            sdb1           sdc            sdc1           sdd
       sdd1           sdd2           sdd5           sr0            
    
       Pipes:
       initctl 

    # usage (help option)
    server5> lc -h
       usage: [ -option ]* [ directory ]*
           a    print special entries as well (. and ..)
           b    list block special files
           c    list character special files
           d    list directories
           f    list ordinary files
           h    print usage and exit
           n    turn off all output
           p    list permanent pipes
           s    list all special files
           v    print version and exit
           1    print 1 entry per line
