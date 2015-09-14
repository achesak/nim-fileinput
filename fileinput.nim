# Nim module for working with a list of files.
# Inspired by Python's fileinput module.

# Written by Adam Chesak.
# Released under the MIT open source license.


import strutils
import sequtils


type
    FileInput* = ref FileInputInternal
    FileInputInternal* = object
        files : seq[File]
        filenames : seq[string] ## May be undefined, depending on how the FileInput object was created.
        fromFilenames : bool    ## Meant for internal use. Don't change the value or something will likely break.
        currentFile : int
        currentFilename : string
        currentLine : int


proc input*(files : seq[File]): FileInput =
    ## Creates a ``FileInput`` object from a given list of files.
    
    return FileInput(files: files, currentFile: 0, currentLine: 0, fromFilenames : false)
    

proc input*(files : seq[string]): FileInput = 
    ## Creates a ``FileInput`` object from a given list of filenames.
    
    var filelist = newSeq[File](len(files))
    for i in 0..high(files):
        filelist[i] = open(files[i], fmRead)
    
    return FileInput(files: filelist, filenames: files, currentFile: 0, currentLine: 0, currentFilename: files[0],
                     fromFilenames: true)


proc nextFile*(input : FileInput): int = 
    ## Moves the ``input`` to the next file and resets the line index. If already on the last file, ends the ``input`.
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
    ## Same behavior as ``nextFile()``, but returns the next filename instead of file index. Returns empty string if ``input``
    ## has been ended, ``input`` was not created from a list of filenames, or ``input`` closes as a result of this proc.
    
    if input.currentFile == -1:
        return ""
    
    elif not input.fromFilenames:
        return ""
    
    elif input.currentFile == high(input.files):
        input.currentFile = -1
        input.currentLine = 0
        return ""
    
    else:
        input.currentFile += 1
        input.currentLine = 0
        input.currentFilename = input.filenames[input.currentFile]
        return input.currentFilename


proc previousFilename*(input : FileInput): string = 
    ## Same behavior as ``previousFile()``, but returns the previous filename instead of file index. Returns empty string if ``input``
    ## has been ended or if ``input`` was not created from a list of filenames.
    
    if input.currentFile == -1:
        return ""
    
    elif not input.fromFilenames:
        return ""
    
    elif input.currentFile == 0:
        input.currentLine = 0
        return input.currentFilename
    
    else:
        input.currentFile -= 1
        input.currentLine = 0
        input.currentFilename = input.filenames[input.currentFile]
        return input.currentFilename
    

proc closeInput*(input : FileInput) {.noreturn.} = 
    ## Immediately closes the ``input``. It can be reset later by using ``resetInput()``.
    
    input.currentFile = -1
    input.currentLine = 0


proc isClosed*(input : FileInput): bool =
    ## Returns whether or not ``input`` has been closed.
    
    return input.currentFile == -1


proc resetInput*(input : FileInput) {.noreturn.} = 
    ## Resets the ``input`` to the first file and first line.
    
    input.currentFile = 0
    input.currentLine = 0
    if input.fromFilenames:
        input.currentFilename = input.filenames[0]


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


proc readCurrentFile*(input : FileInput): string = 
    ## Reads the current file from the ``input``. Returns the contents of the file. Automatically advances the ``input`` to the
    ## next file. Disregards current line number. Returns empty string if ``input`` has been ended.
    
    if input.currentFile == -1:
        return ""
    
    input.files[input.currentFile].setFilePos(0)
    var contents : string = readAll(input.files[input.currentFile])
    input.files[input.currentFile].setFilePos(0)
    discard input.nextFile()
    
    return contents


proc readCurrentLine*(input : FileInput): string = 
    ## Reads the current line from the ``input``. Returns the line. Automatically advances the ``input`` to the next line. If the last
    ## line of the current file is read, automatically advances to the next file. Returns empty string if ``input`` has been ended. 
    
    if input.currentFile == -1:
        return ""
    
    var nextLine : int = input.currentFile + 1
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


proc appendFiles*(input : FileInput, files : seq[File]) {.noreturn.} = 
    ## Appends ``files`` to the ``input``. Resets the ``input``. Note that this proc does nothing if the ``input`` was created
    ## with a list of filenames; use ``appendFiles()`` with filenames to append to an ``input`` created this way.
    
    if input.fromFilenames:
        return
    
    input.files = concat(input.files, files)
    input.resetInput()


proc appendFiles*(input : FileInput, files : seq[string]) {.noreturn.} = 
    ## Appends ``files`` to the ``input``. Resets the ``input``. Note that this proc can only be used if the ``input`` was created
    ## with a list of filenames; use ``appendFiles()`` with File objects to append to an ``input`` created that way,
    
    if not input.fromFilenames:
        return
    
    var filelist = newSeq[File](len(files))
    for i in 0..high(files):
        filelist[i] = open(files[i], fmRead)
    
    input.files = concat(input.files, filelist)
    input.filenames = concat(input.filenames, files)
    input.resetInput()


