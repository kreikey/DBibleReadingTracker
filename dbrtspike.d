#!/usr/bin/env rdmd -I..

import std.stdio;

void main() {
  int tchapters = 748;
  int tdays = 365;
  int chapter = 51;
  int dayChapter = chapter * tdays;
  int day = dayChapter / tchapters;
  int rem = dayChapter % tchapters;
  double remainingChapters = cast(double)rem / tdays;
  writefln("rem: %s", rem);
  writefln("chapter: %s, day: %s", chapter, day);
  double decimalChapters = cast(double)day * tchapters / tdays;
  writefln("decimal chapters: %s", decimalChapters);
  writefln("remaining chapters: %s", remainingChapters);
  writefln("converted chapters: %s", (dayChapter + rem) / tdays); 
  int daysRead = 7;
  day += daysRead;
  chapter = day * tchapters / tdays;
  writefln("chapter: %s, day: %s", chapter, day);
}

