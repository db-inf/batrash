# `batrash`

`batrash` implements trashing based on the [FreeDesktop.org Trash specification version 1.0]( https://specifications.freedesktop.org/trash-spec/trashspec-1.0.html), the _-Standard-_, with support for bind mounts.

## contents

- [importance of trashed files](#importance)
- [alternatives to `batrash`](#alternatives)
    - [Gnome's gio trash](#Gnome)
    - [trash-cli](#trash-cli)
- [deviations from the _-Standard-_](#deviations)
    - [bind mounts](#bind)
    - [trash can creation](#creation)
    - [directory size cache](#cache)
    - [trashinfo `Path` key](#Path)
    - [arguments terminated by '`/`'](#terminated)
- [trash cans](#cans)
- [trashing](#trashing)
- [extra's : spacefm plugins for batrash](#spacefm)

<a name="importance"/>
## importance of trashed files

Indeed, `batrash` considers files in your trash can as important. Files that are deleted on purpose, probably are deemed unimportant. But a trash can is a recovery solution for accidentally deleted files, and accidentally deleted files can be very important. Therefor `batrash` will never delete them (unless you link a trash can in some way to `/dev/null`), and will check whether they can be moved to the trash can before doing so.

<a name="alternatives"/>
## alternatives to `batrash`

<a name="Gnome"/>
### [Gnome's gio trash](https://developer.gnome.org/gio/stable/gio.html)
At least the v2.56.2 implementation of trash in Gnome's `gio trash` (formerly `gvfs-trash`) is confused by bind mounts, and prevents trashing on such mounts. Apparently `gio trash` first looks for a trash can in the file system's root, and then unjustly diagnoses that moving the file or directory from the bind mountpoint to the file system mount point is a move to a different file system : _"Unable to delete file ... across filesystem boundaries"_.

<a name="trash-cli"/>
### [trash-cli](https://github.com/andreafrancia/trash-cli)
The programs of the package `trash-cli` handle files trashed with `batrash` very well, so there is no need for `batrash` to implement other functionality than the trashing itself.

The `trash-put` command of `trash-cli`, however, involves writing a full copy of a trashed item, at least when it originates from a non-writable directory, and sometimes even writing 2 copies of it, before concluding the original can not be deleted from it's current directory. `trash-put` can leave you with 3 copies of the trashed item in total; see my [report on this issue](https://github.com/andreafrancia/trash-cli/issues/133). In contrast `batrash` first verifies the original directory for writability, and will not copy, but rather move a file or directory.

Also, but in full accordance with the _-Standard-_, `trash-put` creates trash cans where none are found; this is a missed opportunity for allowing an administrator to tune trashing differently on different file systems. Alas in creating a trash can, the _-Standard-_ is not followed. When `trash-put` creates a multi-user [_mount point trash can_](#trash-cans), it does not set it's sticky bit on. Even `trash-cli`'s own `trash-list` does not accept this nonconformity.

<a name="deviations"/>
## deviations from the _-Standard-_

<a name="bind"/>
### bind mounts
The _-Standard-_ is ambiguous about the terms _file system_ and _mounted resource_, and therefor can not take the technique of bind mounting into account properly. With bind mounting, a file or directory is indeed accessible under 2 mount points, one for the file system itself, and one where a directory of that file system is bound to some other directory, possibly in another file system. This causes confusion in some implementations of the _-Standard-_.

`batrash` considers the top directory of a bind mountpoint, which may not be the top directory of a file system, as a valid top directory for creating a trash can.

In such case, two trash cans can coexist on the same file system, one directly under the bind mountpoint, and one directly under the file system mount point. The path from which an item is trashed will determine the trash can where it is moved to. If no trash can exists on that path, `batrash` will not trash the item, even if a valid trash can exists on the other path, nor will `batrash` delete it. This behaviour is by necessity, because there is to my knowledge no documented standard way, for a shell script, to determine the file system mount point of a bind mountpoint. It can be parsed from the output of (some versions of ?) the findmount command `findmnt -no source mountpoint`, with `mountpoint` a bind mountpoint. But such approach would be a hack, not a reliable solution for handling your precious files.

<a name="creation"/>
### trash can creation
In deviation from the _-Standard-_, `batrash` will not create a trash can anywhere, so that you can control trashing behaviour of the different filesystems in your directory tree by creating trash cans on them or not. This deviation from the standard does not cause conflicts with other trash implementations.

<a name="cache"/>
### directory size cache
In deviation from the _-Standard-_, `batrash` will not maintain a directory size cache. I doubt the usefulness and the intended implementation of that feature, nor do I see any other tool maintaining it. Therefor this deviation possibly does not cause conflicts with other trash implementations.

<a name="Path"/>
### trashinfo `Path` key
I disagree with, but do not deviate from, the _-Standard-_ on the point of the `Path` key of the `.trashinfo` file for the [_home trash can_](#trash-cans). It would clearly be more appropriate to store a path relative to the user's `$HOME` directory, for files that reside under that directory. Instead the _-Standard-_ requires a path relative to the `$XDG_DATA_HOME` directory, which defaults to `~/.local/share`, but forbids to use `..` path components. And exactly because these two requirements contradict one another, the _-Standard-_ has to make an exception to the rule that `Path` must be relative, and has to allow an absolute `Path` for the _home trash can_.

<a name="terminated"/>
### arguments terminated by '`/`'
The _-Standard-_ says nothing about it, but on this point `batrash` deviates from the behaviour of 2 widely used alternatieve implementations of trashing.

Because of the importance of accidentaly deleted or trashed files, I would prefer to simply reject directory arguments that are terminated by 1 or more '`/`'. This to avoid ambiguity like about the directory itself or it's contents, or to protect your data when you type in a filename when you intend to trash a directory. Rsync for instance handles source directories with or without terminating '`/`' differently too. But that is far from common. Most linux programs treat these references to a directory as equivalent : `dir`, `dir/`, `dir////`, so do Gnome's `gio trash`-`gvfs-trash` and `trash-cli`'s `trash-put`, and so will `batrash`.

    $ [ -d .cache ] && echo a directory || echo NO directory
    a directory
    $ [ -d .cache/ ] && echo a directory || echo NO directory
    a directory
    $ [ -d .cache/// ] && echo a directory || echo NO directory
    a directory

However, for file arguments, I know of no other program that accepts a terminating '`/`', but both Gnome's `gio trash`-`gvfs-trash` and `trash-cli`'s `trash-put` do. `batrash` will not follow their behaviour, but will reject a terminating '`/`' on a file name, and is in good company :

    $ [ -e .bashrc ] && echo exists || echo exists NOT
    exists
    $ [ -f .bashrc ] && echo a file || echo NO file
    a file
    $ [ -e .bashrc/ ] && echo exists || echo exists NOT
    exists NOT
    $ [ -f .bashrc/ ] && echo a file || echo NO file
    NO file
    $ [ -d .bashrc/ ] && echo a directory || echo NO directory
    NO directory
    $ ls .bashrc/
    ls: cannot access '.bashrc/': Not a directory
    $ stat .bashrc/
    stat: cannot stat '.bashrc/': Not a directory

<a name="cans"/>
## trash cans
A trash can is understood by `batrash` as either, in order of precedence

1. The **home trash can** `$XDG_DATA_HOME/Trash`, if `$XDG_DATA_HOME` is set and not empty, and else `$HOME/.local/share/Trash`, where `$HOME` is the user's home directory, if the path to the trashed item is under the directory `$HOME` and is under the same mount point as that _home trash can_. If the name of this trash can exists, it must be a directory and it must be traversable (executable) and writable by the user, or trashing will fail.
2. The **mount point trash can**, a directory `.Trash` in the top directory of the mount point whereunder the path to the trashed item resides. If the name of this trash can exists, it must be a real directory, not a symbolic link to one, it must have it's sticky bit set, and it must be traversable (executable) and writable by the user, or trashing will fail. In a _mount point trash can_, `batrash` creates a subdirectory `$userid` when it is not already present, where `$userid` is the user's id number, to serve as a user compartment of the trash can. If that name already exists, it must be a directory and it must be traversable (executable) and writable by the user, or it must already contain two traversable (executable) and writable directories named `files` and `info`, or trashing will fail. To support file systems that have no sticky bits, a _mount point trash can_ may also be validated by placing a file named ".stickybit" in it.
3. A **personal mount point trash can**, a directory `.Trash-$userid` in the top directory of the mount point whereunder the path to the trashed item resides, where `$userid` is the user id number. If the name of this trash can exists, it must be directory and it must be traversable (executable) and writable by the user, or trashing will fail.

<a name="trashing"/>
## trashing
If no appropriate trash can is found for every arguments to `batrash`, or if any of these arguments can not be removed from it's parent directory because that is not writable, then no action is taken for all the other arguments either.

If any change in this condition has taken place in the time between checking it, and effectively trashing arguments to `batrash`, trashing is performed for all arguments that are not affected by it.

Trashing is done by a `mv` command to the trash can, or to the `./$userid` compartment of a [_mount point trash can_](#trash-cans). If the trash can is located in the same file system as the trashed item, which is so intended with the [_trash cans_](#trash-cans) as described above, this should not involve writing a copy of the trashed item to trash, only relocating it's directory entry from it's current parent to the trash can's `files` directory and writing an index into it's `info` directory. However we do not impose more restrictions on the nature of trash can directories, than those imposed by the _-Standard-_; in particular, if e.g. a `files` directory in a trash can is a symbolic link to some place on another file system, moving a trashed item to it WILL involve writing a full copy of the trashed item, before the original is deleted.

If a trash can already contains an entry with the same name (last path component) as new trashed item, a new name is formed by adding the process id number, to make it unique among all `batrash` instances running simultaneously, supplemented with a sequence number; when necessary, the original name is shortened to make the whole generated name no more than 128 characters long.

<a name="spacefm"/>
## extra's : spacefm plugins for batrash
- Trash.spacefm-plugin.tar.gz is a spacefm plugin (menu item Trash) that calls batrash to move files to trash, except on a tmpfs filesystem, where it deletes files right away, a personal preference of mine. If no trash can is configured for the current file system, the Trash plugin pops up an error. "Delete" is assigned as hotkey to this plugin; you might want to change the hotkey of spacefm's plain "Delete" menu item to something like "Shift+Delete", before installing this plugin.
- Del-from-Trash.spacefm-plugin.tar.gz is a spacefm plugin (menu item Del from Trash) to delete trashed files completely: first it deletes the files themselves, and then the corresponding trashinfo files in the info directory. A typical usage pattern would be to sort the trash _files_ directory on _file size_, to delete the largest trashed files, or to sort the trash _info_ directory on _date_, to delete earliest trashed files. The plugin is configured to show the menu item only in a trash can. No hotkey is assigned to it, because spacefm does not disable hotkeys when their menu items are disabled or hidden.
