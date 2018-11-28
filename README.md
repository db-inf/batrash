# batrash

Batrash implements trashing based on the [FreeDesktop.org Trash specification version 1.0]( https://specifications.freedesktop.org/trash-spec/trashspec-1.0.html), the _-Standard-_, with support for bind mounts.

## alternatives to batrash

### [Gnome's gio](https://developer.gnome.org/gio/stable/gio.html)
At least the v2.56.2 implementation of trash in Gnome's `gio trash` (formerly `gvfs-trash`) is confused by bind mounts, and prevents trashing on such mounts. Apparently `gio trash` first looks for a trash can in the file system's root, and then unjustly diagnoses that moving the file from the bind mountpoint to the file system mount point is a move to a different file system : _"Unable to delete file ... across filesystem boundaries"_.

### [trash-cli](https://github.com/andreafrancia/trash-cli)
The programs of the package `trash-cli` handle files trashed with batrash very well, so there is no need for batrash to implement other functionality than the trashing itself.

The `trash-put` command of `trash-cli` involves writing a full copy of trashed files, at least when it originates from a non-writable directory, and sometimes even writing 2 copies of that trashed file, before concluding the original can not be deleted from it's current directory, leaving you with 3 copies in total; see my [report on this issue here](https://github.com/andreafrancia/trash-cli/issues/133). In contrast batrash first verifies the original directory for writeability.

Also, in accordance with the _-Standard-_, `trash-put` creates trash cans where none are found; this is a missed opportunity for allowing an administrator to tune trashing differently on different file systems.

Also, when `trash-put` creates a multi-user [_mount point trash can_](#trash-cans), it does so without setting the sticky bit on. Even `trash-cli`'s own `trash-list` does not accept this nonconformity.

## deviations from the _-Standard-_

### bind mounts
The _-Standard-_ is ambiguous about the terms _file system_ and _mounted resource_, and therefor does not take the technique of bind mounting into account properly. With bind mounting, a file is indeed accessible under 2 mount points, one for the file system itself, and one where a directory of that file system is bound to some other directory, possibly in another file system. This causes confusion in some implementations of the _-Standard-_.

Batrash considers the top directory of a bind mountpoint, which may not be the top directory of a file system, as a valid top directory for creating a trash can.

In such case, two trash cans can coexist on the same file system, one directly under the bind mountpoint, and one directly under the file system mount point. The path from which a file is trashed will determine the trash can where it is moved to. If no trash can exists on that path, batrash will not trash the file, even if a valid trash can exists on the other path, nor will batrash deleted it. This behaviour is by necessity, because there is to my knowledge no documented standard way, for a shell script, to determine the file system mount point of a bind mountpoint. It can be parsed from the output of (some versions of ?) the findmount command `findmnt -no source mountpoint`, with `mountpoint` a bind mountpoint; such approach would be a hack, not a reliable solution for handling your precious files.

### trash can creation
In deviation from the _-Standard-_, batrash will not create a trash can anywhere, so that you can control trashing behaviour of the different filesystems in your directory tree by creating trash cans on them or not. This deviation from the standard does not cause conflicts with other trash implementations.

### directory size cache
In deviation from the _-Standard-_, batrash will not maintain a directory size cache. I doubt the usefulness and the intended implementation of that feature, nor do I see any other tool maintaining it. Therefor this deviation possibly does not cause conflicts with other trash implementations.

### trashinfo `Path` key
I disagree with, but do not deviate from, the _-Standard-_ on the point of the `Path` key of the `.trashinfo` file for the [_home trash can_](#trash-cans). It would clearly be more appropriate to store a path relative to the user's `$HOME` directory, for files that reside under that directory. Instead the _-Standard-_ requires a path relative to the `$XDG_DATA_HOME` directory, which defaults to `~/.local/share`, but forbids to use `..` path components. And exactly because these two requirements contradict one another, the _-Standard-_ has to make an exception to the rule that `Path` must be relative, and has to allow an absolute `Path` for the _home trash can_.

## importance of trashed files
Indeed, batrash considers files in your trash can as important. Files that are deleted on purpose, probably are deemed unimportant. But a trash can is a recovery solution for accidentally deleted files, and accidentally deleted files can be very important. Therefor batrash will never delete them (unless you link a trash can in some way to `/dev/null`), and will check whether they can be moved to the trash can before doing so.

### arguments terminated by '/'
Because of the importance of accidentaly deleted or trashed files, I would prefer to simply reject directory arguments, and certainly file arguments, that are terminated by 1 or more '/'. This to avoid ambiguity like about the directory itself or it's contents, or to protect your data when you type in a filename when you intend to trash a directory. Rsync for instance handles source directories with or without terminating '/' differently too. But Gnome's "gio trash"/"gvfs-trash" and trash-cli's "trash-put", both widely used trash tools, just strip all terminating '/', even for file arguments. In this case, I think it is best not to deviate from their behaviour, and so to avoid confusion I wrote batrash to do the same.

## trash cans
A trash can is understood by batrash as either, in order of precedence

1. The **home trash can** `$XDG_DATA_HOME/Trash`, if `$XDG_DATA_HOME` is set and not empty, and else `$HOME/.local/share/Trash`, where `$HOME` is the user's home directory, if the path to the trashed item and that _home trash can_ are on the same mount point. If a file with the name of this trash can exists, it must be a directory and it must be traversable (executable) and writable by the user, or trashing will fail.
2. The **mount point trash can**, a directory `.Trash` in the top directory of the mount point whereunder the path to trashed item resides. If a file with the name of this trash can exists, it must be a real directory, not a symbolic link to one, it must have it's sticky bit set, and it must be traversable (executable) and writable by the user, or trashing will fail. In a _mount point trash can_, batrash creates a subdirectory `$userid` when it is not already present, where `$userid` is the user's id number, to serve as the user's compartment of the trash can. If a file with that name already exists, it must be a directory and it must be traversable (executable) and writable by the user, or it must already contain traversable (executable) and writable directories `files` and `info`, or trashing will fail. To support file systems that have no sticky bits, a _mount point trash can_ may also be validated by placing a file named ".stickybit" in it.
3. A **personal mount point trash can**, a directory `.Trash-$userid` in the top directory of the mount point whereunder the path to the trashed item resides, where `$userid` is the user id number. If a file with the name of this trash can exists, it must be directory and it must be traversable (executable) and writable by the user, or trashing will fail.

## trashing
If no appropriate trash can is found for every arguments to batrash, or if any of these arguments can not be removed from it's parent directory because that is not writable, then no action is taken for all the other arguments either. If any change in this condition has taken place while effectively trashing arguments to batrash, trashing is performed for all arguments that are not affected by it.

Trashing is done by a `mv` command to the trash can, or to the `./$userid` compartment of a [_mount point trash can_](#trash-cans). If the trash can is located in the same file system as the file, which is so intended with the [_trash cans](#trash-cans) described above, this should not involve writing a copy of the item to trash, only relocating it's directory entry from it's current parent to the trash can's `files` directory and writing an index into it's `info` directory. However we do not impose more restrictions on the nature of trash can directories, than those imposed by the _-Standard-_; in particular, if e.g. a `files` directory in a trash can is a symbolic link to some place on another file system, moving a trashed file to it WILL involve writing a full copy of the trashed file.

If a trash can already contains an entry with the same name (last path component) as the file to trash, a new name is formed by adding the process id number, to make it unique among all batrash instances running simultaneously, supplemented with a sequence number; when necessary, the original name is shortened to make the whole generated name no more than 128 characters long.
