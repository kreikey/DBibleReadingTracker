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
import std.meta;
import std.regex;
import std.functional;
import std.traits;

struct BookRange {
  string firstBook;
  string lastBook;

  auto byID() {
    static struct Result {
      int frontID;
      int backID;

      this(int _frontID, int _backID) {
        frontID = _frontID;
        backID = _backID;
      }

      void popFront() {
        if (empty)
          throw new RangeError("BibleReadingTracker.d");

        frontID++;
      }

      int front() @property {
        return frontID;
      }

      bool empty() @property {
        return (frontID > backID);
      }
    }

    return Result(idByBook[firstBook], idByBook[lastBook]);
  }

  auto byBook() {
    static struct Result {
      int frontID;
      int backID;

      this(int _frontID, int _backID) {
        frontID = _frontID;
        backID = _backID;
      }
   
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

    return Result(idByBook[firstBook], idByBook[lastBook]);
  }
}
unittest {
  auto r = BookRange("Genesis", "Revelation");
  assert(isInputRange!(typeof(r.byID())));
  assert(isInputRange!(typeof(r.byBook())));
}

struct ChaptersDays {
  int chapters;
  int days;

  this(string input) {
    input.formattedRead!"%d|%d"(this.tupleof);
  }

  this(typeof(this.tupleof) args) {
    this.tupleof = args;
  }

  string toString() {
    return format!"%d|%d"(this.tupleof);
  }
}

struct ToRead {
  private int next;
  private Nullable!int tomorrow;
  private Nullable!int total;

  this(string input) {
    int _tomorrow;
    int _total;
    auto pattern = ctRegex!`([\d]+)(\.\.([\d]+) ([\d]+))?`;
    auto result = input.matchFirst(pattern);

    next = result[1].to!int();

    if (result[3] != "")
      tomorrow = result[3].to!int();
    if (result[4] != "")
      total = result[4].to!int();
  }

  this(int _next) {
    next = _next;
  }

  this(AliasSeq!(int, int, int) args) {
    this.tupleof = args;
  }
  
  string toString() {
    if (tomorrow.isNull || total.isNull)
      return next.to!string();
    else
      return format!"%d..%d %d"(next, tomorrow.get, total.get);
  }
}

struct Progress {
  int chaptersRead;
  int totalChapters;
  int readThrough;
  int multiplicity;

  this(string progress) { 
    int percentRead; // A throwaway variable to make formattedRead parse correctly. We don't need it because it's a computed property.
    progress.formattedRead!"%d/%d %d%% %d/%d"(this.tupleof[0..2], percentRead, this.tupleof[2..4]);
  }

  this(typeof(this.tupleof) args) {
    this.tupleof = args;
  }

  int percentage() @property {
    return (double(chaptersRead) / totalChapters * 100).roundTo!int();
  }

  string toString() {
    string chChStr = format!"%d/%d"(this.tupleof[0..2]);
    string percentStr = format!"%d%%"(this.percentage);
    string mulStr = format!"%d/%d"(this.tupleof[2..4]);
    return format!"%-10s%-5s%-5s"(chChStr, percentStr, mulStr);
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

  string toString() {
    string result = format("%s", this.tupleof[0]);
    foreach (elem; this.tupleof[1 .. $]) {
      result ~= format("\t%s", elem);
    }

    return result;
  }
}

struct LabelledDate {
  Date date;
  string label;
  alias date this;

  this(string labelledDateStr) {
    int month;
    int day;
    int shortYear;

    labelledDateStr.formattedRead!"%s: %d/%d/%d"(label, month, day, shortYear);
    assert(shortYear < 100 && shortYear >= 0);
    date = Date(shortYear + 2000, month, day);
  }

  this(typeof(this.tupleof) args) {
    this.tupleof = args;
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

  string toString() {
    string result = format("%s", this.tupleof[0]);
    foreach (elem; this.tupleof[1 .. $]) {
      result ~= format("\t%s", elem);
    }

    return result;
  }
}

struct Chapter {
  // We have 2 IDs: the plan ID and the section ID. Section ID indexes just the books in the section. Plan ID includes multiplicity, indexing the books numerous times, depending on multiplicity. The range of planID is a multiple of the total number of chapters in the section.
  string name;
  int planID;
  int progID;
}

struct ReadingSection {
  Book[] localBooks;
  int totalChapters;
  
  this(BookRange[] bookRangeList) {
    localBooks = bookRangeList
      .map!(r => r
        .byBook
        .array())
      .join();

    totalChapters = localBooks
      .map!(b => b.chapters)
      .sum();
  } 

  string decodeChapterID(size_t chapterID) const {
    auto chaptersBook = localBooks
      .map!(b => b.chapters)
      .cumulativeFold!((a, b) => a + b)
      .zip(localBooks)
      .find!(a => a[0] > chapterID)
      .front;

    Book book = chaptersBook[1];
    int chapter = chapterID.to!int() - (chaptersBook[0] - book.chapters) + 1;

    return format!"%s %d"(book.name, chapter);
  }

