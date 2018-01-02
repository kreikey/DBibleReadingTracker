#!/usr/bin/env rdmd -I..

import std.stdio;
import std.datetime;
import std.algorithm;
import std.csv;
import std.conv;
import std.string;
import std.range;

string[] books = [
  "Genesis",
  "Exodus",
  "Leviticus",
  "Numbers",
  "Deuteronomy",
  "Joshua",
  "Judges",
  "Ruth",
  "1 Samuel",
  "2 Samuel",
  "1 Kings",
  "2 Kings",
  "1 Chronicles",
  "2 Chronicles",
  "Ezra",
  "Nehemiah",
  "Esther",
  "Job",
  "Psalms",
  "Proverbs",
  "Ecclesiastes",
  "Song of Songs",
  "Isaiah",
  "Jeremiah",
  "Lamentations",
  "Ezekiel",
  "Daniel",
  "Hosea",
  "Joel",
  "Amos",
  "Obadiah",
  "Jonah",
  "Micah",
  "Nahum",
  "Habakkuk",
  "Zephaniah",
  "Haggai",
  "Zechariah",
  "Malachi",
  "Matthew",
  "Mark",
  "Luke",
  "John",
  "Acts",
  "Romans",
  "1 Corinthians",
  "2 Corinthians",
  "Galatians",
  "Ephesians",
  "Philippians",
  "Colossians",
  "1 Thessalonians",
  "2 Thessalonians",
  "1 Timothy",
  "2 Timothy",
  "Titus",
  "Philemon",
  "Hebrews",
  "James",
  "1 Peter",
  "2 Peter",
  "1 John",
  "2 John",
  "3 John",
  "Jude",
  "Revelation"
];

ulong[] chapters = [
  50,
  40,
  27,
  36,
  34,
  24,
  21,
  4,
  31,
  24,
  22,
  25,
  29,
  36,
  10,
  13,
  10,
  42,
  150,
  31,
  12,
  8,
  66,
  52,
  5,
  48,
  12,
  14,
  3,
  9,
  1,
  4,
  7,
  3,
  3,
  3,
  2,
  14,
  4,
  28,
  16,
  24,
  21,
  28,
  16,
  16,
  13,
  6,
  6,
  4,
  4,
  5,
  3,
  6,
  4,
  3,
  1,
  13,
  5,
  5,
  3,
  5,
  1,
  1,
  1,
  22
];

immutable ulong[string] idByBook;

static this() {
  idByBook = cast(immutable)assocArray(zip(books, iota(0, books.length)));
}

struct BookRange {
  string start;
  string end;
}

struct SectionSpec {
  string section;
  string current;
  string target;
  int chaptsBehind;
  int daysBehind;
  string progress;
  string percentComplete;
}

struct ReadingSection {
  ulong[] bookIds;
  ulong chSum;
  int chPerDay;
  int chaptersRead;
  int daysRead;
  
  this(BookRange[] bookRangeList, int _chPerDay, int _daysRead) {
    foreach (bookRange; bookRangeList)
      bookIds ~= iota(idByBook[bookRange.start], idByBook[bookRange.end] + 1).array();
    
    chSum = bookIds.map!(a => chapters[a]).sum();
    chPerDay = _chPerDay;
    chaptersRead = _daysRead * _chPerDay;
    daysRead = _daysRead;
  } 

  string decodeChapterID(int index) {
    int count;
    ulong chapter;
    ulong savedId;

    foreach (bookId; bookIds) {
      count += chapters[bookId];
      if (count >= index ) {
        savedId = bookId;
        chapter = chapters[bookId] - (count - index);
        break;
      }
    }
    return format("%s %d", books[savedId], chapter);
  }

  int encodeChapterId(string bookAndChapter) {
    string bookName;
    int count;
    int chapter;
    ulong splitNdx;

    splitNdx = bookAndChapter.length - 1 - bookAndChapter.retro.indexOf(' ');
    bookName = bookAndChapter[0 .. splitNdx];
    chapter = bookAndChapter[splitNdx + 1 .. $].to!int;

    ulong bookId = idByBook[bookName];

    foreach (id; bookIds) {
      if (id == bookId)
        break;
      count += chapters[id];
    }
    
    count += chapter;
    return count;
  }
}

