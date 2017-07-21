#!/usr/bin/env rdmd -I..

import std.stdio;
import std.file;
import std.array;
import std.datetime;
import std.algorithm;
import std.csv;
import std.typecons;

struct DaySpec {
  string dateModified;
  int daysReadSince;
}

struct SectionSpec {
  string section;
  int target;
  int current;
  int chaptsBehind;
  int daysBehind;
}

void main(string[] args) {
  auto readingStats = stdin.byLineCopy.array();
  auto daysText = readingStats[3 .. 4].join("\n");
  auto daysFields = csvReader!(DaySpec)(daysText, '\t');
  writeln("more cowbell!");
}
