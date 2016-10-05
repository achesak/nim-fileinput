About
=====

nim-fileinput is a Nim module based on the ``fileinput`` module in Python's
standard library. It can read and iterate through a list of files.

For the purposes of the examples, assume two files exist called "hello"
and "world" with the given contents:

File "hello":

    this is an
    example file

File "world":

    fileinput can read lines
    across files
    1234
    abcd

Examples:

 
    # Create a file input and read the first three lines.
    var input : FileInput = createFileInput(@["hello", "world"])
    for i in 0..2:
        echo(input.readCurrentLine())
    # Output:
    # this is an
    # example file
    # fileinput can read lines


    # Create an input and iterate through all the lines.
    var input : FileInput = createFileInput(@["hello", "world"])
    for line in lines(input):
        echo(line)
    # Outputs all the lines in the fileinput

License
=======

nim-fileinput is released under the MIT open source license.