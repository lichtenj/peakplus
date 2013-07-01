#!/usr/bin/perl

use strict; 
use warnings;

use CGI::Simple;
use DBI;
use CGI; 
use CGI::Carp qw ( fatalsToBrowser ); 
use File::Basename;
use Math::Combinatorics;

use SigSeeker;

my $dsn = sprintf(
    'DBI:mysql:database=sigseeker_v2;host=localhost',
    'cdcol', 'localhost'
);

my $dbh = DBI->connect($dsn, $SigSeeker::MYSQL_USER,$SigSeeker::MYSQL_PASS);

SigSeeker::header('Status');

my $cgi = new CGI;

my $project = $cgi->param("project");

my $sth = $dbh->prepare('SELECT * FROM PROJECTS WHERE ID="'.$project.'"');
my $projects = $dbh->selectall_hashref('SELECT * FROM PROJECTS WHERE ID="'.$project.'"', 'ID');

$sth = $dbh->prepare('SELECT * FROM PEAKPLUS WHERE PROJECT="'.$project.'"');
my $peakplus = $dbh->selectall_hashref('SELECT * FROM PEAKPLUS WHERE PROJECT="'.$project.'"', 'PROJECT');

$sth = $dbh->prepare('SELECT * FROM PEAKPLUS WHERE PROJECT="'.$project.'"');
my $qualityplus = $dbh->selectall_hashref('SELECT * FROM QUALITYPLUS WHERE PROJECT="'.$project.'"', 'PROJECT');

print '<table border=1>';
print '<tr>';
print '<td>Type</td>';
print '<td>Sample</td>';
print '<td>Control</td>';
foreach my $tool (keys %{$qualityplus->{$project}})
{
	if($tool eq "PROJECT" || $qualityplus->{$project}->{$tool} eq ""){next;}
	print '<td>Quality:'.$tool.'</td>';
}
foreach my $tool (keys %{$peakplus->{$project}})
{
	if($tool eq "PROJECT" || $peakplus->{$project}->{$tool} eq ""){next;}
	print '<td>Peak:'.$tool.'</td>';
}
print '<td>Comparisons</td>';
print '<td>Filters</td>';
print '<td>Partitions</td>';
print '</tr>';

open(IN, $SigSeeker::READ_UPLOADS.$projects->{$project}->{ABBREVIATION}.'/setup.tsv');
while(my $record = <IN>)
{
	chomp($record);
	my @fields = split(/\t+/,$record);

	my @samples = split(/\,/,$fields[1]);
	my @controls = split(/\,/,$fields[2]);

	foreach my $sample (@samples)
	{
		foreach my $control (@controls)
		{
			print '<tr>';
			print '<td>'.$fields[0].'</td><td>'.$sample.'</td><td>'.$control.'</td>';
			foreach my $tool (keys %{$qualityplus->{$project}})
			{
				if($tool eq "PROJECT" || $qualityplus->{$project}->{$tool} eq ""){next;}
				if(( -e $SigSeeker::READ_UPLOADS.$projects->{$project}->{ABBREVIATION}.'/'.$tool.'/'.$projects->{$project}->{ABBREVIATION}.'_'.$sample.'_fastqc.zip' || -e $SigSeeker::READ_UPLOADS.$projects->{$project}->{ABBREVIATION}.'/'.$tool.'/'.$projects->{$project}->{ABBREVIATION}.'_'.$sample.'/info.tab') && ( ! -z $SigSeeker::READ_UPLOADS.$projects->{$project}->{ABBREVIATION}.'/'.$tool.'/'.$projects->{$project}->{ABBREVIATION}.'_'.$sample.'_fastqc.zip' || ! -z $SigSeeker::READ_UPLOADS.$projects->{$project}->{ABBREVIATION}.'/'.$tool.'/'.$projects->{$project}->{ABBREVIATION}.'_'.$sample.'/info.tab'))
				{
					print '<td bgcolor="green">Done</td>';
				}
				else
				{
					print '<td bgcolor="yellow">Pending</td>';
				}
			}
			foreach my $tool (keys %{$peakplus->{$project}})
			{
				if($tool eq "PROJECT" || $peakplus->{$project}->{$tool} eq ""){next;}
				my $file = $SigSeeker::PEAK_REPOSITORY.$projects->{$project}->{ABBREVIATION}.'/'.$fields[0].'_'.$sample.'_'.$control.'_'.$tool.'_peaks.bed';
				if(-e $file && ! -z $file)
				{
					print '<td bgcolor="green">Done</td>';
				}
				else
				{
					print '<td bgcolor="yellow">Pending</td>';
				}
			}
            
			my $file = $SigSeeker::PEAK_REPOSITORY.$projects->{$project}->{ABBREVIATION}.'/Comparisons.tsv';
			if(-e $file && ! -z $file)
			{
				print '<td bgcolor="green">Done</td>';
			}
			else
			{
				print '<td bgcolor="yellow">Pending</td>';
			}
            
			my $file = $SigSeeker::PEAK_REPOSITORY.$projects->{$project}->{ABBREVIATION}.'/Filters.tsv';
			if(-e $file && ! -z $file)
			{
				print '<td bgcolor="green">Done</td>';
			}
			else
			{
				print '<td bgcolor="yellow">Pending</td>';
			}
            
			my $file = $SigSeeker::PEAK_REPOSITORY.$projects->{$project}->{ABBREVIATION}.'/Partitions.tsv';
			if(-e $file && ! -z $file)
			{
				print '<td bgcolor="green">Done</td>';
			}
			else
			{
				print '<td bgcolor="yellow">Pending</td>';
			}

			print '</tr>';
		}
	}
}
close IN;
print '</table>';

SigSeeker::footer();

1;
