#!/usr/bin/env rdmd -i -I..

import std.stdio;
import std.datetime;
import std.algorithm;
import std.csv;
import std.conv;
import std.string;
import std.range;
import core.exception;
import sdlang;
import std.math;
import std.typecons;
import std.format;
import std.exception : assumeUnique;

struct BookRange {
  string firstBook;
  string lastBook;

  auto byID() {
    ulong frontID = idByBook[firstBook];
    ulong backID = idByBook[lastBook];

    struct Result {
      void popFront() {
        if (empty) {
          throw new RangeError("BibleReadingTracker.d");
        }

        frontID++;
      }

      ulong front() @property {
        return frontID;
      }

      bool empty() @property {
        return (frontID > backID);
      }
    }

    return Result();
  }

  auto byBook() {
    ulong frontID = idByBook[firstBook];
    ulong backID = idByBook[lastBook];
   
    struct Result {
      void popFront() {
        if (empty) {
          throw new RangeError("BibleReadingTracker.d");
        }

        frontID++;
      }

      Book front() @property {
        return books[frontID];
      }

      bool empty() @property {
        return (frontID > backID);
      }
    }

    return Result();
  }
}
unittest {
  auto r = BookRange("Genesis", "Revelation");
  assert(isInputRange!(typeof(r.byID())));
  assert(isInputRange!(typeof(r.byBook())));
}

struct ChaptersDays {
  long chapters;
  long days;

  this(string input) {
    input.formattedRead!"%d|%d"(chapters, days);
  }

  this(long _chapters, long _days) {
    chapters = _chapters;
    days = _days;
  }

  string toString() {
    return format!"%d|%d"(chapters, days);
  }
}

struct ToRead {
  private ulong next;
  private Nullable!ulong tomorrow;
  private Nullable!ulong total;

  this(string input) {
    ulong _tomorrow;
    ulong _total;

    if (input.canFind(' ')) {
      input.formattedRead!"%d..%d %d"(next, _tomorrow, _total);
      tomorrow = _tomorrow;
      total = _total;
    } else {
      next = input.to!ulong();
    }
  }

  this(ulong _next) {
    next = _next;
  }

  this(ulong _next, ulong _tomorrow, ulong _total) {
    next = _next;
    tomorrow = _tomorrow;
    total = _total;
  }
  
  string toString() {
    if (tomorrow.isNull || total.isNull)
      return next.to!string();
    else
      return format!"%d..%d %d"(next, tomorrow.get, total.get);
  }
}

struct Progress {
  ulong chaptersRead;
  ulong totalChapters;
  long readThrough;
  long multiplicity;

  this(string progress) { 
    double percentRead; // A throwaway variable to make formattedRead parse correctly. We don't need it because it's a computed property.
    progress.formattedRead!"%d/%d %f%% %d/%d"(chaptersRead, totalChapters, percentRead, readThrough, multiplicity);
  }

  this(ulong _chaptersRead, ulong _totalChapters, long _readThrough, long _multiplicity) {
    chaptersRead = _chaptersRead;
    totalChapters = _totalChapters;
    readThrough = _readThrough;
    multiplicity = _multiplicity;
  }

  double percentage() @property {
    return double(chaptersRead) / totalChapters * 100;
  }

  string toString() {
    return format!"%s/%s %.1f%% %s/%s"(chaptersRead, totalChapters, percentage, readThrough, multiplicity);
  }
}

struct SectionSpec {
  string section;
  string current;
  string target;
  ChaptersDays behind;
  ChaptersDays lastRead;
  ToRead toRead;
  Progress progress;
}

struct LabelledDate {
  string label;
  Date date;
  alias date this;

  this(string labelledDateStr) {
    int month;
    int day;
    int shortYear;

    labelledDateStr.formattedRead!"%s: %d/%d/%d"(label, month, day, shortYear);
    assert(shortYear < 100 && shortYear >= 0);
    date = Date(shortYear + 2000, month, day);
  }

  this(Date sourceDate, string _label) {
    date = sourceDate;
    label = _label;
  }

  this(SysTime source, string _label) {
    date = cast(Date)source;
    label = _label;
  }
 
  string toString() {
    return format!"%s: %d/%d/%d"(label, month, day, year - 2000);
  }
}
unittest {
  auto myDate = LabelledDate("Date: 10/24/15");
  with (myDate) writefln("%s, %s, %s", month, day, year);
  with (myDate) writefln("%s: %s", label, date);
  LabelledDate rightNowDate = Clock.currTime.LabelledDate("Now");
  writeln(rightNowDate);
  LabelledDate nowWithLabel = LabelledDate(Clock.currTime(), "Label");
  writeln(nowWithLabel);
  LabelledDate nowDateLabel = LabelledDate(cast(Date)Clock.currTime(), "Label2");
  writeln(nowDateLabel);
}

