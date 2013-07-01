#!/usr/bin/perl

use strict; 
use warnings;

use CGI::Simple;
use DBI;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;
use LWP::UserAgent;
use XML::Simple;
use Scalar::Util qw(looks_like_number);
use Math::Combinatorics;

use SigSeeker;

my $cgi = new CGI;
my $project = $cgi->param('projectname');

SigSeeker::header("Peak Calling");

my $tools;
my $setup;

if(-e $SigSeeker::READ_UPLOADS.$project.'/setup.tsv') # This needs to be associated with a MySQL query instead to track the user
{
    open(IN, $SigSeeker::READ_UPLOADS.$project.'/setup.tsv') or die "Cannot open ".$SigSeeker::READ_UPLOADS.$project."/setup.tsv";
    while(my $record = <IN>)
    {
        #print $record;
        
        chomp($record);
        my @tmp = split(/\t/,$record);
        my @samples = split(/\,/,$tmp[1]);
        foreach my $sample (@samples)
        {
            if($cgi->param("id") != $sample)
            {
                $setup->{$tmp[0]}->{'sample'}->{$sample} = 1;
            }
            else
            {
                print 'Removing Sample "'.$project.'_'.$sample.'"<br>';
                system('rm '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.'.$cgi->param("file_format"));
            }
        }
        my @controls = split(/\,/,$tmp[2]);
        foreach my $control (@controls)
        {
            if($cgi->param("id") != $control)
            {
                $setup->{$tmp[0]}->{'control'}->{$control} = 1;
            }
            else
            {
                print 'Removing Control "'.$project.'_'.$control.'"<br>';
                system('rm '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.'.$cgi->param("file_format"));
            }
        }
    }
}

print '<br><br>';
print '<table border=1>';
print '<tr>';
print '<th>Cell Type</th>';
print '<th>Samples</th>';
print '<th>Controls</th>';
print '</tr>';
open(OUT, ">".$SigSeeker::READ_UPLOADS.$project.'/setup.tsv');
foreach my $ct (keys %$setup)
{
    print '<tr>';
    print '<td>'.$ct.'</td>';
    
    print '<td>';
    my $samples = "";
    foreach my $sample (keys %{$setup->{$ct}->{'sample'}})
    {
        print $sample.'[<a href=./SigSeeker_PeakCalling_RemoveSet.pl?id='.$sample.'&projectname='.$project.'&file_format='.$cgi->param('file_format').'>Remove</a>]<br>';
        $samples .= $sample.',';
    }
    chop($samples);
    print '</td>';

    print '<td>';
    my $controls = "";
    foreach my $control (keys %{$setup->{$ct}->{'control'}})
    {
        print $control.'[<a href=./SigSeeker_PeakCalling_RemoveSet.pl?id='.$control.'&projectname='.$project.'&file_format='.$cgi->param('file_format').'>Remove</a>]<br>';
        $controls .= $control.',';
    }
    chop($controls);
    print '</td>';

    print OUT $ct."\t";
    print OUT $samples."\t";
    print OUT $controls."\n";
    
    print '</tr>';
}
close OUT;
print '</table>';

print '<br><br>';
print 'Add additional sets [<a href="./SigSeeker_PeakCalling_Uploads.pl?projectname='.$project.'">here</a>]<br>';
print 'Initiate the analysis [here]<br>';