void main(string[] args) {
  int[] daysRead = args[1 .. $].to!(int[]);
  if (daysRead.length == 0)
    daysRead ~= 1;
  int ndx;

  // Read in the chunk of text
  string[] text = stdin.byLineCopy.array();

  // Extract title and separators
  string title = text[0];
  string headSeparator = text[1];
  string mainSeparator = text[3];

  // Extract Date Modified string from text
  string[] dateRow = text[2].split(" ").array();
  string* dateModified = &dateRow[1];
  
  // Process the lines we want into CSV ranges
  auto sectionRecordsRange = csvReader!SectionSpec(text[4 .. $ - 2].join("\n"), null, '\t');

  // Extract headers
  string[] sectionHeader = sectionRecordsRange.header;

  // Turn ranges into arrays
  SectionSpec[] sectionRecords = sectionRecordsRange.array();

  // Declare array of sections for later use
  ReadingSection[] sections;

  // Pick out the records we want
  SectionSpec* oldTest = &sectionRecords.find!((a, b) => a.section == b)("Old Testament")[0];
  SectionSpec* newTest = &sectionRecords.find!((a, b) => a.section == b)("New Testament")[0];
  SectionSpec* Psalms = &sectionRecords.find!((a, b) => a.section == b)("Psalms")[0];
  SectionSpec* Proverbs = &sectionRecords.find!((a, b) => a.section == b)("Proverbs")[0];

  int OTDaysRead;
  int NTDaysRead;
  int PsDaysRead;
  int PrDaysRead;

  // The semantics change based on how many arguments we passed
  if (args.length > 2) {
    // figure out which sections are active and assign arguments respectively
    OTDaysRead = oldTest.isActive() ? daysRead[ndx++] : 0;
    NTDaysRead = newTest.isActive() ? daysRead[ndx++] : 0;
    PsDaysRead = Psalms.isActive() ? daysRead[ndx++] : 0;
    PrDaysRead = Proverbs.isActive() ? daysRead[ndx++] : 0;
  } else {
    OTDaysRead = oldTest.isActive() ? daysRead[0] : 0;
    NTDaysRead = newTest.isActive() ? daysRead[0] : 0;
    PsDaysRead = Psalms.isActive() ? daysRead[0] : 0;
    PrDaysRead = Proverbs.isActive() ? daysRead[0] : 0;
  }

  // Get dates and days elapsed
  Date lastModDate = (*dateModified).fromShortHRStringToDate();
  Date todaysDate = cast(Date)(Clock.currTime());
  long daysElapsed = (todaysDate - lastModDate).total!"days";

  // Initialize Reading Sections
  ReadingSection OTSection = ReadingSection([ BookRange("Genesis", "Job"),
                                              BookRange("Ecclesiastes", "Malachi") ],
                                            6, OTDaysRead);
  sections ~= OTSection;
  ReadingSection NTSection = ReadingSection([ BookRange("Matthew", "Revelation") ],
                                            2, NTDaysRead);
  sections ~= NTSection;
  ReadingSection PsSection = ReadingSection([ BookRange("Psalms", "Psalms") ],
                                            1, PsDaysRead);
  sections ~= PsSection;
  ReadingSection PrSection = ReadingSection([ BookRange("Proverbs", "Proverbs") ],
                                            1, PrDaysRead);
  sections ~= PrSection;
  // How do I determine whether to loop around or stop when a ReadingSection is finished (inactive)?
  // I simply change the progress column, arbitrarily setting one number to be different than the
  // other one. It's a trick, but it works.
 
  // Update table with days read
  updateRecord(OTSection, oldTest, daysElapsed);
  updateRecord(NTSection, newTest, daysElapsed);
  updateRecord(PsSection, Psalms, daysElapsed);
  updateRecord(PrSection, Proverbs, daysElapsed);
  *dateModified = todaysDate.toShortHRString();

  // write updated table along with related information
  writeln(title);
  writeln(headSeparator);
  writeln(dateRow.join(" "));
  writeln(mainSeparator);
  writeln(sectionHeader.join("\t"));
  foreach(record; sectionRecords) {
    with(record) {
      writefln("%s\t%s\t%s\t%s\t%s\t%s\t%s", section, current, target, chaptsBehind, daysBehind, progress, percentComplete);
    }
  }
  writeln(mainSeparator);
  write("Status: completed ");
  foreach(i, section; sections) {
    if (i == 0)
      writef("%s", section.daysRead);
    else if (i == sections.length - 1)
      if (i == 1)
        writef(" and %s", section.daysRead);
      else
        writef(", and %s", section.daysRead);
    else
      writef(", %s", section.daysRead);
  }
  writefln(" days worth of reading in %s days", daysElapsed);
}

void updateRecord(ReadingSection section, SectionSpec* record, long daysElapsed) {
  int targetId, currentId;
  int[] progress;

  progress = record.progress.split("/").map!(to!int).array();
  if (progress[0] > progress[1]) {  // The condition for resetting progress
    currentId = section.chPerDay;
    targetId = section.chPerDay;
  } else {
    targetId = section.encodeChapterId(record.target);
    currentId = section.encodeChapterId(record.current);
    targetId += daysElapsed * section.chPerDay;
    if (targetId > section.chSum)
      targetId = cast(int)section.chSum;
    currentId += section.chaptersRead;
    if (currentId > section.chSum)
      currentId = cast(int)section.chSum;
  }
  record.chaptsBehind = targetId - currentId;
  record.daysBehind = record.chaptsBehind / section.chPerDay;
  record.target = section.decodeChapterID(targetId);
  record.current = section.decodeChapterID(currentId);
  record.progress = format("%s/%s", currentId, section.chSum);
  record.percentComplete = format("%.1f %%", (cast(double)currentId / section.chSum * 100));
}

string toShortHRString(Date someDate)
{
  with (someDate) {
    return format("%d/%d/%d", month, day, year - 2000);
  }
}

Date fromShortHRStringToDate(string dateStr)
{
  int[] mdy = dateStr.split("/").to!(int[]);
  return Date(mdy[2] + 2000, mdy[0], mdy[1]);
}

string toHRString(Date someDate)
{
  with (someDate) {
    return format("%s/%s/%s", month, day, year);
  }
}

Date fromHRStringToDate(string dateStr)
{
  string[] mdyStr = dateStr.split("/");
  int[] mdy;
  Month m = mdyStr[0].to!(Month);
  mdy ~= m;
  mdy ~= mdyStr[1 .. $].to!(int[]);
  return Date(mdy[2], mdy[0], mdy[1]);
}

bool isActive(SectionSpec* record) {
  int current;
  int total;
  int[] parts;

  parts = record.progress.split("/").map!(to!int).array();
  current = parts[0];
  total = parts[1];

  return (current != total);
}

