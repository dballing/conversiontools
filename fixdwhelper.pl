#!/usr/bin/perl -w

use DateTime;
use Getopt::Long;

use constant DEBUG => 1;
use Switch;
use strict;

my $dryRun = '';
my $overwriteNew = '';
my $noKeepOriginal = '';

GetOptions ("dryrun" => \$dryRun,
	    "overwrite" => \$overwriteNew ) 
    or die ("Error in command line arguments\n");

my $USERNAME = 'derek.balling';

my $HOMEDIR = '/Users/' . $USERNAME;
my $SRC_PATH = $HOMEDIR . '/dwhelper';
my $DEST_PATH = $HOMEDIR . '/dwfixed';

print "SourcePath: $SRC_PATH\n" if DEBUG;
opendir SRC, $SRC_PATH;
my @files = grep (/^[^\.]/, readdir (SRC));
closedir SRC;

if ( $#files < 0 )
{
    print STDERR "No files or dirs found in $SRC_PATH.\n";
    exit;
}

foreach my $sourceFilename (sort {lc $a cmp lc $b} @files)
{
    my $sourceFullPathFilename = "$SRC_PATH/$sourceFilename";
    if ( -f $sourceFullPathFilename )
    {
	# Skip this individual file if it's not actually a video
	next if $sourceFilename !~ /\.(mkv|flv|mp4|m4v|avi)$/;
	my @subsFilenames = ();
	my ($shortFilename) = $sourceFilename =~ /(.*?)\.\w{3}$/;
	$shortFilename =~ s/ streaming.*//;
	processFile($sourceFullPathFilename, $shortFilename, \@subsFilenames);
    }
    elsif ( -d $sourceFullPathFilename )
    {
	processDirectory($sourceFullPathFilename);
    }
}

sub processDirectory
{
    my $sourceFullPathFilename = shift;

    my $HAS_SUBS = 0;
    $HAS_SUBS = 1 if ( -d "$sourceFullPathFilename/Subs" );

    opendir PROCESSDIR, $sourceFullPathFilename;
    my @videoFiles = grep (/\.(mkv|flv|mp4|m4v|avi)$/, readdir (PROCESSDIR));
    closedir PROCESSDIR;

    my $numVideos = $#videoFiles + 1;
    
    foreach my $potentialVideo (sort {lc $a cmp lc $b} @videoFiles)
    {
	my $fullPathPotentialVideo = "$sourceFullPathFilename/$potentialVideo";
	next if $fullPathPotentialVideo !~ /\.(mkv|flv|mp4|m4v|avi)$/;
	my ($shortFilename) = $potentialVideo =~ /(.*?)\.\w{3}$/;

	my @subsFilenames = ();
	
	if ($HAS_SUBS)
	{
	    my $subsDir = $sourceFullPathFilename . '/Subs';
	    if ($numVideos > 1)
	    {
		# The subs are probably in a subdir of Subs
		$subsDir .= "/$shortFilename";
	    }
	    opendir SUBS, $subsDir;
	    my @subsFiles = grep (/\.srt$/, readdir(SUBS));
	    closedir SUBS;

	    foreach my $subsFile (sort {lc $a cmp lc $b} @subsFiles)
	    {
		push @subsFilenames, "'$subsDir/$subsFile'";
	    }
	}

	processFile($fullPathPotentialVideo,$shortFilename,\@subsFilenames);
    }
    
}

sub processFile
{
    my $sourceFullPathFilename = shift;
    my $shortFilename = shift;
    
    my $subsFilenamesRef = shift;
    my @subsFilenames = @$subsFilenamesRef;

    my $subFileSwitch = '';
    print "FILENAME: $sourceFullPathFilename\n" if DEBUG;
    print " --SHORT: $shortFilename\n" if DEBUG;
    
    foreach my $subsFilename (@subsFilenames)
    {
	print " -- SUBS: $subsFilename\n" if DEBUG;
    }

    if (@subsFilenames)
    {
	$subFileSwitch = ' --srt-file ';
	$subFileSwitch .= join (',', @subsFilenames);
    }

    print " --SUBSW: $subFileSwitch\n" if DEBUG;

    my $outputFilename = $DEST_PATH . '/' . $shortFilename . '.m4v';
    print " --OUTFN: $outputFilename\n" if DEBUG;

    if (! -e $sourceFullPathFilename )
    {
	print "Skipping $sourceFullPathFilename as it seems to have vanished since we started.\n";
    }
    elsif ( -e $outputFilename and ! $overwriteNew )
    {
	print "Skipping $sourceFullPathFilename since $outputFilename exists already.\n";
    }
    else
    {
	# OK, let's do this shit.
	my $dt = DateTime->now;
	my $commandLine = "/Applications/HandBrakeCLI -i '$sourceFullPathFilename' -o '$outputFilename' --all-subtitles --all-audio $subFileSwitch";
	print " --CMDLN: $commandLine\n" if DEBUG;
	
	if (! $dryRun )
        {
	    system($commandLine) if ! $dryRun;
	}
	else
        {
            print "Conversion not executed. Dry run mode.\n";
        }
    }

    print "\n\n" if DEBUG;
}

