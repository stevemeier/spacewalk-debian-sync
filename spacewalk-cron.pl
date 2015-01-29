#!/usr/bin/perl
#
# Script Cron - Sync repo debian
# Author: Diego Lopes (diego@sistemafieg.org.br)
# Version: 0.1
#
use strict;
use warnings;

our @ARCH = qw( i386 x86_64 );
our $SYNC="/root/spacewalk-debian-sync.pl --username 'username' --password 'pass111'";

=begin ubuntu
Declaração de variáveis para distro ubuntu
--Example ubuntu dists URL
http://archive.ubuntu.com/ubuntu/dists/trusty/{$repo}
http://archive.ubuntu.com/ubuntu/dists/trusty-updates/{$repo}
http://archive.ubuntu.com/ubuntu/dists/trusty-security/{$repo}
http://archive.ubuntu.com/ubuntu/dists/trusty-proposed/{$repo}
http://archive.ubuntu.com/ubuntu/dists/trusty-backports/{$repo}

=cut

our $URL_BASE_UBUNTU = "http://archive.ubuntu.com/ubuntu/dists/";
our @UBUNTU_DIST = qw( trusty );
our @UBUNTU_DIST_CHANNEL = qw( main security updates proposed backports ) ;
our @UBUNTU_REPO = qw( main multiverse restricted universe );
our @UBUNTU_ARCH = qw( x86_64 );

=begin zentyal
Declaração de variáveis para distro zentyal
--Example zentyal dists URL
http://archive.zentyal.org/zentyal/dists/$VERSION/{$repo}

=cut

our $URL_BASE_ZENTYAL = "http://archive.zentyal.org/zentyal/dists/";
our @ZENTYAL_VERSION = qw( 3.5 4.0 );
our @ZENTYAL_REPO = qw( main extra );
our @ZENTYAL_ARCH = qw( x86_64 );

=begin debian
Declaração de variáveis para distro debian
-- Example debian dists URL
http://ftp.us.debian.org/debian/dists/wheezy/{$repo}
http://ftp.us.debian.org/debian/dists/wheezy-updates/{$repo}
http://ftp.us.debian.org/debian/dists/wheezy-backports/{$repo}

-- Example debian dists security URL
http://security.debian.org/dists/wheezy/updates/{$repo}

=cut

our $URL_BASE_DEBIAN = "http://ftp.us.debian.org/debian/dists/";
our @DEBIAN_DIST = qw( wheezy );
our @DEBIAN_DIST_CHANNEL = qw( updates backports security );
our $DEBIAN_DIST_CHANNEL_SECURITY = "http://security.debian.org/dists/";
our @DEBIAN_REPO = qw( main contrib non-free );


=begin

_sync_dist_ubuntu() - Metodo para sincronizar os repositorios do ubuntu

=cut
 
sub _sync_dist_ubuntu() {

foreach my $distro ( @UBUNTU_DIST ) {

	my $url = undef;
	my $cmd = undef;
	my $tmp_channel = undef;
	my $tmp_url = undef;
	my $tmp_repos = undef;

	$url = $URL_BASE_UBUNTU;

	foreach my $channel ( @UBUNTU_DIST_CHANNEL ) {
		
		if ( $channel eq "main" ) {
			#$url = $url . $distro;
			$tmp_url = $distro;
		} elsif ( $channel eq "security" ) {
			#$url = $url . $distro . "-" . $channel;
			$tmp_url = $distro . "-" . $channel;
		} elsif ( $channel eq "updates" ) {
			#$url = $url . $distro . "-" . $channel;
			$tmp_url = $distro . "-" . $channel;
		} elsif ( $channel eq "proposed" ) {
			#$url = $url . $distro . "-" . $channel;
			$tmp_url = $distro . "-" . $channel;
		} elsif ( $channel eq "backports" ) { 
			#$url = $url . $distro . "-" . $channel;
			$tmp_url = $distro . "-" . $channel;
		} else {
			$url = "unknown";
		}
		
	foreach my $repos ( @UBUNTU_REPO ) {

				
		foreach my $arch ( @UBUNTU_ARCH ) {
			my $tmp_arch = undef;

			if ( $arch eq "i386" ){
				$tmp_arch = "binary-i386";
				$url = $url . $tmp_url . "/" . $repos . "/" . $tmp_arch;
				
				$cmd = $SYNC . " --channel " . "'$tmp_channel'" . " --url '$url'" . "\n";
				system ( $cmd );
				
				$url = $URL_BASE_UBUNTU;
			} elsif ( $arch eq "x86_64" ) {
				$tmp_arch = "binary-amd64";
				$url = $url . $tmp_url . "/" . $repos . "/" . $tmp_arch;
				$tmp_channel = "ubuntu" . "-" . $tmp_url . "-" . "x86_64" . "-" . $repos;	 
				$cmd = $SYNC . " --channel " . "'$tmp_channel'" . " --url '$url'" . "\n";
				system ( $cmd );
				#print  $cmd . "\n";
				$url = $URL_BASE_UBUNTU;
				#print "channel: " . "ubuntu" . "-" . $tmp_url . "-" . "x86_64" . "-" .$repos . "\n\n";
			} else {
				$tmp_arch = "unknown";
				print "URL unknown \n";
				$url = undef;
			}
			
		}
	}	

}

}
}

=begin

_sync_dist_zentyal() - Metodo para sincronizar os repositorios zentyal

=cut
 
sub _sync_dist_zentyal() {

foreach my $versao (@ZENTYAL_VERSION) {
	my $tmp = undef;
	my $tmp_arch = undef;
	my $url = undef;
	my $cmd = undef;

	$tmp = $versao;
	$tmp =~ s/\.//ig;
	$tmp_channel = "zentyal" . $tmp;
	
	foreach my $repos ( @ZENTYAL_REPO ) {

		foreach my $arch ( @ZENTYAL_ARCH ) {

			if ( $arch eq "i386" ){
				$tmp_arch = "binary-i386";

			} elsif ( $arch eq "x86_64" ) {
				$tmp_arch = "binary-amd64";
			
			} else {
				$tmp_arch = "unknown";
			}
			
			if ( $repos eq "extra" ){
				$tmp_channel = $tmp_channel . "-extras";
				$url = "$URL_BASE_ZENTYAL" . "$versao" . "/" . $repos . "/" . $tmp_arch;
				$cmd = $SYNC . " --channel " . "'$tmp_channel'" . " --url '$url'" . "\n";

				system ($cmd);
			} else {
				$url = "$URL_BASE_ZENTYAL" . "$versao" . "/" . $repos . "/" . $tmp_arch;
				$cmd = $SYNC . " --channel " . "'$tmp_channel'" . " --url '$url'" . "\n";

				system ($cmd);
			}
		}
	}	

}

}

# Inicia a sincronizacao
_sync_dist_ubuntu();

_sync_dist_zentyal();

