#!/usr/bin/env rdmd -i -I..

import std.stdio: stdin, writeln, writefln;
import std.datetime: Date, Clock, Month;
import std.algorithm: map, until, fill, sum, cumulativeFold, find;
import std.csv: csvReader;
import std.conv: to;
import std.string: format, indexOf;
import std.range: zip, split, join, iota, retro, array, assocArray, lockstep, isRandomAccessRange;
import core.exception: RangeError;
import sdlang;
import std.math;

immutable string[] books = [
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

immutable ulong[] chapters = [
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

immutable ulong[immutable(string)] idByBook;

static this() {
  idByBook = books.zip(iota(0, books.length)).assocArray();
  resetIeeeFlags();
  FloatingPointControl fpctrl;
  //fpctrl.rounding(RoundingMode.roundUp);
}

struct BookRange {
  string first;
  string last;
}

struct ChaptersDays {
  long chapters;
  long days;
}

struct SectionSpec {
  string section;
  string current;
  string target;
  string behind;
  string lastRead;
  string toRead;
  string progress;

  ChaptersDays getBehind() {
    string[] parts = behind.split("|");
    ChaptersDays result = {chapters: parts[0].to!long(), days: parts[1].to!long()};
    return result;
  }

  void setBehind(long chapters, long days) {
    behind = format!"%d|%d"(chapters, days);
  }

  ChaptersDays getLastRead() {
    string[] parts = lastRead.split("|");
    ChaptersDays result = {chapters: parts[0].to!long(), days: parts[1].to!long()};
    return result;
  }

  void setLastRead(long chapters, long days) {
    lastRead = format!("%d|%d")(chapters, days);
  }

  long[] getToRead() {
    return toRead.split("..").map!(to!long).array();
  }

  void setToRead(long chToRead) {
    toRead = chToRead.to!string();
  }

  void setToRead(long next, long last) {
    string nextStr = next.to!string();
    string lastStr = last.to!string();
    toRead = nextStr ~ ".." ~ lastStr;
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

struct Chapter {
  // We have 2 IDs: the plan ID and the section ID. Section ID indexes just the books in the section. Plan ID includes multiplicity, indexing the books numerous times, depending on multiplicity. The range of planID is a multiple of the total number of chapters in the section.
  string name;
  ulong planID;
  ulong secID;
}

struct ReadingSection {
  ulong[] bookIDs;
  ulong totalChapters;
  
  this(BookRange[] bookRangeList) {
    foreach (bookRange; bookRangeList)
      bookIDs ~= iota(idByBook[bookRange.first], idByBook[bookRange.last] + 1).array();
    
    totalChapters = bookIDs.map!(chaptersOf).sum();
  } 

  string decodeChapterID(ulong chapterID) {
    auto bookChNdx = bookIDs.zip(bookIDs.map!(chaptersOf).cumulativeFold!(sum2)()).find!(a => a[1] >= chapterID).front;
    ulong chapter = chapterID - (bookChNdx[1] - chapters[bookChNdx[0]]);

    return format("%s %d", books[bookChNdx[0]], chapter);
  }

  long encodeChapterID(string bookAndChapter) {
    string bookName;
    ulong index;
    ulong chapter;
    ulong splitNdx;

    splitNdx = bookAndChapter.length - 1 - bookAndChapter.retro.indexOf(' ');
    bookName = bookAndChapter[0 .. splitNdx];
    chapter = bookAndChapter[splitNdx + 1 .. $].to!ulong;

    ulong bookID = idByBook[bookName];

    return bookIDs.until(bookID).map!(chaptersOf).sum() + chapter;
  }

  auto byDay(ulong totalDays, ulong multiplicity) {
    ReadingSection* parent = &this;

    struct Result {
      ulong chaptersInSection;
      ulong totalChapters;
      ulong frontDay;
      ulong backDay;
      bool empty = true;
      ulong length;

      this(ulong _totalDays, ulong _multiplicity) { 
        chaptersInSection = parent.totalChapters;
        totalChapters = chaptersInSection * _multiplicity;
        frontDay = 1;
        backDay = _totalDays;
        empty = backDay != frontDay;
        length = _totalDays + 1;
      }

      Chapter front() @property {
        ulong planID = lrint(real(frontDay) * totalChapters / (length - 1));
        ulong secID = (planID - 1) % chaptersInSection + 1;
        string chapterName = parent.decodeChapterID(secID);
        return Chapter(chapterName, planID, secID);
      }
      Chapter back() @property {
        ulong planID = lrint(real(backDay) * totalChapters / (length - 1));
        ulong secID = (planID - 1) % chaptersInSection + 1;
        string chapterName = parent.decodeChapterID(secID);
        return Chapter(chapterName, planID, secID);
      }

      void popFront() {
        if (empty == false)
          frontDay++;
        if (frontDay == backDay)
          empty = true;
      }
      void popBack() {
        if (empty == false)
          backDay--;
        if (backDay == frontDay)
          empty = true;
      }

      auto save() @property {
        auto copy = this;
        return copy;
      }

      Chapter opIndex(size_t currentDay) {
        if (currentDay >= length)
          throw new RangeError("BibleReadingTracker.d");
        if (currentDay < 0)
          throw new RangeError("BibleReadingTracker.d");
        ulong planID = lrint(real(currentDay) * totalChapters / (length - 1));
        ulong secID = (planID - 1) % chaptersInSection + 1;
        string chapterName = parent.decodeChapterID(secID);
        return Chapter(chapterName, planID, secID);
      }

      ulong opDollar() {
        return length;
      }
    }
    return Result(totalDays, multiplicity);
  }

}

void main(string[] args) {
  // Read in the chunk of text
  string[] text = stdin.byLineCopy.array();

  // Extract title and separators
  string title = text[0];
  string headSeparator = text[1];
  string mainSeparator = text[3];

  // Extract Date Row
  DateRowSpec dateRow = csvReader!DateRowSpec(text[2], '\t').front;
  
  // Process the lines we want into CSV ranges
  auto sectionRecordsRange = csvReader!SectionSpec(text[4 .. $ - 2].join("\n"), null, '\t');

  // Extract headers
  string[] sectionHeader = sectionRecordsRange.header;

  // Turn ranges into arrays
  SectionSpec[] sectionRecords = sectionRecordsRange.array();

  // Fix up number of daysRead arguments
  long[] daysRead;
  daysRead.length = sectionRecords.length;
  long ndx = 1;

  if (args.length - 1 == 0) {
    daysRead.fill(1);
  } else if (args.length - 1 == 1) {
    daysRead.fill(args[1].to!long());
  } else {
    foreach (record, ref count; lockstep(sectionRecords, daysRead)) {
      count = record.isActive() ? args[ndx++].to!long() : 0;
    }
  }

  // Get dates
  Date startDate = dateRow.getStartDate();
  Date endDate = dateRow.getEndDate();
  Date lastModDate = dateRow.getLastModDate();
  Date todaysDate = cast(Date)(Clock.currTime());

  // Initialize our updateRecord closure with the day offsets we calculated so we don't have to pass a bunch of reduntant arguments to it when we update records
  auto updateRecord = updateRecordInit(startDate, endDate, lastModDate, todaysDate);

  string tableResetMsg = "";
  long daysElapsed = 0;

  if (lastModDate < startDate) {
    daysElapsed++;
    tableResetMsg ~= "Table reset; ";
    lastModDate = startDate;
  }
  daysElapsed += (todaysDate - lastModDate).total!"days";

  ReadingSection[string] sectionsByName = getSectionsFromFile("readingSections.sdl");

  // Update table with days read
  foreach(ref record, daysRead; lockstep(sectionRecords, daysRead)) {
    updateRecord(record, sectionsByName[record.section], daysRead);
  }

  // Update last-modified date
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
  writefln("Status: %scompleted last reading in %s days", tableResetMsg, daysElapsed);
}

void delegate(ref SectionSpec, ReadingSection, long) updateRecordInit(Date startDate, Date endDate, Date lastModDate, Date todaysDate) {
  bool reset = lastModDate < startDate;
  if (reset)
    lastModDate = startDate;
  // Initialize the day offsets we'll use to do our calculations
  long totalDays = (endDate - startDate).total!"days" + 1;
  long lastDay = (lastModDate - startDate).total!"days" + 1;
  if (lastDay > totalDays)
    lastDay = totalDays;
  long today = (todaysDate - startDate).total!"days" + 1;
  if (today > totalDays)
    today = totalDays;
  long tomorrow = today + 1;
  if (tomorrow > totalDays)
    tomorrow = totalDays;

  void updateRecord(ref SectionSpec record, ReadingSection section, long daysRead) {
    long[4] progress = record.getProgress();
    long multiplicity = progress[3];
    long daysBehind = record.getBehind().days;
    auto chapterByDay = section.byDay(totalDays, multiplicity);
    assert(isRandomAccessRange!(typeof(chapterByDay)));

    long lastCurDay = lastDay - daysBehind;
    if (reset) {
      lastCurDay = 0;
      if (daysRead == 0)
        daysRead = 1;
    } else if (lastCurDay + daysRead > totalDays) {
      daysRead = totalDays - lastCurDay;
    }
    long currentDay = lastCurDay + daysRead;
    if (currentDay > totalDays)
      currentDay = totalDays;

    long nextDay = currentDay + 1; // handle chaptersToRead issue here by limiting nextDay depending on totalDays
    if (nextDay > totalDays)
      nextDay = totalDays;

    Chapter lastCurChapter = chapterByDay[lastCurDay];
    Chapter curChapter = chapterByDay[currentDay];
    Chapter nextChapter = chapterByDay[nextDay];
    Chapter targetChapter = chapterByDay[today];
    Chapter tomorrowsChapter = chapterByDay[tomorrow];

    long readThrough = (curChapter.planID - 1) / section.totalChapters + 1;
    long chaptersBehind = targetChapter.planID - curChapter.planID;
    daysBehind = today - currentDay;
    long chaptersRead = curChapter.planID - lastCurChapter.planID;
    long chaptersToReadNext = nextChapter.planID - curChapter.planID;
    long chaptersToReadTomorrow = tomorrowsChapter.planID - targetChapter.planID;

    record.current = curChapter.name;
    record.target = targetChapter.name;
    record.setBehind(chaptersBehind, daysBehind);
    record.setLastRead(chaptersRead, daysRead);
    if (nextDay >= tomorrow || today == totalDays)
      record.setToRead(chaptersToReadNext);
    else
      record.setToRead(chaptersToReadNext, chaptersToReadTomorrow);
    record.setProgress(curChapter.secID, section.totalChapters, readThrough, multiplicity);
  }

  return &updateRecord;
}

ReadingSection[string] getSectionsFromFile(string filename) {
  Tag root = parseFile(filename);
  ReadingSection[string] sectionsByName;

  foreach (section; root.tags["section"]) {
    string sectionName = section.expectValue!string;

    BookRange[] bookRanges = [];

    foreach (bookrange; section.tags["bookrange"]) {
      string first = bookrange.expectAttribute!string("first");
      string last = bookrange.expectAttribute!string("last");
      bookRanges ~= BookRange(first, last);
    }

    auto readingSection = ReadingSection(bookRanges);
    sectionsByName[sectionName] = readingSection;
  }

  return sectionsByName;
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

bool isActive(SectionSpec record) {
  long[4] progress = record.getProgress();
  long totalChapters = progress[3] * progress[1];
  long chaptersRead = (progress[2] - 1) * progress[1] + progress[0];

  return (chaptersRead < totalChapters);
}

string nameOf(ulong id) {
  return books[id];
}

ulong chaptersOf(ulong id) {
  return chapters[id];
}

ulong sum2(ulong a, ulong b) {
  return a + b;
}

