#!/usr/bin/env rdmd -I..

import std.stdio;
import std.datetime;
import std.algorithm;
import std.csv;
import std.conv;
import std.string;
import std.range;
import std.typecons;
import std.format;

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
  "1 Corlonghians",
  "2 Corlonghians",
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
  string behind;
  string lastRead;
  string toRead;
  string progress;

  long[2] getBehind() {
    string[] parts = behind.split("|");
    long[2] behindParts = [parts[0].to!long(), parts[1].to!long()];
    return behindParts;
  }

  void setBehind(long chapters, long days) {
    behind = format!"%d|%d"(chapters, days);
  }

  long[2] getLastRead() {
    string[] parts = lastRead.split("|");
    long[2] lastReadParts = [parts[0].to!long(), parts[1].to!long()];
    return lastReadParts;
  }

  void setLastRead(long chapters, long days) {
    lastRead = format!("%d|%d")(chapters, days);
  }

  long getToRead() {
    return toRead.to!long();
  }

  void setToRead(long chToRead) {
    toRead = chToRead.to!string();
  }

  long[4] getProgress() {
    string[] parts = progress.split(" ");
    string[] leftParts = parts[0].split("/");
    string[] rightParts = parts[2].split("/");
    long[4] progressMul = [leftParts[0].to!long(), leftParts[1].to!long(), rightParts[0].to!long(), rightParts[1].to!long()];
    return progressMul;
  }

  void setProgress(long chRead, long totalCh, long readThrough, long multiplicity) {
    float percentage = cast(float)chRead / totalCh * 100;
    progress = format("%d/%d %.1f%% %d/%d", chRead, totalCh, percentage, readThrough, multiplicity);
  }
}

struct DateRowSpec {
  string lastModDateStr;
  string startDateStr;
  string endDateStr;
  
  Date getLastModDate() {
    string datePortion = lastModDateStr.split(" ")[1];
    return fromShortHRStringToDate(datePortion);
  }

  void setLastModDate(Date date) {
    string[] datePieces = lastModDateStr.split(" ");
    datePieces[1] = date.toShortHRString();
    lastModDateStr = datePieces.join(" ");
  }

  Date getStartDate() {
    string datePortion = startDateStr.split(" ")[1];
    return fromShortHRStringToDate(datePortion);
  }

  void setStartDate(Date date) {
    string[] datePieces = startDateStr.split(" ");
    datePieces[1] = date.toShortHRString();
    startDateStr = datePieces.join(" ");
  }

  Date getEndDate() {
    string datePortion = endDateStr.split(" ")[1];
    return fromShortHRStringToDate(datePortion);
  }

  void setEndDate(Date date) {
    string[] datePieces = endDateStr.split(" ");
    datePieces[1] = date.toShortHRString();
    endDateStr = datePieces.join(" ");
  }
}

struct ReadingSection {
  ulong[] bookIDs;
  ulong totalChapters;
  
  this(BookRange[] bookRangeList) {
    foreach (bookRange; bookRangeList)
      bookIDs ~= iota(idByBook[bookRange.start], idByBook[bookRange.end] + 1).array();
    
    totalChapters = bookIDs.map!(a => chapters[a]).sum();
  } 

  string decodeChapterID(long chapterID) {
    long index;
    ulong chapter;
    ulong savedID;

    foreach (bookID; bookIDs) {
      index += chapters[bookID];
      if (chapterID < index) {
        savedID = bookID;
        chapter = chapters[bookID] - index + chapterID + 1;
        break;
      }
    }
    return format("%s %d", books[savedID], chapter);
  }

  long encodeChapterID(string bookAndChapter) {
    string bookName;
    long index;
    ulong chapter;
    ulong splitNdx;

    splitNdx = bookAndChapter.length - 1 - bookAndChapter.retro.indexOf(' ');
    bookName = bookAndChapter[0 .. splitNdx];
    chapter = bookAndChapter[splitNdx + 1 .. $].to!ulong - 1;

    ulong bookID = idByBook[bookName];

    foreach (id; bookIDs) {
      if (id == bookID)
        break;
      index += chapters[id];
    }
    
    index += chapter;
    return index;
  }
}
long debugToReadChapterDays;
long debugDaysRead;

