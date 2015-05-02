# lc - a ls alternative

## Description
lc is an alternative to ls.

It separates out directories, special files, ordinary files, etc.
It dynamically loads modules, if available, to better handle line-lengths
of the terminal window.  It would prefer that the modules be installed:

    Term::ReadKey

    IO::Interactive