  int encodeChapterID(string bookAndChapter) {
    string bookName;
    int index;
    int chapter;
    long splitNdx;

    splitNdx = (bookAndChapter.length - 1 - bookAndChapter.retro.indexOf(' '));
    bookName = bookAndChapter[0 .. splitNdx];
    chapter = bookAndChapter[splitNdx + 1 .. $].to!int();

    Book book = books[idByBook[bookName]];

    return localBooks
      .until(book)
      .map!(i => book.chapters)
      .sum() + chapter - 1;
  }

  auto byChapter() {
    struct Result {
      size_t length;
      int frontID;
      int backID;
      ReadingSection* parent;

      this(ReadingSection* _parent) {
        parent = _parent;
        length = parent.totalChapters;
        frontID = 0;
        backID = (length - 1).to!int();
      }

      string front() @property {
        return parent.decodeChapterID(frontID);
      }

      string back() @property {
        return parent.decodeChapterID(backID);
      }

      void popFront() {
        if (empty)
          throw new RangeError("BibleReadingTracker.d");

        frontID++;
        length--;
      }

      void popBack() {
        if (empty)
          throw new RangeError("BibleReadingTracker.d");

        backID--;
        length--;
      }

      bool empty() @property {
        return frontID > backID;
      }

      auto save() @property {
        auto copy = this;
        return copy;
      }

      string opIndex(size_t idx) inout {
        if (idx >= length)
          throw new RangeError("BibleReadingTracker.d");

        return parent.decodeChapterID(cast(int)idx);
      }
    }

    return Result(&this);
  }