struct DateRowSpec {
  LabelledDate lastModDate;
  LabelledDate startDate;
  LabelledDate endDate;
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
    bookIDs = bookRangeList
      .map!(r => r
        .byID
        .array())
      .join();

    totalChapters = bookIDs
      .map!(i => books[i].chapters)
      .sum();
  } 

  string decodeChapterID(ulong chapterID) {
    auto chaptersBook = bookIDs
      .map!(i => books[i].chapters)
      .cumulativeFold!((a, b) => a + b)
      .zip(bookIDs)
      .find!(a => a[0] >= chapterID)
      .front;

    ulong bookID = chaptersBook[1];
    ulong chapter = chapterID - (chaptersBook[0] - books[bookID].chapters);

    return format!"%s %d"(books[bookID].name, chapter);
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

    return bookIDs
      .until(bookID)
      .map!(i => books[i].chapters)
      .sum() + chapter;
  }

  auto byDay(ulong totalDays, ulong multiplicity) {
    ReadingSection* parent = &this;

    struct Result {
      ulong chaptersInSection;
      ulong totalChapters;
      ulong frontDay;
      ulong backDay;
      ulong length;

      this(ulong _totalDays, ulong _multiplicity) { 
        chaptersInSection = parent.totalChapters;
        totalChapters = chaptersInSection * _multiplicity;
        frontDay = 1;
        backDay = _totalDays;
        length = _totalDays + 1;
      }

      Chapter front() @property {
        ulong planID = lrint(double(frontDay) * totalChapters / (length - 1));
        ulong secID = (planID - 1) % chaptersInSection + 1;
        string chapterName = parent.decodeChapterID(secID);
        return Chapter(chapterName, planID, secID);
      }

      Chapter back() @property {
        ulong planID = lrint(double(backDay) * totalChapters / (length - 1));
        ulong secID = (planID - 1) % chaptersInSection + 1;
        string chapterName = parent.decodeChapterID(secID);
        return Chapter(chapterName, planID, secID);
      }

      void popFront() {
        if (empty)
          throw new RangeError("BibleReadingTracker.d");

        frontDay++;
      }

      void popBack() {
        if (empty)
          throw new RangeError("BibleReadingTracker.d");

        backDay--;
      }

      bool empty() @property {
        return (frontDay > backDay);
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
        ulong planID = lrint(double(currentDay) * totalChapters / (length - 1));
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

struct Book {
  string name;
  ulong chapters;
}

static Book[] books = [
  {"Genesis", 50},
  {"Exodus", 40},
  {"Leviticus", 27},
  {"Numbers", 36},
  {"Deuteronomy", 34},
  {"Joshua", 24},
  {"Judges", 21},
  {"Ruth", 4},
  {"1 Samuel", 31},
  {"2 Samuel", 24},
  {"1 Kings", 22},
  {"2 Kings", 25},
  {"1 Chronicles", 29},
  {"2 Chronicles", 36},
  {"Ezra", 10},
  {"Nehemiah", 13},
  {"Esther", 10},
  {"Job", 42},
  {"Psalms", 150},
  {"Proverbs", 31},
  {"Ecclesiastes", 12},
  {"Song of Songs", 8},
  {"Isaiah", 66},
  {"Jeremiah", 52},
  {"Lamentations", 5},
  {"Ezekiel", 48},
  {"Daniel", 12},
  {"Hosea", 14},
  {"Joel", 3},
  {"Amos", 9},
  {"Obadiah", 1},
  {"Jonah", 4},
  {"Micah", 7},
  {"Nahum", 3},
  {"Habakkuk", 3},
  {"Zephaniah", 3},
  {"Haggai", 2},
  {"Zechariah", 14},
  {"Malachi", 4},
  {"Matthew", 28},
  {"Mark", 16},
  {"Luke", 24},
  {"John", 21},
  {"Acts", 28},
  {"Romans", 16},
  {"1 Corinthians", 16},
  {"2 Corinthians", 13},
  {"Galatians", 6},
  {"Ephesians", 6},
  {"Philippians", 4},
  {"Colossians", 4},
  {"1 Thessalonians", 5},
  {"2 Thessalonians", 3},
  {"1 Timothy", 6},
  {"2 Timothy", 4},
  {"Titus", 3},
  {"Philemon", 1},
  {"Hebrews", 13},
  {"James", 5},
  {"1 Peter", 5},
  {"2 Peter", 3},
  {"1 John", 5},
  {"2 John", 1},
  {"3 John", 1},
  {"Jude", 1},
  {"Revelation", 22}
];

immutable ulong[string] idByBook;

static this() {
  auto temp = books
    .map!(b => b.name)
    .enumerate
    .map!(reverse)
    .assocArray();
  temp.rehash();
  idByBook = assumeUnique(temp);
  resetIeeeFlags();
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

  // Get today's date
  LabelledDate todaysDate = Clock.currTime.LabelledDate(dateRow.lastModDate.label);

  // Initialize our updateRecord closure with the day offsets we calculated so we don't have to pass a bunch of reduntant arguments to it when we update records
  auto updateRecord = updateRecordInit(dateRow.startDate, dateRow.endDate, dateRow.lastModDate, todaysDate);

  string tableResetMsg = "";
  long daysElapsed = 0;

  if (dateRow.lastModDate < dateRow.startDate) {
    daysElapsed++;
    tableResetMsg ~= "Table reset; ";
    dateRow.lastModDate.date = dateRow.startDate.date;
  }
  daysElapsed += (todaysDate - dateRow.lastModDate).total!"days";

  ReadingSection[string] sectionsByName = getSectionsFromFile("readingSections.sdl");

  // Update table with days read
  foreach(ref record, daysRead; lockstep(sectionRecords, daysRead)) {
    updateRecord(record, sectionsByName[record.section], daysRead);
  }

  // Update last-modified date
  dateRow.lastModDate.date = todaysDate.date;

  // write updated table along with related information
  writeln(title);
  writeln(headSeparator);
  with(dateRow) writefln!"%s\t%s\t%s"(lastModDate, startDate, endDate);
  writeln(mainSeparator);
  writeln(sectionHeader.join("\t"));
  foreach(record; sectionRecords) {
    with(record) {
      writefln!"%s\t%s\t%s\t%s\t%s\t%s\t%s"(section, current, target, behind, lastRead, toRead, progress);
    }
  }
  writeln(mainSeparator);
  writefln!"Status: %scompleted last reading in %s days"(tableResetMsg, daysElapsed);
}

// The return type of this function is void delegate(ref SectionSpec, ReadingSection, long), but auto is more readable.
auto updateRecordInit(LabelledDate startDate, LabelledDate endDate, LabelledDate lastModDate, LabelledDate todaysDate) {
  bool reset = lastModDate < startDate;

  if (reset)
    lastModDate.date = startDate.date;

  // Initialize the day offsets we'll use to do our calculations
  long totalDays = (endDate - startDate).total!"days" + 1;
  auto limitDays = limitDaysInit(totalDays);

  long lastDay = (lastModDate - startDate).total!"days" + 1;
  long today = (todaysDate - startDate).total!"days" + 1;
  long tomorrow = today + 1;

  limitDays(&lastDay, &today, &tomorrow);

  void updateRecord(ref SectionSpec record, ReadingSection section, long daysRead) {
    long multiplicity = record.progress.multiplicity;
    long daysBehind = record.behind.days;
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
    limitDays(&currentDay);

    long nextDay = currentDay + 1; // handle chaptersToRead issue here by limiting nextDay depending on totalDays
    limitDays(&nextDay);

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
    record.behind = ChaptersDays(chaptersBehind, daysBehind);
    record.lastRead = ChaptersDays(chaptersRead, daysRead);
    record.toRead = (nextDay >= tomorrow || today == totalDays) ?
      ToRead(chaptersToReadNext) :
      ToRead(chaptersToReadNext, chaptersToReadTomorrow, (chaptersBehind + chaptersToReadTomorrow));
    record.progress = Progress(curChapter.secID, section.totalChapters, readThrough, multiplicity);
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

bool isActive(SectionSpec record) {
  long totalChapters = record.progress.multiplicity * record.progress.totalChapters;
  long chaptersRead = (record.progress.readThrough - 1) * record.progress.totalChapters + record.progress.chaptersRead;

  return (chaptersRead < totalChapters);
}

auto limitDaysInit(long totalDays) {
  void limitDays(long*[] days ...) {
    foreach (d; days) {
      if (*d > totalDays)
        *d = totalDays;
    }
  }
  return &limitDays;
}

