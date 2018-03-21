#!/usr/bin/perl

# Debian Repository Sync
#
# Downloads Debian packages from mirror and pushes them into Spacewalk
# using rhnpush. This is a workaround until spacewalk-repo-sync natively
# supports Debian repositories
#
# Author:  Steve Meier
# Version: 20130204
#
# Changelog:
# 20130204 - Initial release
# 20130215 - Fix for downloading security repository
# 20130216 - Fix for downloading from snapshot.debian.org
#
# Here are some sample URLs:
#
# squeeze (Debian 6) Base for i386
# -> http://ftp.debian.org/debian/dists/squeeze/main/binary-i386/
#
# squeeze (Debian 6) Updates for i386
# -> http://ftp.debian.org/debian/dists/squeeze-updates/main/binary-i386/
#
# squeeze (Debian 6) Security for i386
# -> http://security.debian.org/dists/squeeze/updates/main/binary-i386/
#
# Replace for i386 with amd64 for 64-bit (x86_64 in CentOS/RHEL)
# Besides main/ there are also contrib/ and non-free/ which you might
# want to add as sub-channels to main/

use strict;
use warnings;
use Compress::Zlib;
use File::Basename;
use Frontier::Client;
use Getopt::Long;
use WWW::Mechanize;

# No buffering
$| = 1;

my $debug = 0;
my ($getopt, $url, $channel, $username, $password, $debianroot);
my $mech;
my ($packages, $package);
my ($pkgname, $fileurl, $md5, $sha1, $sha256, $m_arch, $arch, $version);
my ($client, $session, $allpkg);
my (%inrepo, %inchannel);
my ($synced, $tosync);
my %download;

$getopt = GetOptions( 'url=s'  		=> \$url,
                      'channel=s'	=> \$channel,
		      'username=s'	=> \$username,
		      'password=s'	=> \$password
		    );

# Ubuntu mirrors store data under /ubuntu/
if ($url =~ /(.*ubuntu\/)/) {
  $debianroot = $1;
  &info("Repo URL: $url\n");
  &info("Ubuntu root is $debianroot\n");
}

# Debian mirrors store data under /debian/
if ($url =~ /(.*debian\/)/) {
  $debianroot = $1;
  &info("Repo URL: $url\n");
  &info("Debian root is $debianroot\n");
} 

# security.debian.org has no /debian/ directory
if ($url =~ /security\.debian\.org\//) {
  $debianroot = "http://security.debian.org/";
  &info("Repo URL: $url\n");  
  &info("Debian root is $debianroot\n");
}

# snapshot.debian.org handling
if ($url =~ /(.*\d{8}T\d{6}Z\/)/) {
  $debianroot = $1;
  &info("Repo URL: $url\n");
  &info("Debian root is $debianroot\n");
}

# Abort if we don't know the root
if (not(defined($debianroot))) {
  &error("ERROR: Could not find Debian root directory\n");
  exit(1);
}

# Connect to API
$client = new Frontier::Client(url => "http://localhost/rpc/api") ||
  die "ERROR: Could not connect to API";

# Authenticate to API
$session = $client->call('auth.login', "$username", "$password");
if ($session =~ /^\w+$/) {
  &debug("API Authentication successful\n");
} else {
  &error("API Authentication FAILED!\n");
  exit 3;
}

# Index channel on server
$allpkg = $client->call('channel.software.list_all_packages', $session, $channel);
foreach my $pkg (@$allpkg) {
  &debug("Found $pkg->{'name'} with checksum $pkg->{'checksum'}\n");
  $inchannel{$pkg->{'checksum'}} = 1;
}

# Logout from API
$client->call('auth.logout', $session);

# Download Packages.gz (why does this fail on some mirrors? HTTP deflate maybe?)
$mech = WWW::Mechanize->new;
print "INFO: Fetching Packages.gz... ";
$mech->get("$url/Packages.gz");
print "done\n";

if (not($mech->success)) {
  print "ERROR: Could not retrieve Packages.gz\n";
  exit(1);
}

# Uncompress Packages.gz in memory
$packages = Compress::Zlib::memGunzip($mech->content())
  or die "ERROR: Failed to uncompress Packages.gz\n";

# Parse uncompressed Packages.gz
$tosync = 0;
$synced = 0;

# open temporary file to store,
# package name|multi-arch|channel
if(! open(MULTI, '>', "/tmp/$channel")) {
  printf STDERR "Sorry...cannot log multi-arch values.";
}
foreach $package (split(/\n\n/, $packages)) {
  ($fileurl, $md5, $sha1, $sha256, $pkgname, $m_arch, $arch, $version) = (undef, '', '', '', undef, undef, undef, undef);
  foreach $_ (split(/\n/, $package)) {
    if (/^Filename: (.*)$/) { $fileurl = $1; };
    if (/^MD5sum: (.*)$/)   { $md5     = $1; };
    if (/^SHA1: (.*)$/)     { $sha1    = $1; };
    if (/^SHA256: (.*)$/)   { $sha256  = $1; };
    if (/^Package: (.*)$/)  { $pkgname = $1; };
    if (/^Multi-Arch: (.*)$/) { $m_arch = $1; };
    if (/^Version: (.*)$/)  { $version = $1; };
    if (/^Architecture: (.*)$/)  { $arch = $1; };
  }
  
  if(defined($m_arch)) {
    printf MULTI "%s %s %s %s\n", $pkgname, $version, $arch, $m_arch;
  }
  $inrepo{basename($fileurl)} = $fileurl;
  &debug("Package ".basename($fileurl)." at $fileurl\n");

  if ( (not(exists($inchannel{$md5}))) &&
       (not(exists($inchannel{$sha1}))) &&
       (not(exists($inchannel{$sha256}))) ) {
    $download{basename($fileurl)} = $fileurl;
    $tosync++;
    &debug(basename($fileurl)." needs to be synced\n");
  } else {
    $synced++;
  }
}
close(MULTI);
&info("Packages in repo:\t\t".scalar(keys %inrepo)."\n");
&info("Packages already synced:\t$synced\n");
&info("Packages to sync:\t\t$tosync\n");

# Download missing packages
$synced = 0;
foreach $_ (keys %download) {
  $synced++;
  &info("$synced/$tosync : $_\n");
 
  $mech->get("$debianroot/$download{$_}", ':content_file' => "/tmp/$_");
  if ($mech->success) {
    system("rhnpush -c $channel -u $username -p $password /tmp/$_");
    if ($? > 0) { die "ERROR: rhnpush failed\n"; }
  }
  unlink("/tmp/$_");
}

&info("Sync complete.\n");
exit;

# SUBS
sub debug() {
  if ($debug) { print "DEBUG: @_"; }
}

sub info() {
  print "INFO: @_";
}

sub warning() {
  print "WARNING: @_";
}

sub error() {
  print "ERROR: @_";
}

sub notice() {
  print "NOTICE: @_";
}
