# Nim module for working with a list of files.
# Inspired by Python's fileinput module.

# Written by Adam Chesak.
# Released under the MIT open source license.


## fileinput is a Nim module based on the ``fileinput`` module in Python's
## standard library. It can read and iterate through a list of files.
##
## For the purposes of the examples, assume two files exist called "hello"
## and "world" with the given contents:
##
## File "hello":
##
##    this is an
##    example file
##
## File "world":
##
##    fileinput can read lines
##    across files
##    1234
##    abcd
##
## Examples:
##
## .. code-block::nimrod
##    
##    # Create a file input and read the first three lines.
##    var input : FileInput = createFileInput(@["hello", "world"])
##    for i in 0..2:
##        echo(input.readCurrentLine())
##    # Output:
##    # this is an
##    # example file
##    # fileinput can read lines
##
## .. code-block::nimrod
##
##    # Create an input and iterate through all the lines.
##    var input : FileInput = createFileInput(@["hello", "world"])
##    for line in lines(input):
##        echo(line)
##    # Outputs all the lines in the fileinput


import strutils
import sequtils


type
    FileInput* = ref object
        files* : seq[File]
        filenames* : seq[string] ## ``filenames`` may be undefined, depending on how the FileInput object was created.
        fromFilenames : bool
        currentFile* : int
        currentFilename* : string
        currentLine* : int


proc createFileInput*(files : seq[File]): FileInput =
    ## Creates a ``FileInput`` object from a given list of files.

    return FileInput(files: files, currentFile: 0, currentLine: 0, fromFilenames : false)


proc createFileInput*(files : seq[string]): FileInput =
    ## Creates a ``FileInput`` object from a given list of filenames.

    var filelist = newSeq[File](len(files))
    for i in 0..high(files):
        filelist[i] = open(files[i], fmRead)

    return FileInput(files: filelist, filenames: files, currentFile: 0, currentLine: 0, currentFilename: files[0],
                     fromFilenames: true)


proc nextFile*(input : FileInput): int =
    ## Moves the ``input`` to the next file and resets the line index. If already on the last file, ends the ``input``.
    ## Returns the current file index.

    if input.currentFile == -1:
        return -1

    elif input.currentFile == high(input.files):
        input.currentFile = -1
        input.currentLine = 0
        return -1

    else:
        input.currentFile += 1
        input.currentLine = 0
        if input.fromFilenames:
            input.currentFilename = input.filenames[input.currentFile]
        return input.currentFile


proc previousFile*(input : FileInput): int =
    ## Moves the input to the previous file and resets the line index. If already on the first file, only resets the
    ## line index. Returns the current file index, or ``-1`` if ``input`` has been ended.

    if input.currentFile == -1:
        return -1

    elif input.currentFile == 0:
        input.currentLine = 0
        return 0

    else:
        input.currentFile -= 1
        input.currentLine = 0
        if input.fromFilenames:
            input.currentFilename = input.filenames[input.currentFile]
        return input.currentFile


proc nextFilename*(input : FileInput): string =
    ## Same behavior as ``nextFile()``, but returns the next filename instead of file index. Returns ``nil`` if ``input``
    ## has been ended, ``input`` was not created from a list of filenames, or ``input`` closes as a result of this proc.

    if input.currentFile == -1:
        return nil

    elif not input.fromFilenames:
        return nil

    elif input.currentFile == high(input.files):
        input.currentFile = -1
        input.currentLine = 0
        return nil

    else:
        input.currentFile += 1
        input.currentLine = 0
        input.currentFilename = input.filenames[input.currentFile]
        return input.currentFilename


proc previousFilename*(input : FileInput): string =
    ## Same behavior as ``previousFile()``, but returns the previous filename instead of file index. Returns ``nil`` if ``input``
    ## has been ended or if ``input`` was not created from a list of filenames.

    if input.currentFile == -1:
        return nil

    elif not input.fromFilenames:
        return nil

    elif input.currentFile == 0:
        input.currentLine = 0
        return input.currentFilename

    else:
        input.currentFile -= 1
        input.currentLine = 0
        input.currentFilename = input.filenames[input.currentFile]
        return input.currentFilename


proc closeInput*(input : FileInput) {.noreturn.} =
    ## Immediately closes the ``input``.

    input.currentFile = -1
    input.currentLine = 0

    for file in input.files:
        file.close()


proc isClosed*(input : FileInput): bool =
    ## Returns whether or not ``input`` has been closed.

    return input.currentFile == -1


proc getLineNumber*(input : FileInput): int =
    ## Gets the cumulative current line number. Note that this is different from ``FileInput.currentLine``, as that property
    ## holds the current line number of only the current file. Returns ``-1`` if ``input`` has been ended.

    if input.currentFile == -1:
        return -1

    elif input.currentFile == 0:
        return input.currentLine

    else:
        var lines : int = 0
        for i in 0..(input.currentFile - 1):
            input.files[i].setFilePos(0)
            lines += len(readAll(input.files[i]).splitLines())
            input.files[i].setFilePos(0)
        lines += input.currentLine
        return lines


proc getCurrentFile*(input : FileInput): int =
    ## Gets the current file index. Returns ``-1`` if ``input`` has been ended.

    return input.currentFile


proc readCurrentFile*(input : FileInput): string =
    ## Reads the current file from the ``input``. Returns the contents of the file. Automatically advances the ``input`` to the
    ## next file. Disregards current line number. Returns empty string if ``input`` has been ended.

    if input.currentFile == -1:
        return nil

    input.files[input.currentFile].setFilePos(0)
    var contents : string = readAll(input.files[input.currentFile])
    input.files[input.currentFile].setFilePos(0)
    discard input.nextFile()

    return contents


proc readCurrentLine*(input : FileInput): string =
    ## Reads the current line from the ``input``. Returns the line. Automatically advances the ``input`` to the next line. If the last
    ## line of the current file is read, automatically advances to the next file. Returns empty string if ``input`` has been ended.

    if input.currentFile == -1:
        return nil

    var nextLine : int = input.currentLine + 1
    var curPos : int = int(input.files[input.currentFile].getFilePos())
    input.files[input.currentFile].setFilePos(0)
    var numLines : int = len(input.files[input.currentFile].readAll().splitLines())
    input.files[input.currentFile].setFilePos(curPos)

    if nextLine == numLines:
        discard input.nextFile()
        return input.readCurrentLine()

    var contents : string = input.files[input.currentFile].readLine()

    if nextLine == numLines:
        discard input.nextFile()
    else:
        input.currentLine = nextLine

    return contents


iterator lines*(input : FileInput): string = 
    ## Iterates through the lines in the ``input``.

    while true:
        var line : string = input.readCurrentLine()
        if line == nil:
            break
        yield line


iterator files*(input : FileInput): string = 
    ## Iterates through the files in the ``input``.

    while true:
        var file : string = input.readCurrentFile()
        if file == nil:
            break
        yield file
