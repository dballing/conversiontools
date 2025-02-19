#!/usr/bin/perl -w

#use lib '/Users/derek.balling/perl5/lib';
use DateTime;
use Getopt::Long;

use constant DEBUG => 1;
use Switch;
use strict;

my $noTV = '';
my $noConvert = '';
my $dryRun = '';
my $overwriteNew = '';
my $noCloudOriginal = '';
my $noCloudConverted = '';
my $help = '';
my $eraseWorkproduct = '';
my $eraseOriginal = '';

#my $handbrakeCLI = '/Applications/HandbrakeCLI';
my $handbrakeCLI = '/opt/homebrew/bin/HandBrakeCLI';

my %CODECS = (
    '720' => 'Devices/Apple 720p30 Surround',
    '1080' => 'Devices/Apple 1080p30 Surround',
    '2160' => 'Devices/Apple 2160p60 4K HEVC Surround'
    );
my $DEFAULT_CODEC = 'Devices/Apple 720p30 Surround';

GetOptions ("notv" => \$noTV,
	    "nocloudoriginal|tossorig" => \$noCloudOriginal,
            "nocloudconverted|nodropbox" => \$noCloudConverted,
	    "noconvert" => \$noConvert,
            "dryrun" => \$dryRun,
            "overwrite" => \$overwriteNew,
	    "eraseoriginal" => \$eraseOriginal,
	    "tvonly" => sub { $noCloudOriginal=1; $noCloudConverted=1; },
            "help" => \$help,
	    "eraseworkproduct" => \$eraseWorkproduct,
    ) 
    or die ("Error in command line arguments\n");

if ($help)
{
    print STDERR "            notv = Do not import converted MP4 into TV\n";
    print STDERR "       noconvert = Do not convert to MP4. Simply store original.\n";
    print STDERR "nocloudconverted = Do not archive converted MP4 to DropBox\n";
    print STDERR " nocloudoriginal = Do not archive original file to DropBox\n";
    print STDERR "          tvonly = Don't archive anything.\n";
    print STDERR "       overwrite = Ignore any existing files.\n";
    print STDERR "          dryrun = Do not do anything\n";
    print STDERR "eraseworkproduct = Remove the converted file afterward (do not combine with nocloudconverted and notv together)\n";
    print STDERR "   eraseoriginal = Remove the original file afterward\n";
    print STDERR "            help = This message.\n";
    exit 1;
}

if ( ($noConvert && ! $noTV) or
     ($noConvert && ! $noCloudConverted) )
{
    $noTV = $noConvert;
    $noCloudConverted = $noConvert;
    print STDERR "Enabling 'notv' and 'nodropbox' as 'noconvert' has been set\n";
    print STDERR "and those flags require conversion.\n";
}

if ( ($noCloudConverted && $noTV)
     &&
     $eraseWorkproduct
    )
{
    print STDERR "Converted output will be saved in neither Dropbox, nor iTunes, and is scheduled to be deleted.\n";
    print STDERR "This is a waste of time.\n";
    exit;
}

my $USERNAME=`whoami`;
chomp $USERNAME;
my $HOMEDIR = '/Users/' . $USERNAME;

my $TV_ADD_DIR = $HOMEDIR . '/Movies/TV/Media.localized/Automatically Add To TV.localized';
#my $DROPBOX_DIR = $HOMEDIR . '/Dropbox (Harris-Balling)/Darkweb Files';
my $DROPBOX_DIR = $HOMEDIR . '/MEGASelectiveSync/Staging';
my $TRANSCODE_ROOT = $HOMEDIR . '/Desktop/Transcoding';
my $SRC_PATH = $TRANSCODE_ROOT . '/Actual Programming';
my $DEST_PATH = $TRANSCODE_ROOT . '/AppleTVReady';

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
	next if $sourceFilename !~ /\.(mkv|flv|mp4|m4v|avi)$/;
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

    my $dropboxFilename = $DROPBOX_DIR . '/' . $shortFilename . '.m4v';
    print " --DRPFN: $dropboxFilename\n" if DEBUG and ! $noCloudConverted;

    my $TVFilename = $TV_ADD_DIR . '/' . $shortFilename . '.m4v';
    print " --ITNFN: $TVFilename\n" if DEBUG and ! $noTV;

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
	    
	    my $commandLine = "$handbrakeCLI --crop 0:0:0:0 -i '$sourceFullPathFilename' -o '$outputFilename' --all-subtitles --all-audio --preset='$TARGETCODEC' $subFileSwitch";
	    print " --CMDLN: $commandLine\n" if DEBUG;
	
	    if (! $dryRun )
	    {
		open LOG, ">> $DROPBOX_DIR/conversion_log.txt";
		print LOG "$dt Converting $shortFilename\n";
		close LOG;

		system($commandLine);
	    }
	}
	elsif ( ! $dryRun )
	{
	    open LOG, ">> $DROPBOX_DIR/conversion_log.txt";
	    print LOG "$dt Not-Converting $shortFilename\n";
	    close LOG;
	}

	if (! $dryRun)
	{
            if (! $noTV )
            {
		# Do this via a temp-file because non-atomic moves into TV can cause
		# failed imports.
		my $tmpFilename = '/tmp/converter.$$';
                system("/bin/cp '$outputFilename' '$tmpFilename'");
		system("/bin/mv '$tmpFilename' '$TVFilename'");
            }
            if (! $noCloudConverted )
            {
                system("/bin/cp '$outputFilename' '$dropboxFilename'");
            }
	    if ( ! $noCloudOriginal )
	    {
		system("/bin/cp '$sourceFullPathFilename' '$DROPBOX_DIR/.'");
	    }
	    if ( $eraseWorkproduct )
	    {
		system("/usr/bin/trash $outputFilename");
	    }
	    if ( $eraseOriginal )
	    {
		system("/usr/bin/trash '$sourceFullPathFilename'");
	    }
	}
	else
        {
            print "Conversion not executed. Dry run mode.\n";
        }
    }

    print "\n\n" if DEBUG;
}

