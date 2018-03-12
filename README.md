# DBibleReadingTracker
This is a Bible reading tracker program for use as a filter in Vim, to be called from a macro.

It receives a table of text and updates it based on the date, and the passed-in command line arguments.

It has hard-coded data structures defining the books in the Bible and the number of chapters in each book.

It has hard-coded data structures defining each Bible reading section as a list of ranges of books.

It is distributed under the terms of the GPL V3 License.

It works. For me.

To make it work for you, set tabstop to 20 with `:set tabstop=20` in Vim.
Also, make a macro to call the thing, by copying the following line into a register:

1G11!!BibleReadingTracker 

But you must not include the newline character! So place the cursor at the beginning of the line and use the keystrokes 

`"by$`

That means "into register b, yank everything to the end of the line inclusively."
Use mksession to save these changes into a session that you can reuse later.

Run the macro with `@b`

When you run the macro, pass in command-line arguments saying how many days' worth of reading you've done for each section.
Example:
`:.,.+10!BibleReadingTracker 1 2 2 1`
Or just pass one argument if you've read the same number of days' worth for each section
`:.,.+10!BibleReadingTracker 3`
Or just don't pass any arguments and just hit Enter if you've done one day's worth of reading.

To compile the program, run `dmd DBibleReadingTracker.d` from the OS command line.
On unix-like systems, you can also run the program as a script by making it executable and running it as
`./DBibleReadingTracker.d`
(To make it executable, first run `chmod 755 DBibleReadingTracker.d` or similar.)
Put either executable in your PATH variable and use it.

Use the sampleTable.txt file as a base to start your Bible reading program.
Change the Date field before the Start date to reset the table.
At the end of the Progress column is a "multiplicity" variable that determines how many times you want to read through each 
section in the given time frame. Change it to whatever works for you.
Change the start and end dates to whatever works for you.
Edit the source file DBibleReadingTracker.d to change the Bible Reading Sections to whatever works for you.
Each Bible Reading Section corresponds to a row in your table, by the the name in the "section" column.
