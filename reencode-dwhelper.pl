#!/usr/bin/perl -w

use strict;
my ($INFILE,$OUTFILE) = @ARGV;

#/Applications/net.downloadhelper.coapp.app/Contents/MacOS/converter/build/mac/64/ffmpeg \
$INFILE = "\"$INFILE\"";
$OUTFILE = "\"$OUTFILE\"";

system("/usr/local/bin/ffmpeg -y -i $INFILE -c:a aac -f mp4 -c:v h264 -threads auto -strict experimental $OUTFILE");
    
