# DBibleReadingTracker
This is a Bible reading tracker program for use as a filter in Vim, to be called from a macro.

It is written in the D programming language.

It receives a table of text and updates it based on the date, and the passed-in command line arguments.

It has hard-coded data structures defining the books in the Bible and the number of chapters in each book.

It parses the "readingSections.sdl" file defining each Bible reading section as a list of ranges of books.

It is distributed under the terms of the GPL V3 License.

It works. For me.

To make it work for you:
- copy sampleTable.txt into your own file
- open your file in Vim
- set tabstop to 20 with `:set tabstop=20`
- make a row for each section
- set the very last value, the one in the r/m column, to the "multiplicity" you want, i.e. how many times you want to read through that section in the given timeframe.
- set your Start and End dates, then to reset the table, set the Date field to any date before the Start date.

Don't worry about the actual values in the table. It will be reset when you start your reading plan.

Define your reading sections:
- copy readingSections.sdl into your home directory or wherever you will call the program from
- define your sections which correspond to the sections column in your reading table
- define each section as a list of bookranges where "start" is the first book in the range and "end" is the last book

The list of valid books in their order is in the comments in the provided readingSections.sdl file.
You can put as many bookranges in each section as you want, and they can even overlap if you want.
The program will simply enumerate all the books in the ranges and put them in a list.

Make a macro to call the thing, by copying the following line into a register:

```
1G11!!BibleReadingTracker 
```

But you must not include the newline character! So place the cursor at the beginning of the line and use the keystrokes 

`"by$`

That means "into register b, yank everything to the end of the line inclusively."
Use mksession to save these changes into a session that you can reuse later.

Define your Bible reading sections in readingSections.sdl, and put that file into the directory 

Run the macro with `@b`

When you run the macro, pass in command-line arguments saying how many days' worth of reading you've done for each section.
Example:

`:.,.+10!BibleReadingTracker 1 2 2 1`

Or just pass one argument if you've read the same number of days' worth for each section

`:.,.+10!BibleReadingTracker 3`

Or just don't pass any arguments and just hit Enter if you've done one day's worth of reading for each section.

To compile the program, run `dmd -i DBibleReadingTracker.d` from the OS command line.
On unix-like systems, you can also run the program as a script by making it executable and running it as
`./BibleReadingTracker.d`
Running the program as a script is no longer supported because that would require you to move the sdlang import folder into the same 
directory as the BibleReadingTracker.d file, which is annoying and impractical (but you can do it if you want),
and we now load the reading sections from a file, reducing the need to recompile.
(To make it executable, first run `chmod 755 DBibleReadingTracker.d` or similar.)
Put either executable in your PATH variable and use it.

