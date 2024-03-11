#!/usr/bin/perl -w

use DateTime;
use Getopt::Long;

use constant DEBUG => 0;

my $noiTunes = '';
my $noDropbox = '';
my $dryRun = '';
my $overwriteNew = '';
GetOptions ("noitunes" => \$noiTunes,
            "nodropbox" => \$noDropbox,
            "dryrun" => \$dryRun,
            "overwrite" => \$overwriteNew ) 
    or die ("Error in command line arguments\n");

my $MEDIAMUSIC = 'Music';
my $LOCALIZED = '';
my $USERNAME = 'derek.balling';

my $uname = `uname -a`;
if (lc $uname =~ /(darkweb|vagabond)/i)
{
    $MEDIAMUSIC = 'Media';
    $LOCALIZED = '.localized';
    $USERNAME = 'dballing';
}

use strict;

my $HOMEDIR = '/Users/' . $USERNAME;
my $ITUNES_AUTO_ADD = $HOMEDIR . '/Music/iTunes/iTunes ' . $MEDIAMUSIC .
    '/Automatically Add to iTunes' . $LOCALIZED;
my $DROPBOX_DIR = $HOMEDIR . '/Dropbox (Harris-Balling)/Darkweb Files';
my $TORRENT_ROOT = $HOMEDIR . '/Desktop/Torrenting';
my $SRC_PATH = $TORRENT_ROOT . '/Actual Programming';
my $DEST_PATH = $TORRENT_ROOT . '/AppleTVReady';

opendir SRC, $SRC_PATH;
my @files = grep (/^[^\.]/, readdir (SRC));
closedir SRC;

foreach my $oldFilename (sort {lc $a cmp lc $b} @files)
{
    my $shortOldFilename = $oldFilename;
    my $subtitlesFlags = '';

    if ( -d "$SRC_PATH/$oldFilename" )
    {
	# This filename is a directory so we need to treat it a bit differently
	# we need to (a) find the actual filename and put that in $oldFilename
	# and (b) find the subtitles and add the relevant flags to $subtitlesFlags
	my $downloadRootDir = $oldFilename;
	my $subtitlesDir = '';
	print STDERR "Checking $SRC_PATH/$oldFilename/[Su]bs \n" if DEBUG;
	if ( -d "$SRC_PATH/$oldFilename/subs" )
	{
	    $subtitlesDir = "$SRC_PATH/$oldFilename/subs";
	}
	elsif ( -d "$SRC_PATH/$oldFilename/Subs" )
	{
	    $subtitlesDir = "$SRC_PATH/$oldFilename/Subs";
	}
	else
	{
	    print STDERR "I am unable to locate the subtitles directory for $oldFilename.\n";
	    next;
	}
	print STDERR "Found subs at $subtitlesDir\n" if DEBUG;
	opendir SUBSDIR, $subtitlesDir or die "Couldn't open $subtitlesDir: $!";
	my @subfiles = (grep /\.srt/, readdir SUBSDIR);
	closedir SUBSDIR;
	print STDERR "Subs: " . (join "---" , @subfiles) . "\n" if DEBUG;

	if (@subfiles)
	{
	    print STDERR "We have subfiles.\n" if DEBUG;
	    my @fqsubfiles = ();
	    foreach my $subfile (@subfiles)
	    {
		print STDERR "pushing FQ version of $subfile.\n" if DEBUG;
		push @fqsubfiles, ( "'$subtitlesDir/$subfile'");
	    }
	    $subtitlesFlags = ' --srt-file ';
	    $subtitlesFlags .= join (',', @fqsubfiles);
	}
	else
	{
	    print STDERR "WE have a subs dir but no sub files in $oldFilename. Skipping.\n";
	    next;
	}

	print STDERR "subtitlesFlags = '$subtitlesFlags'\n" if DEBUG; 
	opendir FNDIR, "$SRC_PATH/$oldFilename" or die "Couldn't opendir $oldFilename: $!" ;
	my @vidfiles = ( grep /\.(mkv|flv|mp4|m4v|avi)$/, readdir FNDIR );
	closedir FNDIR;
	
	my $numVids = @vidfiles;
	if ( $numVids > 1 )
	{
	    print STDERR "There are n>1 videos in $oldFilename.\n";
	    next;
	}
	$shortOldFilename = $vidfiles[0];
	$oldFilename .= "/" . $vidfiles[0];
    }

    next if $oldFilename !~ /\.(mkv|flv|mp4|m4v|avi)$/;

# TODO fix this so this works with 's in filenames
#    $oldFilename =~ s/\'/\\'/gs;

    my $oldExt = $1;
    my $newFilename = $shortOldFilename;
    $newFilename =~ s/$oldExt$/m4v/;
    my $oldOriginal = $oldFilename;
    $oldFilename = "$SRC_PATH/$oldFilename";
    $newFilename = "$DEST_PATH/$newFilename";
    print "OLDFN: $oldFilename\n" if DEBUG;
    print "NEWFN: $newFilename\n" if DEBUG;
    if (! -e $oldFilename)
    {
	print "Skipping $oldFilename as it seems to have vanished since we started.\n";
    }
    elsif (-e $newFilename and ! $overwriteNew )
    {
	print "Skipping $oldFilename since $newFilename already exists.\n";
    }
    else
    {
	my $dt = DateTime->now;
	my $commandLine = "/Applications/HandBrakeCLI -i '$oldFilename' -o '$newFilename' --all-subtitles --all-audio --preset='AppleTV 3' $subtitlesFlags";
	print STDERR "Command: [[ $commandLine ]]\n" if DEBUG;
	
	if (! $dryRun )
	{
	    open LOG, ">> $DROPBOX_DIR/conversion_log.txt";
	    print LOG "$dt Converting $oldOriginal\n";
	    close LOG;
	    
	    system($commandLine) if ! $dryRun;
	    if (! $noiTunes )
	    {
		system("/bin/cp '$newFilename' '$ITUNES_AUTO_ADD/.'");
	    }
	    if (! $noDropbox )
	    {
		system("/bin/cp '$newFilename' '$DROPBOX_DIR/.'");
	    }
	}
	else
	{
	    print STDERR "Conversion not executed. Dry run mode.\n";
	}
    }
}
