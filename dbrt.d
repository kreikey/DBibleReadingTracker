#!/usr/bin/env rdmd -I..

import std.stdio;
import std.file;
import std.array;
import std.datetime;
import std.algorithm;
import std.csv;
import std.typecons;
import std.conv;
import std.regex;
import std.string;
import std.range;
import std.traits;

enum BibleBook
{
  Genesis,
  Exodus,
  Leviticus,
  Numbers,
  Deuteronomy,
  Joshua,
  Judges,
  Ruth,
  I_Samuel,
  II_Samuel,
  I_Kings,
  II_Kings,
  I_Chronicles,
  II_Chronicles,
  Ezra,
  Nehemiah,
  Esther,
  Job,
  Psalms,
  Proverbs,
  Ecclesiastes,
  Song_of_Songs,
  Isaiah,
  Jeremiah,
  Lamentations,
  Ezekiel,
  Daniel,
  Hosea,
  Joel,
  Amos,
  Obadiah,
  Jonah,
  Micah,
  Nahum,
  Habakkuk,
  Zephaniah,
  Haggai,
  Zechariah,
  Malachi,
  Matthew,
  Mark,
  Luke,
  John,
  Acts,
  Romans,
  I_Corinthians,
  II_Corinthians,
  Galatians,
  Ephesians,
  Philippians,
  Colossians,
  I_Thessalonians,
  II_Thessalonians,
  I_Timothy,
  II_Timothy,
  Titus,
  Philemon,
  Hebrews,
  James,
  I_Peter,
  II_Peter,
  I_John,
  II_John,
  III_John,
  Jude,
  Revelation
}

//string[] books = [
  //"Genesis",
  //"Exodus",
  //"Leviticus",
  //"Numbers",
  //"Deuteronomy",
  //"Joshua",
  //"Judges",
  //"Ruth",
  //"1 Samuel",
  //"2 Samuel",
  //"1 Kings",
  //"2 Kings",
  //"1 Chronicles",
  //"2 Chronicles",
  //"Ezra",
  //"Nehemiah",
  //"Esther",
  //"Job",
  //"Psalms",
  //"Proverbs",
  //"Ecclesiastes",
  //"Song of Songs",
  //"Isaiah",
  //"Jeremiah",
  //"Lamentations",
  //"Ezekiel",
  //"Daniel",
  //"Hosea",
  //"Joel",
  //"Amos",
  //"Obadiah",
  //"Jonah",
  //"Micah",
  //"Nahum",
  //"Habakkuk",
  //"Zephaniah",
  //"Haggai",
  //"Zechariah",
  //"Malachi",
  //"Matthew",
  //"Mark",
  //"Luke",
  //"John",
  //"Acts",
  //"Romans",
  //"1 Corinthians",
  //"2 Corinthians",
  //"Galatians",
  //"Ephesians",
  //"Philippians",
  //"Colossians",
  //"1 Thessalonians",
  //"2 Thessalonians",
  //"1 Timothy",
  //"2 Timothy",
  //"Titus",
  //"Philemon",
  //"Hebrews",
  //"James",
  //"1 Peter",
  //"2 Peter",
  //"1 John",
  //"2 John",
  //"3 John",
  //"Jude",
  //"Revelation"
//];

int[] chapters = [
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
  BibleBook[] bookList;
  int chSum;
  int chPerDay;
  
  this(string[2][] bookRangeList) {
    foreach (bookPair; bookRangeList) 
      bookList ~= [EnumMembers!BibleBook][bookPair[0].toEnum .. bookPair[1].toEnum + 1];
    chSum = bookList.map!(a => chapters[a]).sum();
  } 

  string decodeChapterID(int index) {
    int count;
    int chapter;
    BibleBook savedBook;

    foreach (book; bookList) {
      count += chapters[book];
      if (count >= index ) {
        savedBook = book;
        chapter = chapters[book] - (count - index);
        break;
      }
    }
    return format("%s %d", savedBook.toString, chapter);
  }

  int encodeChapterId(string bookAndChapter) {
    string bookName;
    int count;
    int chapter;
    string[] parts;

    parts = bookAndChapter.split(" ").array();
    bookName = parts[0];
    chapter = parts[1].to!int;
    
    BibleBook b = bookName.toEnum();

    foreach (book; bookList) {
      if (book == b)
        break;
      count += chapters[book];
    }
    
    count += chapter;
    return count;
  }
}

