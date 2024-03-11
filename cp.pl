#!/usr/bin/perl -w

use DateTime;
use Getopt::Long;

use constant DEBUG => 1;
use Switch;
use strict;

my $noConvert = '';
my $dryRun = '';
my $overwriteNew = '';
my $help = '';
my $eraseWorkproduct = '';

my %CODECS = (
    '720' => 'Devices/Apple 720p30 Surround',
    '1080' => 'Devices/Apple 1080p30 Surround',
    '2160' => 'Devices/Apple 2160p60 4K HEVC Surround'
    );
my $DEFAULT_CODEC = 'Devices/Apple 720p30 Surround';

GetOptions ("noconvert" => \$noConvert,
            "dryrun" => \$dryRun,
            "overwrite" => \$overwriteNew,
            "help" => \$help,
	    "eraseworkproduct" => \$eraseWorkproduct
    ) 
    or die ("Error in command line arguments\n");

if ($help)
{
    print STDERR "       noconvert = Do not convert to MP4. Simply store original.\n";
    print STDERR "       overwrite = Ignore any existing files.\n";
    print STDERR "          dryrun = Do not do anything\n";
    print STDERR "eraseworkproduct = Remove the converted file afterward (do not combine with nocloudconverted and notv together)\n";
    print STDERR "            help = This message.\n";
    exit 1;
}

my $USERNAME=`whoami`;
chomp $USERNAME;
my $HOMEDIR = '/Users/' . $USERNAME;

my $TRANSCODE_ROOT = $HOMEDIR . '/Desktop/TorrentingLocal/Conversion';
my $LOG_FILE = $TRANSCODE_ROOT . '/conversion_log.txt';
my $SRC_PATH = $TRANSCODE_ROOT . '/MKV';
my $DEST_PATH = $TRANSCODE_ROOT . '/MP4';

print "TorrentRoot: $TRANSCODE_ROOT\n" if DEBUG;
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
	next if $sourceFilename !~ /\.(mkv|flv|mp4|m4v|avi|wmv)$/;
	my @subsFilenames = ();
	my ($shortFilename) = $sourceFilename =~ /(.*?)\.\w{3}$/;
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
    print " --OUTFN: $outputFilename\n" if DEBUG and ! $noConvert;
    
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
	if (! $noConvert)
	{
	    my $TARGETCODEC = $DEFAULT_CODEC;
	    foreach my $resOption (sort { $a <=> $b } keys %CODECS)
	    {
		$TARGETCODEC = $CODECS{$resOption} if ( $outputFilename =~ /$resOption/ );
	    }
	    print " --CODEC: $TARGETCODEC\n" if DEBUG;
	    
	    my $commandLine = "/Applications/HandBrakeCLI --crop 0:0:0:0 -i '$sourceFullPathFilename' -o '$outputFilename' --all-subtitles --all-audio --preset='$TARGETCODEC' $subFileSwitch";
	    print " --CMDLN: $commandLine\n" if DEBUG;
	
	    if (! $dryRun )
	    {
		open LOG, ">> $LOG_FILE";
		print LOG "$dt Converting $shortFilename\n";
		close LOG;

		system($commandLine);
	    }
	}
	elsif ( ! $dryRun )
	{
	    open LOG, ">> $LOG_FILE";
	    print LOG "$dt Not-Converting $shortFilename\n";
	    close LOG;
	}

        print "Conversion not executed. Dry run mode.\n" if $dryRun;

    }

    print "\n\n" if DEBUG;
}