void main(string[] args) {
  long[] daysRead = args[1 .. $].to!(long[]);
  if (daysRead.length == 0)
    daysRead ~= 1;
  long ndx;

  // Read in the chunk of text
  string[] text = stdin.byLineCopy.array();

  // Extract title and separators
  string title = text[0];
  string headSeparator = text[1];
  string mainSeparator = text[3];

  // Extract Date Row
  DateRowSpec dateRow = csvReader!DateRowSpec(text[2], '\t').front;
  
  // Process the lines we want longo CSV ranges
  auto sectionRecordsRange = csvReader!SectionSpec(text[4 .. $ - 2].join("\n"), null, '\t');

  // Extract headers
  string[] sectionHeader = sectionRecordsRange.header;

  // Turn ranges longo arrays
  SectionSpec[] sectionRecords = sectionRecordsRange.array();

  // Declare array of sections for later use
  ReadingSection[] sections;

  // Pick out the records we want
  SectionSpec* oldTest = &sectionRecords.find!((a, b) => a.section == b)("Old Testament")[0];
  SectionSpec* newTest = &sectionRecords.find!((a, b) => a.section == b)("New Testament")[0];
  SectionSpec* Psalms = &sectionRecords.find!((a, b) => a.section == b)("Psalms")[0];
  SectionSpec* Proverbs = &sectionRecords.find!((a, b) => a.section == b)("Proverbs")[0];

  long OTDaysRead;
  long NTDaysRead;
  long PsDaysRead;
  long PrDaysRead;

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

  // Get dates
  Date startDate = dateRow.getStartDate();
  Date endDate = dateRow.getEndDate();
  Date lastModDate = dateRow.getLastModDate();
  Date todaysDate = cast(Date)(Clock.currTime());
  long daysElapsed = (todaysDate - lastModDate).total!"days" + 1;

  auto updateRecord = updateRecordInit(startDate, endDate, lastModDate, todaysDate);
  //writeln(typeof(updateRecord).stringof);

  // Initialize Reading Sections
  ReadingSection OTSection = ReadingSection([ BookRange("Genesis", "Job"),
                                              BookRange("Ecclesiastes", "Malachi") ]);
  sections ~= OTSection;
  ReadingSection NTSection = ReadingSection([ BookRange("Matthew", "Revelation") ]);
  sections ~= NTSection;
  ReadingSection PsSection = ReadingSection([ BookRange("Psalms", "Psalms") ]);
  sections ~= PsSection;
  ReadingSection PrSection = ReadingSection([ BookRange("Proverbs", "Proverbs") ]);
  sections ~= PrSection;
 
  // Update table with days read
  updateRecord(OTSection, oldTest, OTDaysRead);
  updateRecord(NTSection, newTest, NTDaysRead);
  updateRecord(PsSection, Psalms, PsDaysRead);
  updateRecord(PrSection, Proverbs, PrDaysRead);
  dateRow.setLastModDate(todaysDate);

  // write updated table along with related information
  writeln(title);
  writeln(headSeparator);
  with(dateRow) writefln("%s\t%s\t%s", lastModDateStr, startDateStr, endDateStr);
  writeln(mainSeparator);
  writeln(sectionHeader.join("\t"));
  foreach(record; sectionRecords) {
    with(record) {
      writefln("%s\t%s\t%s\t%s\t%s\t%s\t%s", section, current, target, behind, lastRead, toRead, progress);
    }
  }
  writeln(mainSeparator);
  writefln("Status: last reading completed in %s days", daysElapsed);
}

void delegate(ReadingSection, SectionSpec*, long) updateRecordInit(Date startDate, Date endDate, Date lastModDate, Date todaysDate) {
  long totalDays = (endDate - startDate).total!"days" + 1;
  long daysToDate = (todaysDate - startDate).total!"days" + 1;
  long daysToModDate = (lastModDate - startDate).total!"days" + 1;

  void updateRecord(ReadingSection section, SectionSpec* record, long daysRead) {
    long[4] progress = record.getProgress();
    long readThrough = progress[2];
    long multiplicity = progress[3];
    long lastChapter = section.encodeChapterID(record.current) + section.totalChapters * (readThrough - 1);
    long totalChapters = section.totalChapters * multiplicity;
    long daysBehind = record.getBehind()[1];

    if (lastModDate == startDate) {
      lastChapter = 0;
      daysBehind = 1;
    }

    long lastDay = daysToModDate - daysBehind;
    long currentDay = lastDay + daysRead;
    long nextDay = currentDay + 1;
    daysBehind = daysToDate - currentDay;

    long targetChapter = daysToDate * totalChapters / totalDays - 1;
    long nextChapter = nextDay * totalChapters / totalDays - 1;
    long currentChapter = currentDay * totalChapters / totalDays - 1;
    long chaptersBehind = targetChapter - currentChapter;
    long chaptersRead = currentChapter - lastChapter;
    long chaptersToRead = nextChapter - currentChapter;
    readThrough = currentChapter / section.totalChapters + 1;

    record.current = section.decodeChapterID(currentChapter % section.totalChapters);
    record.target = section.decodeChapterID(targetChapter % section.totalChapters);
    record.setBehind(chaptersBehind, daysBehind);
    record.setLastRead(chaptersRead, daysRead);
    record.setToRead(chaptersToRead);
    record.setProgress(currentChapter % section.totalChapters + 1, section.totalChapters, readThrough, multiplicity);
  }

  return &updateRecord;
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
  bool isActive = false;
  long[4] progress = record.getProgress();

  if (progress[2] != progress[3]) {
    isActive = true;
  }

  if (progress[0] != progress[1]) {
    isActive = true;
  }

  return isActive;
}

