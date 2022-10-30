# lc - a ls alternative
lc (list catalog) is an alternate to ls which separates files, directories, and
other special file types.

## Description
lc is an alternative to ls.

The original lc was on a Honeywell running GECOS at the University of
Waterloo in the mid 1970's.  From there it migrated to UNIX and was
written in C.  This open-source version is written in Perl and is based
on the man-page and the behavior of the original UNIX version lc command.

lc separates out directories, special files, ordinary files, etc.
It dynamically loads modules, if available, to better handle line-lengths
of the terminal window.  It would prefer that the following modules be installed
that can be obtained from CPAN:

        Term::ReadKey  
        IO::Interactive

The behavior of this Perl version is the same as the original UW lc version
except for the usage which has been made more friendly and with a added version option.

The original man page for the UW lc has been included but the C code version is not,
since it's unclear if that would violate the University of Waterloo copyright.
You may find the perldoc of the program to be a bit more informative (and functional)
than the man-page.

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
           a    print special entries as well
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