  auto byDayEdge(int totalDays, int multiplicity) {
    alias ChaptersType = typeof(this.byChapter.cycle());

    static struct Result {
      int chaptersInSection;
      int totalDays;
      int totalChapters;
      int frontEdge;
      int backEdge;
      size_t length;
      ChaptersType chapters;

      this(int _totalDays, int _multiplicity, int _chaptersInSection, ChaptersType _chapters) {
        chaptersInSection = _chaptersInSection;
        totalChapters = chaptersInSection * _multiplicity;
        frontEdge = 0;
        backEdge = _totalDays;
        totalDays = _totalDays;
        length = totalDays + 1;
        chapters = _chapters;
      }

      Chapter front() @property {
        int planID = (double(frontEdge) * totalChapters / totalDays).roundTo!int();
        int progID = (planID - 1) % chaptersInSection + 1;
        string chapterName;

        if (planID == totalChapters)
          chapterName = "The End";
        else
          chapterName = chapters[planID];

        return Chapter(chapterName, planID, progID);
      }

      Chapter back() @property {
        int planID = (double(backEdge) * totalChapters / totalDays).roundTo!int();
        int progID = (planID - 1) % chaptersInSection + 1;
        string chapterName;

        if (planID == totalChapters)
          chapterName = "The End";
        else
          chapterName = chapters[planID];

        return Chapter(chapterName, planID, progID);
      }

       void popFront() {
        if (empty)
          throw new RangeError("BibleReadingTracker.d");

        frontEdge++;
        length--;
      }

      void popBack() {
        if (empty)
          throw new RangeError("BibleReadingTracker.d");

        backEdge--;
        length--;
      }

      bool empty() @property {
        return frontEdge > backEdge;
      }

      auto save() @property {
        auto copy = this;
        return copy;
      }

      Chapter opIndex(size_t idx) {
        if (idx >= length)
          throw new RangeError("BibleReadingTracker.d");

        string chapterName;
        int planID = (double(idx + frontEdge) * totalChapters / totalDays).roundTo!int();
        int progID = (planID - 1) % chaptersInSection + 1;

        if (planID == totalChapters)
          chapterName = "The End";
        else
          chapterName = chapters[planID];

        return Chapter(chapterName, planID, progID);
      }

      size_t opDollar() {
        return length;
      }
    }

    return Result(totalDays, multiplicity, this.totalChapters, this.byChapter.cycle());
  }
}
unittest {
  auto r = BookRange("Genesis", "Revelation");
  auto s = ReadingSection([r]);
  auto bd = s.byDayEdge(365, 1);
  assert(isRandomAccessRange!(typeof(bd)));
  assert(bd[$-1].name == "The End");
  assert(bd[0].name == "Genesis 1");
  bd.popFront();
  bd.popBack();
  assert(bd.front.name == "Genesis 4");
  assert(bd.back.name == "Revelation 20");
  assert(bd[0].name == "Genesis 4");
  assert(bd[$-1].name == "Revelation 20");
  auto bc = s.byChapter();
  assert(isRandomAccessRange!(typeof(bc)));
  assert(bc[0] == "Genesis 1");
  assert(bc.front == "Genesis 1");
  assert(bc[$-1] == "Revelation 22");
  assert(bc.back == "Revelation 22");
  bc.popFront();
  bc.popBack();
  assert(bc[0] == "Genesis 2");
  assert(bc.front == "Genesis 2");
  assert(bc[$-1] == "Revelation 21");
  assert(bc.back == "Revelation 21");
}

struct Book {
  string name;
  int chapters;
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

immutable int[string] idByBook;
ReturnType!limitDayInit limit;

shared static this() {
  auto temp = iota!int(0, books.length.to!int())
    .map!(i => books[i].name, i => i)
    .assocArray();
  temp.rehash();
  idByBook = assumeUnique(temp);
  resetIeeeFlags();
}

void main(string[] args) {
  // Copy and transform command-line arguments
  int[] daysRead = args[1 .. $].map!(to!int).array();

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

  if (daysRead.length == 0)
    daysRead ~= 1;

  if (daysRead.length < sectionRecords.length)
    daysRead ~= daysRead[$ - 1].repeat(sectionRecords.length - daysRead.length).array();
  else if (daysRead.length > sectionRecords.length)
    daysRead.length = sectionRecords.length;

  // Get today's date
  LabelledDate todaysDate = Clock.currTime.LabelledDate(dateRow.lastModDate.label);

  // Initialize our updateRecord closure with the day offsets we calculated so we don't have to pass a bunch of reduntant arguments to it when we update records
  auto updateRecord = updateRecordInit(dateRow.tupleof, todaysDate);

  string tableResetMsg = "";
  int daysElapsed = 0;

  with(dateRow) if (lastModDate < startDate) {
    daysElapsed++;
    tableResetMsg ~= "Table reset; ";
    lastModDate.date = startDate.date;
  }

  daysElapsed += (todaysDate - dateRow.lastModDate).total!"days"();

  ReadingSection[string] sectionsByName = getSectionsFromFile("readingSections.sdl");

  // Update table with days read
  lockstep(sectionRecords, sectionRecords.map!(r => sectionsByName[r.section])(), daysRead)
    .each!updateRecord();

  // Update last-modified date
  dateRow.lastModDate.date = todaysDate.date;

  // write updated table along with related information
  writeln(title);
  writeln(headSeparator);
  writeln(dateRow);
  writeln(mainSeparator);
  writeln(sectionHeader.join("\t"));
  sectionRecords.each!writeln();
  writeln(mainSeparator);
  writefln!"Status: %scompleted last reading in %s days"(tableResetMsg, daysElapsed);
}

// The return type of this function is void delegate(ref SectionSpec, ReadingSection, int), but auto is more readable.
auto updateRecordInit(LabelledDate lastModDate, LabelledDate startDate, LabelledDate endDate, LabelledDate todaysDate) {
  // Initialize the day offsets we'll use to do our calculations
  int totalDays = ((endDate - startDate).total!"days"() + 1).to!int();
  limit = limitDayInit(totalDays);

  int lastDay = ((lastModDate - startDate).total!"days"() + 1).to!int.limit();
  int today = ((todaysDate - startDate).total!"days"() + 1).to!int.limit();
  int tomorrow = (today + 1).limit();
  
  void updateRecord(ref SectionSpec record, ReadingSection section, int daysRead) {
    int multiplicity = record.progress.multiplicity;
    int daysBehind = record.behind.days;
    auto chapterByDay = section.byDayEdge(totalDays, multiplicity);

    int lastCurDay = lastDay - daysBehind;

    if (lastModDate < startDate)
      lastCurDay = 0;
    else if (lastCurDay + daysRead > totalDays)
      daysRead = totalDays - lastCurDay;

    int currentDay = (lastCurDay + daysRead).limit();
    int nextDay = (currentDay + 1).limit(); // handle chaptersToRead issue here by limiting nextDay depending on totalDays

    Chapter lastCurChapter = chapterByDay[lastCurDay];
    Chapter curChapter = chapterByDay[currentDay];
    Chapter nextChapter = chapterByDay[nextDay];
    Chapter targetChapter = chapterByDay[today];
    Chapter tomorrowsChapter = chapterByDay[tomorrow];

    int readThrough = (curChapter.planID - 1) / section.totalChapters + 1;
    int chaptersBehind = targetChapter.planID - curChapter.planID;
    daysBehind = today - currentDay;
    int chaptersRead = curChapter.planID - lastCurChapter.planID;
    int chaptersToReadNext = nextChapter.planID - curChapter.planID;
    int chaptersToReadTomorrow = tomorrowsChapter.planID - targetChapter.planID;

    record.current = curChapter.name;
    record.target = targetChapter.name;
    record.behind = ChaptersDays(chaptersBehind, daysBehind);
    record.lastRead = ChaptersDays(chaptersRead, daysRead);
    record.toRead = (nextDay >= tomorrow || today == totalDays) ?
      ToRead(chaptersToReadNext) :
      ToRead(chaptersToReadNext, chaptersToReadTomorrow, (chaptersBehind + chaptersToReadTomorrow));
    record.progress = Progress(curChapter.progID, section.totalChapters, readThrough, multiplicity);
  }

  return &updateRecord;
}

ReadingSection[string] getSectionsFromFile(string filename) {
  auto sections = parseFile(filename).tags["section"];
  return sections.map!(s => tuple(s.expectValue!string, s.tags["bookrange"]
      .map!(r => BookRange(r.expectAttribute!string("first"), r.expectAttribute!string("last")))
      .array
      .ReadingSection()))
    .assocArray();
}

auto limitDayInit(int totalDays) {
  return delegate(int day) {
    return day < totalDays ? day : totalDays;
  };
}
