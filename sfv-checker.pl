#!/usr/bin/perl

use strict;
use warnings;

use Digest::CRC qw();
use Cwd qw(abs_path);
use File::Basename qw(dirname basename);
use List::Util qw(min max);

$| = 1;

unless (@ARGV) {
	print STDERR "Usage: $0 SFVFILE [SFVFILE ...]$/";
	exit(1);
}

my $ctx = Digest::CRC->new('type' => 'crc32');
my $errors = 0;
my $max_filename_length = 40;

foreach my $sfvfile (@ARGV) {
	print basename($sfvfile), $/;
	my $sfvh;
	unless (open($sfvh, '<', $sfvfile)) {
		print "$!$/$/";
		$errors = 1;
		next;
	}
	print $/;
	my $dir = dirname($sfvfile);
	my @entries;
	while (my $line = <$sfvh>) {
		next if ($line =~ /^\s*;/
			|| $line !~ /^\s*(.+?)\s+([0-9A-Za-z]{1,8})\s*/);
		my ($filename, $crc32) = ($1, $2);
		my $path = abs_path("$dir/$filename");
		$crc32 = canonicalize_crc($crc32);
		push @entries, [ $path, basename($path), $crc32 ];
	}
	close($sfvh);
	my $total = scalar(@entries);
	my $num_length = length($total);
	my $format = "%${num_length}d/$total  %8s  %-${max_filename_length}s  ";
	my $ok = 0;
	my $i = 0;
	foreach my $entry (@entries) {
		my ($abspath, $filename, $crc32) = @$entry;
		printf($format, ++$i, $crc32,
			(length($filename) > $max_filename_length
				? substr($filename, 0, $max_filename_length - 3) . '...'
				: $filename));
		my $fh;
		unless (open($fh, '<', $abspath)) {
			print "Error$/$!$/";
			next;
		}
		binmode($fh);
		$ctx->addfile($fh);
		close($fh);
		my $digest = $ctx->hexdigest();
		$ctx->reset();
		$digest = canonicalize_crc($digest);
		unless ($digest eq $crc32) {
			print "$digest :-($/";
			next;
		}
		print "OK$/";
		$ok++;
	}
	print $/;
	my $erroneous = $total - $ok;
	if ($erroneous) {
		$errors = 1;
		print "Erroneous files: $erroneous$/";
	} else {
		print "All files OK$/";
	}
	print $/;
}

exit($errors ? 2 : 0);

sub canonicalize_crc {
	return sprintf '%08s', lc shift;
}
