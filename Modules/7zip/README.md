7-Zip
=====

Zip is a file archiver with a high compression ratio.

http://www.7-zip.org/

This module provides a simple PowerShell interface for 7-zip.

NOTE: *Somewhat* based on commands in 'Microsoft.PowerShell.Archive'.

Exported Commands
-----------------

### Compress-Archive

The verb "Compress" aligns with Windows Explorer's right-click
"Send To > Compressed (zipped) Folder", as well as 7-zip's
"Compress and email..." and "Compress to..." options.

`Compress-Archive [-Path <Path>] [-DestinationPath <Path>] [-Recurse] [-Force] [-Silent]`

**Path**

The path to the folder to archive.

**DestinationPath**

Optional. The path to a destination folder, or the archive file to create
('.zip' extension). If not specified, the current directory is used.

**Recurse**

Optional. If the input path is a directory, recursively include sub-directories.

**Force**

Optional. If the destination path is an existing file, attempt to remove it
before creating the archive.

**Silent**

Optional. Don't write output from the 7-zip command.

### Expand-Archive

The verb "Expand" is used as a close alternative to "Extract", which would
align more closely with Windows Explorer's "Extract All..." and 7-zip's
"Extract files...", "Extract Here" and "Extract to" options. However, it is not
one of the approved verbs.

The noun archive aligns with 7-zip's "Open Archive" and "Add to archive"
commands.

`Expand-Archive [-Path <Path>] [-DestinationPath <Path>] [-SuppressExtensionCheck] [-Flatten] [-Silent]`

**Path**

The path to the archive to expand (i.e. extract).

**DestinationPath**

Optional. The path to a destination folder. If not specified, the current
directory is used.

**SuppressExtensionCheck**

Optional. If specified, the input file can have an extension other than '.zip'.

**Flatten**

Optional. If specified, all files are extracted to the top-level of the
destination directory.

**Silent**

Optional. Don't write output from the 7-zip command.
