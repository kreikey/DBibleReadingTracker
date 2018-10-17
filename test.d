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

struct BookRange {
  string first;
  string last;
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
        ulong planID = frontDay * totalChapters / (length - 1);
        ulong secID = (planID - 1) % chaptersInSection + 1;
        string chapterName = parent.decodeChapterID(secID);
        return Chapter(chapterName, planID, secID);
      }
      Chapter back() @property {
        ulong planID = backDay * totalChapters / (length - 1);
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

struct Chapter {
  // We have 2 IDs: the plan ID and the section ID. Section ID indexes just the books in the section. Plan ID includes multiplicity, indexing the books numerous times, depending on multiplicity. The range of planID is a multiple of the total number of chapters in the section.
  string name;
  ulong planID;
  ulong secID;
}

ReadingSection[string] getSectionsFromFile1(string filename) {
  ReadingSection[string] sectionsByNameOld = [
    "Old Testament" : ReadingSection([BookRange("Genesis", "Job"),
        BookRange("Ecclesiastes", "Malachi")]),
    "New Testament" : ReadingSection([BookRange("Matthew", "Revelation")]),
    "Psalms" : ReadingSection([BookRange("Psalms", "Psalms")]),
    "Proverbs" : ReadingSection([BookRange("Proverbs", "Proverbs")])
  ];

  Tag root = parseFile(filename);
  ReadingSection[string] sectionsByName;

  foreach (section; root.tags["section"]) {
    string sectionName = section.expectValue!string;
    //writefln("%s: %s", section.name, sectionName);

    BookRange[] bookRanges = [];

    foreach (range; section.tags["range"]) {
      //writefln("  %s: %s, %s", range.name, range.tags["first"][0].expectValue!string, range.tags["last"][0].expectValue!string);
      //string first = range.tags["first"].front.expectValue!string;
      //string last = range.tags["last"].front.expectValue!string;
      string first = range.expectTagValue!string("first");
      string last = range.expectTagValue!string("last");
      bookRanges ~= BookRange(first, last);
    }
    auto readingSection = ReadingSection(bookRanges);

    sectionsByName[sectionName] = readingSection;
  }

  writeln(sectionsByName);
  writeln(sectionsByNameOld);
  writeln(sectionsByName == sectionsByNameOld);

  return sectionsByName;
}

ReadingSection[string] getSectionsFromFile(string filename) {
  //ReadingSection[string] sectionsByNameOld = [
    //"Old Testament" : ReadingSection([BookRange("Genesis", "Job"),
        //BookRange("Ecclesiastes", "Malachi")]),
    //"New Testament" : ReadingSection([BookRange("Matthew", "Revelation")]),
    //"Psalms" : ReadingSection([BookRange("Psalms", "Psalms")]),
    //"Proverbs" : ReadingSection([BookRange("Proverbs", "Proverbs")])
  //];

  Tag root = parseFile(filename);
  ReadingSection[string] sectionsByName;

  foreach (section; root.tags["section"]) {
    string sectionName = section.expectValue!string;
    //writefln("%s: %s", section.name, sectionName);

    BookRange[] bookRanges = [];

    foreach (bookrange; section.tags["bookrange"]) {
      writefln("  %s: %s, %s", bookrange.name, bookrange.expectAttribute!string("first"), bookrange.expectAttribute!string("last"));
      string first = bookrange.expectAttribute!string("first");
      string last = bookrange.expectAttribute!string("last");
      bookRanges ~= BookRange(first, last);
    }
    auto readingSection = ReadingSection(bookRanges);

    sectionsByName[sectionName] = readingSection;
  }

  //writeln(sectionsByName);
  //writeln(sectionsByNameOld);
  //writeln(sectionsByName == sectionsByNameOld);

  return sectionsByName;
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


immutable ulong[string] idByBook;

static this() {
  idByBook = zip(books, iota(0, books.length)).assocArray();
}

void main(string[] args) {
  ulong[] bookIDs = [14, 15, 16, 17, 20, 21, 22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38];
  foreach(bookID; bookIDs)
    writeln(books[bookID]);
  writeln("-----");

  ulong length = bookIDs.length;
  writeln(length);
  for (ulong i = 0; i < length; i++) {
    writefln("%s, %s", bookIDs.front, books[bookIDs.front]);
    bookIDs.popFront();
    writeln(bookIDs);
    writeln(bookIDs.empty);
  }

  int[] numbers = [1, 2, 3, 4, 5];
  writeln(numbers);
  writeln(numbers.empty);
  writefln("front: %d back: %d", numbers.front, numbers.back);
  numbers.popFront();
  numbers.popBack();
  writeln(numbers);
  writeln(numbers.empty);
  writefln("front: %d back: %d", numbers.front, numbers.back);
  numbers.popFront();
  numbers.popBack();
  writeln(numbers);
  writeln(numbers.empty);
  writefln("front: %d back: %d", numbers.front, numbers.back);
  numbers.popFront();
  writeln(numbers);
  writeln(numbers.empty);
  
  //ulong chapterSum = 0;
  //ulong chID = 292;
  //auto theBook = bookIDs.zip(bookIDs.map!(chaptersOf).cumulativeFold!(sum2)()).find!(a => a[1] >= chID).front;
  //writeln(theBook);
  //writefln("%s: %d", books[theBook[0]], chID - (theBook[1] - chapters[theBook[0]]));

  //writeln("-----");

  //File readingSectionsFile = File("readingSections2.sdl");
  //ReadingSection[string] sectionsByName = getSectionsFromFile1("readingSections2.sdl");
  ReadingSection[string] sectionsByName = getSectionsFromFile("readingSections.sdl");
  //writeln(sectionsByName);
  //readingSections.rawWrite(sectionsByName);
  //ReadingSection[string] sectionsByName = [
    //"Old Testament" : ReadingSection([BookRange("Genesis", "Job"),
        //BookRange("Ecclesiastes", "Malachi")]),
    //"New Testament" : ReadingSection([BookRange("Matthew", "Revelation")]),
    //"Psalms" : ReadingSection([BookRange("Psalms", "Psalms")]),
    //"Proverbs" : ReadingSection([BookRange("Proverbs", "Proverbs")])
  //];

  //auto output = File("sectionsOut.txt", "w");
  //root.all.tags["ReadingSection"].each!(t => output.writeln(t.getFullName()));

  //writeln(sectionsByName.to!string());
  //sectionsByName.to!string().toFile("readingSections.txt");


}
