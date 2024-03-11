#!/usr/bin/perl -w

use strict;
use Switch;

my ($MEDIAMUSIC,$LOCALIZEDADD,$LOCALIZEDNOT,$USERNAME,$TVITUNES);
my $uname = `uname -a`;
switch($uname) {
    case /vagabond/i {
        $MEDIAMUSIC = 'Media';
        $LOCALIZEDADD = '.localized';
	$LOCALIZEDNOT = '';
        $USERNAME = 'dballing';
        $TVITUNES = 'iTunes';
    }
    case /darkweb/i {
        $MEDIAMUSIC = 'Media';
        $LOCALIZEDADD = '.localized';
	$LOCALIZEDNOT = '.localized';
        $USERNAME = 'dballing';
        $TVITUNES = 'TV';
    }
    else {
        $MEDIAMUSIC = 'Music';
        $LOCALIZEDADD = '';
	$LOCALIZEDNOT = '';
        $USERNAME = 'derek.balling';
        $TVITUNES = 'iTunes';
    }
}

my $HOMEDIR = '/Users/' . $USERNAME;
my $ITUNES_AUTO_ADD = $HOMEDIR . '/Music/iTunes/iTunes ' . $MEDIAMUSIC .
    '/Automatically Add to ' . $TVITUNES . $LOCALIZEDADD;
my $NOT_ADDED_DIR = $ITUNES_AUTO_ADD . '/Not Added' . $LOCALIZEDNOT;
my $DROPBOX_DIR = $HOMEDIR . '/Dropbox (Harris-Balling)/Darkweb Files';
my $TORRENT_ROOT = $HOMEDIR . '/Desktop/Torrenting';
my $SRC_PATH = $TORRENT_ROOT . '/Actual Programming';
my $DEST_PATH = $TORRENT_ROOT . '/AppleTVReady';

opendir AUTOADD, $NOT_ADDED_DIR;
my @autoadd_dirs = readdir (AUTOADD);
closedir AUTOADD;

foreach my $autoadd_dir (@autoadd_dirs)
{
    next if $autoadd_dir =~ /^\./;
    
    my $SUBDIR = $NOT_ADDED_DIR . '/' . $autoadd_dir;
    opendir ADDFILES, $SUBDIR;
    my @add_files = readdir (ADDFILES);
    closedir ADDFILES;
    print "DIR: $SUBDIR\n";

    foreach my $filename (@add_files)
    {
	next if $filename !~ /\.(mkv|flv|mp4|m4v|avi)$/;
	my $old_fqfn = $SUBDIR . '/' . $filename;
	my $new_fqfn = $ITUNES_AUTO_ADD . '/' . $filename;
	print $old_fqfn, "\n";
	rename $old_fqfn, $new_fqfn;
    }
    rmdir $SUBDIR;
}
