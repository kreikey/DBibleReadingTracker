#!/usr/bin/env rdmd

import std.stdio;
import std.file;
import std.string;
import std.algorithm;
import std.conv;
import std.array;
import std.csv;
import std.typecons;
import std.range;

struct BookSpec {
  string book;
  int chapters;
}

void main() {
  writeln("beginning the program");
  File outFile;
  string OTText = std.file.readText("OldTestament.tsv");
  string NTText = std.file.readText("NewTestament.tsv");
  auto OTRecordsRange = csvReader!(BookSpec)(OTText, null, '\t');
  auto NTRecordsRange = csvReader!(BookSpec)(NTText, null, '\t');
  string[] OTHeader = OTRecordsRange.header;
  string[] NTHeader = NTRecordsRange.header;
  auto OTRecords = OTRecordsRange.array();
  //OTRecords.each!((ref a) => makeEnumable(a.book));
  auto NTRecords = NTRecordsRange.array();
  //NTRecords.each!((ref a) => makeEnumable(a.book));
  auto BibleBooksRange = chain(OTRecords, NTRecords);
  auto BibleRecords = BibleBooksRange.array();
  outFile = File("OldTestamentEnum.txt", "w");
  printEnum(OTRecords, outFile);
  outFile = File("NewTestamentEnum.txt", "w");
  printEnum(NTRecords, outFile);
  outFile = File("BibleBooksEnum.txt", "w");
  printEnum(BibleRecords, outFile);
  outFile = File("BibleChaptersArray.txt", "w");
  printChapters(BibleRecords, outFile);
  outFile = File("BibleBooksStructs.txt", "w");
  printBooks(BibleRecords, outFile);
  outFile = File("BookNamesArray.txt", "w");
  printBookNames(BibleRecords, outFile);
  outFile = File("BibleChaptersHashmap.txt", "w");
  printBibleChaptersMap(BibleRecords, outFile);
  outFile = File("BookIndexHashmap.txt", "w");
  printBookIndexMap(BibleRecords, outFile);
  writeln("done");
}

void printEnum(BookSpec[] records, File outFile) {
  outFile.writeln("enum BibleBook");
  outFile.writeln("{");
  outFile.writeln("  ", records[0].book, " = 1,");
  foreach (record; records[1 .. $-1]) {
    outFile.writeln("  ", record.book.makeEnumable(), ",");
  }
  outFile.writeln("  ", records[$-1].book);
  outFile.writeln("}");
}
 
void printChapters(BookSpec[] records, File outFile) {
  outFile.writeln("int[] chapters = [");
  foreach (record; records[0 .. $-1]) {
    outFile.writeln("  ", record.chapters, ",");
  }
  outFile.writeln("  ", records[$ - 1].chapters);
  outFile.writeln("];");
}

string makeEnumable(string bookName) {
  bookName = bookName.tr(" ", "_");
  if (bookName[0] == '1')
    bookName.replaceInPlace(0u, 1u, "I");
  else if (bookName[0] == '2')
    bookName.replaceInPlace(0u, 1u, "II");
  else if (bookName[0] == '3')
    bookName.replaceInPlace(0u, 1u, "III");
  return bookName;
}

void printBooks(BookSpec[] records, File outFile) {
  outFile.writeln("static Book[] books = [");

  foreach (record; records[0 .. $-1])
    outFile.writefln("  {\"%s\", %d},", record.book, record.chapters);

  outFile.writefln("  {\"%s\", %d}", records[$ - 1].book, records[$ - 1].chapters);
  outFile.writeln("];");
}

void printBookNames(BookSpec[] records, File outFile) {
  outFile.writeln("bookNames = [");
  foreach (record; records[0 .. $-1])
    outFile.writeln("  \""~record.book~"\",");
  outFile.writefln("  \""~records[$ - 1].book~"\"");
  outFile.writeln("];");
}

void printBibleChaptersMap(BookSpec[] records, File outFile) {
  outFile.writeln("immutable int[string] chaptOf;");
  outFile.writeln("chaptOf = [");
  foreach (record; records[0 .. $-1])
    outFile.writefln("  \"%s\": %d,", record.book, record.chapters);
  outFile.writefln("  \"%s\": %d", records[$ - 1].book, records[$ - 1].chapters);
  outFile.writeln("];");
}

void printBookIndexMap(BookSpec[] records, File outFile) {
  outFile.writeln("immutable int[string] idxOf;");
  outFile.writeln("idxOf = [");
  foreach (i, record; records[0 .. $-1])
    outFile.writefln("  \"%s\": %d,", record.book, i);
  outFile.writefln("  \"%s\": %d", records[$ - 1].book, records.length - 1);
  outFile.writeln("];");
}
