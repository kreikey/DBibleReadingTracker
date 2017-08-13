#!/usr/bin/env rdmd

import std.stdio;
import std.file;
import std.string;
import std.algorithm;
import std.conv;
import std.array;

void main() {
  string bibleBooksText;
  bibleBooksText = std.file.readText("bibleBooks.txt");
  string[] chunks = bibleBooksText.split("\n\n \t \n");
  string[] OT = chunks[0].split("\n\n");
  string[] NT = chunks[1].split("\n\n");
  string[] headers = OT[0 .. 3];
  string[] footerOT = OT[$-2 .. $];
  OT = OT[3 .. $-2];
  string[] footerNT = NT[$-2 .. $];
  NT = NT[0 .. $-2];
  //headers.each!((ref a) => (a = "\""~a~"\""));
  string commonHeader = headers[1 .. 3].join("\t")~"\n";
  //OT.each!((i, ref a) => (i % 2 == 0) ? (a = "\""~a~"\"\t") : (a = "\""~a~"\"\n"));
  OT.each!((i, ref a) => (i % 2 == 0) ? a.insertInPlace(a.length, "\t") : a.insertInPlace(a.length, "\n"));
  auto OTTab = appender(commonHeader);
  OTTab.put(OT.join());
  //NT.each!((i, ref a) => (i % 2 == 0) ? (a = "\""~a~"\"\t") : (a = "\""~a~"\"\n"));
  NT.each!((i, ref a) => (i % 2 == 0) ? a.insertInPlace(a.length, "\t") : a.insertInPlace(a.length, "\n"));
  auto NTTab = appender(commonHeader);
  NTTab.put(NT.join());
  std.file.write("OldTestament.tsv", OTTab.data());
  std.file.write("NewTestament.tsv", NTTab.data());
  writeln("done");
  //(i, ref a) => i % 2 == 0 ? a.insertInPlace(a.length, "\t") : a.insertInPlace(a.length, "\n")

}