// The most syntactically simple solution might be 3 data structures:
// An array of book names,
// A hashmap of name:index pairs,
// A hashmap of name:chapters pairs
// Another option is 2 data structures:
// An enum of book names
// An array of chapter counts per book
// Another option is 2 data structures:
// A books array with structs of name:chapters pairs
// A hashmap of name:index pairs (or an enum of book names)
// Option:
// Array of book names
// Array of book chapters
// Hashmap of names to book index

void main(string[] args) {
  int daysRead = args[1].to!int;

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
  auto sectionRecordsRange = csvReader!SectionSpec(text[4 .. 7].join("\n"), null, '\t');

  // Extract headers
  string[] sectionHeader = sectionRecordsRange.header;

  // Turn ranges into arrays
  SectionSpec[] sectionRecords = sectionRecordsRange.array();

  // Pick out the records we want
  SectionSpec* newTest = &sectionRecords.find!((a, b) => a.section == b)("New Testament")[0];
  SectionSpec* oldTest = &sectionRecords.find!((a, b) => a.section == b)("Old Testament")[0];

  // Get dates and days elapsed
  Date lastModDate = (*dateModified).fromShortHRStringToDate();
  Date todaysDate = cast(Date)(Clock.currTime());
  long daysElapsed = (todaysDate - lastModDate).total!"days";

  // Update table with days read
  ReadingSection NTSection = ReadingSection([ ["Matthew", "Revelation"] ]);
  NTSection.chPerDay = 1;
  updateSection(NTSection, newTest, daysElapsed, daysRead);

  ReadingSection OTSection = ReadingSection([ ["Genesis", "Job"],
                               ["Ecclesiastes", "Malachi"] ]);
  OTSection.chPerDay = 2;
  updateSection(OTSection, oldTest, daysElapsed, daysRead);
  *dateModified = todaysDate.toShortHRString();

  writeln(title);
  writeln(headSeparator);
  writeln(dateRow.join(" "));
  writeln(mainSeparator);
  writeln(sectionHeader.join("\t"));
  foreach(record; sectionRecords) {
    with(record) {
      writefln("%s\t%s\t%s\t%s\t%s", section, current, target, chaptsBehind, daysBehind);
    }
  }
  writeln(mainSeparator);
  writefln("status: %s days read in %s days", daysRead, daysElapsed);
}

void updateSection(ReadingSection section, ref SectionSpec* spec, long daysElapsed, int daysRead) {
  int targetId, currentId;

  targetId = section.encodeChapterId(spec.target);
  currentId = section.encodeChapterId(spec.current);
  targetId += daysElapsed * section.chPerDay;
  if (targetId > section.chSum)
    targetId = section.chSum;
  currentId += daysRead * section.chPerDay;
  if (currentId > section.chSum)
    currentId = section.chSum;
  spec.chaptsBehind = targetId - currentId;
  spec.daysBehind = spec.chaptsBehind / section.chPerDay;
  spec.target = section.decodeChapterID(targetId);
  spec.current = section.decodeChapterID(currentId);
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

BibleBook toEnum(string bookName) {
  bookName = bookName.tr(" ", "_");
  if (bookName[0] == '1')
    bookName.replaceInPlace(0u, 1u, "I");
  else if (bookName[0] == '2')
    bookName.replaceInPlace(0u, 1u, "II");
  else if (bookName[0] == '3')
    bookName.replaceInPlace(0u, 1u, "III");
  return bookName.parse!(BibleBook);
}

string toString(BibleBook myBook) {
  string bookName = myBook.to!string;

  if (bookName[0] == 'I') {
    if (bookName[1] == 'I') {
      if (bookName[2] == 'I') {
        bookName.replaceInPlace(0u, 3u, "3");
      } else {
        bookName.replaceInPlace(0u, 2u, "2");
      }
    } else if (bookName[1] == '_') {
      bookName.replaceInPlace(0u, 1u, "1");
    }
  }
  return bookName.tr("_", " ");
}
