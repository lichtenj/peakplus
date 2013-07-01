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

my $sth = $dbh->prepare('SELECT * FROM PROJECTS');
my $projects = $dbh->selectall_hashref('SELECT * FROM PROJECTS', 'ID');

SigSeeker::header();

my $cgi = new CGI;

my $project = $projects->{$cgi->param("project")}->{ABBREVIATION};
my $exclusion_sample = $cgi->param("exclude_sample");
my $blacklist_overlap = $cgi->param("blacklist_overlap");

my $exclude_sample;
my @ex_sam = split(/\,/,$exclusion_sample);
foreach my $ex (@ex_sam)
{
        $exclude_sample->{$ex} = 1;
}

SigSeeker::subheader($cgi->param("project"));

if($cgi->param("visualization"))
{
    print '<h3>Raw Data</h3>';
    print '<a href="'.$ENV->{SERVER}.'/Peak_Repository/'.$project.'/Box_Part.png"><img src="'.$ENV->{SERVER}.'/Peak_Repository/'.$project.'/Box_Part.png" width=400></a>';
    print '<h3>Encode Optimized Data</h3>';
    print '<a href="'.$ENV->{SERVER}.'/Peak_Repository/'.$project.'/Box_Part_Optimized.png"><img src="'.$ENV->{SERVER}.'/Peak_Repository/'.$project.'/Box_Part_Optimized.png" width=400></a>';
}
else
{
    my $results;
    my $tools;
    #print $SigSeeker::PEAK_REPOSITORY.$project.'/Called_Peaks.tsv';
    open(IN,$SigSeeker::PEAK_REPOSITORY.$project.'/Called_Peaks.tsv');
    while(my $record = <IN>)
    {
        chomp($record);
        my @field = split(/\t/,$record);
        $results->{$field[0]}->{$field[1]}->{$field[2]}->{$field[3]}->{$field[4]} = $field[5];
        $tools->{$field[4]} = 1;
    }
    close IN;
    
    print '<table border=1>';
    print '<tr>';
    print '<th>Set</th>';
    print '<th>Sub</th>';
    print '<th>Sample</th>';
    print '<th>Control</th>';
    foreach my $tool (sort {$a cmp $b} keys %$tools)
    {
        print '<th>'.$tool.'</th>';
    }
    print '</tr>';
    foreach my $set (keys %$results)
    {
        foreach my $sub (keys %{$results->{$set}})
        {
            foreach my $sample (keys %{$results->{$set}->{$sub}})
            {
                foreach my $control (keys %{$results->{$set}->{$sub}->{$sample}})
                {
                    print '<tr>';
                    print '<td>'.$set.'</td>';
                    print '<td>'.$sub.'</td>';
                    print '<td>'.$sample.'</td>';
                    print '<td>'.$control.'</td>';
                    foreach my $tool (sort {$a cmp $b} keys %$tools)
                    {
                        print '<td>'.$results->{$set}->{$sub}->{$sample}->{$control}->{$tool}.'</td>';
                    }
                    print '</tr>';
                }
            }
        }
    }
    print '</table>';
}

SigSeeker::footer();

1;
