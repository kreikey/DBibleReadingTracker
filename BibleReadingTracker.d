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
//import std.traits;
import core.exception;

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
  idByBook = zip(books, iota(0, books.length)).assocArray();
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

struct Chapter {
  // TODO: we want 2 IDs: the plan ID and the section ID. Something like planID and secID. Section ID disregards multiplicity.
  string name;
  ulong planID;
  ulong secID;
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
      if (chapterID <= index) {
        savedID = bookID;
        chapter = chapters[bookID] - index + chapterID;
        break;
      }
    }
    return format("%s %d", books[savedID], chapter);
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

    foreach (id; bookIDs) {
      if (id == bookID)
        break;
      index += chapters[id];
    }
    
    index += chapter;
    return index;
  }

  auto byDay(ulong totalDays, ulong multiplicity) {
    ReadingSection* parent = &this;

    struct Result {
      //ulong totalDays;
      //ulong multiplicity;
      ulong chaptersInSection;
      ulong totalChapters;
      ulong frontDay;
      ulong backDay;
      bool empty = true;
      ulong length;

      this(ulong _totalDays, ulong _multiplicity) { 
        //totalDays = _totalDays;
        //multiplicity = _multiplicity;
        chaptersInSection = parent.totalChapters;
        totalChapters = chaptersInSection * _multiplicity;
        frontDay = 1;
        backDay = _totalDays;
        empty = backDay != frontDay;
        length = _totalDays + 1;
      }

      Chapter front() @property {
        //writeln("Debug:");
        //writefln("frontDay: %s, totalChapters: %s, totalDays: %s, multiplicity: %s", frontDay, totalChapters, totalDays, multiplicity);
        //writeln("Debug: ", (frontDay * chaptersInPlan / totalDays) % multiplicity);
        //return frontDay * totalChapters / length - 1;
        ulong planID = frontDay * totalChapters / (length - 1);
        //string chapterName = parent.decodeChapterID(planID % chaptersInSection);
        ulong secID = (planID - 1) % chaptersInSection + 1;
        string chapterName = parent.decodeChapterID(secID);
        return Chapter(chapterName, planID, secID);
      }
      Chapter back() @property {
        ulong planID = backDay * totalChapters / (length - 1);
        //string chapterName = parent.decodeChapterID(planID % chaptersInSection);
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
        ulong planID = currentDay * totalChapters / (length - 1);
        //writeln((planID - 1) % chaptersInSection + 1);
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
  //writeln(typeof(updateRecord).stringof);

  string tableResetMsg = "";
  long daysElapsed = 0;

  if (lastModDate < startDate) {
    daysElapsed++;
    tableResetMsg ~= "Table reset; ";
    lastModDate = startDate;
  }
  daysElapsed += (todaysDate - lastModDate).total!"days";

  ReadingSection[string] sectionByName = [
    "Old Testament" : ReadingSection([BookRange("Genesis", "Job"),
        BookRange("Ecclesiastes", "Malachi")]),
    "New Testament" : ReadingSection([BookRange("Matthew", "Revelation")]),
    "Psalms" : ReadingSection([BookRange("Psalms", "Psalms")]),
    "Proverbs" : ReadingSection([BookRange("Proverbs", "Proverbs")])
  ];

  // Update table with days read
  foreach(ref record, daysRead; lockstep(sectionRecords, daysRead)) {
    updateRecord(record, sectionByName[record.section], daysRead);
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
  long targetDayOld = (lastModDate - startDate).total!"days" + 1;
  long targetDayNew = (todaysDate - startDate).total!"days" + 1;
  long totalDays = (endDate - startDate).total!"days" + 1;

  void updateRecord(ref SectionSpec record, ReadingSection section, long daysRead) {
    long[4] progress = record.getProgress();
    long readThrough = progress[2];
    long multiplicity = progress[3];
    long daysBehind = record.getBehind()[1];
    auto chapterByDay = section.byDay(totalDays, multiplicity);
    assert(isRandomAccessRange!(typeof(chapterByDay)));

    long curDayOld = targetDayOld - daysBehind;
    if (reset) {
      curDayOld = 0;
      if (daysRead == 0)
        daysRead = 1;
    } else if (curDayOld + daysRead > totalDays) {
      daysRead = totalDays - curDayOld;
    }
    long curDayNew = curDayOld + daysRead;

    long nextDay = curDayNew + 1; // handle chaptersToRead issue here by limiting nextDay depending on totalDays
    if (curDayNew >= totalDays)
      nextDay--;

    if (targetDayNew > chapterByDay.length)
      targetDayNew = chapterByDay.length;

    readThrough = (chapterByDay[curDayNew].planID - 1) / section.totalChapters + 1;

    //writeln(curDayNew);
    record.current = chapterByDay[curDayNew].name;
    record.target = chapterByDay[targetDayNew].name;
    record.setBehind(chapterByDay[targetDayNew].planID - chapterByDay[curDayNew].planID, targetDayNew - curDayNew);
    record.setLastRead(chapterByDay[curDayNew].planID - chapterByDay[curDayOld].planID, daysRead);
    record.setToRead(chapterByDay[nextDay].planID - chapterByDay[curDayNew].planID);
    record.setProgress(chapterByDay[curDayNew].secID, section.totalChapters, readThrough, multiplicity);
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

bool isActive(SectionSpec record) {
  long[4] progress = record.getProgress();
  long totalChapters = progress[3] * progress[1];
  long chaptersRead = (progress[2] - 1) * progress[1] + progress[0];

  return (chaptersRead < totalChapters);
}