proc prependFiles*(input : FileInput, files : seq[File]) {.noreturn.} = 
    ## Prepends ``files`` to the ``input``. Resets the ``input``. Note that this proc does nothing if ``input`` was created 
    ## with a list of filenames; use ``prependFiles()`` with filenames to prepend to an ``input`` created this way.
    
    if input.fromFilenames:
        return
    
    input.files = concat(files, input.files)
    input.resetInput()


proc prependFiles*(input : FileInput, files : seq[string]) {.noreturn.} = 
    ## Prepends ``files`` to the ``input``. Resets the ``input``. Note that this proc can only be used if the ``input`` was created
    ## with a list of filenames; use ``prependFiles()`` with File objects to prepend to an ``input`` created that way,
    
    if not input.fromFilenames:
        return
    
    var filelist = newSeq[File](len(files))
    for i in 0..high(files):
        filelist[i] = open(files[i], fmRead)
    
    input.files = concat(filelist, input.files)
    input.filenames = concat(files, input.filenames)
    input.resetInput()


proc insertFiles*(input : FileInput, files : seq[File], position : int) {.noreturn.} = 
    ## Inserts ``files`` to the ``input`` at the given ``position``. Resets the ``input``. Note that this proc does nothing if ``input``
    ## was created with a list of filenames; use ``insertFiles()`` with filenames to insert to an ``input`` created this way.
    
    if input.fromFilenames:
        return
    
    var files1 : seq[File] = input.files[0..position-1]
    var files2 : seq[File] = input.files[position..high(input.files)]
    
    input.files = concat(files1, files, files2)
    input.resetInput()


proc insertFiles*(input : FileInput, files : seq[string], position : int) {.noreturn.} = 
    ## Inserts ``files`` to the ``input`` at the given ``position``. Reset the ``input``. Note that this proc can only be used if
    ## the ``input`` was created with a list of filenames; use ``insertFiles()`` with File objects to insert to an ``input`` created
    ## that way.
    
    if not input.fromFilenames:
        return
    
    var filelist = newSeq[File](len(files))
    for i in 0..high(files):
        filelist[i] = open(files[i], fmRead)
    
    var files1 : seq[string] = input.filenames[0..position-1]
    var files2 : seq[string] = input.filenames[position..high(input.filenames)]
    var filelist1 : seq[File] = input.files[0..position-1]
    var filelist2 : seq[File] = input.files[position..high(input.files)]
    
    input.files = concat(filelist1, filelist, filelist2)
    input.filenames = concat(files1, files, files2)
    input.resetInput()


proc removeFiles*(input : FileInput, files : seq[int]) {.noreturn.} = 
    ## Removes the files in the positions given from the ``input``. Resets the ``input``.
    
    var newFiles : seq[File] = @[]
    var newFilenames : seq[string] = @[]
    
    for i in 0..high(input.files):
        if not contains(files, i):
            newFiles.add(input.files[i])
            if input.fromFilenames:
                newFilenames.add(input.filenames[i])
    
    input.files = newFiles
    if input.fromFilenames:
        input.filenames = newFilenames
    input.resetInput()


proc removeFiles*(input : FileInput, files : seq[string]) {.noreturn.} = 
    ## Removes the files with the filenames given from the ``input``. Resets the ``input``. Note that this proc can only be used if
    ## the ``input`` was created with a list of filenames; use ``removeFiles()`` with positions or File objects to remove from an
    ## ``input`` created that way.
    
    if not input.fromFilenames:
        return
    
    var newFiles : seq[File] = @[]
    var newFilenames : seq[string] = @[]
    
    for i in 0..high(input.filenames):
        if not contains(files, input.filenames[i]):
            newFiles.add(input.files[i])
            newFilenames.add(input.filenames[i])
    
    input.files = newFiles
    input.filenames = newFilenames
    input.resetInput()


proc removeFiles*(input : FileInput, files : seq[File]) {.noreturn.} = 
    ## Removes the files with the File objects given from the ``input``. Resets the ``input``. Note that simply having the same filename
    ## is not enough for these objects to match.
    
    var newFiles : seq[File] = @[]
    var newFilenames : seq[string] = @[]
    
    for i in 0..high(input.files):
        if not contains(files, input.files[i]):
            newFiles.add(input.files[i])
            if input.fromFilenames:
                newFilenames.add(input.filenames[i])
    
    input.files = newFiles
    if input.fromFilenames:
        input.filenames = newFilenames
    input.resetInput()

