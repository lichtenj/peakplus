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
my $project = time();

SigSeeker::header("Peak Calling");

print $SigSeeker::READ_UPLOADS.$project.'/setup.tsv<br>';

my $tools;
my $samples;
my $controls;
my $new_project = 1;
print '<span id="shown_parameters" style="display: block;">';
print '<a href="#" onclick="showStuff(\'shown_parameters\',\'hidden_parameters\'); return false;"><img src="../../Images/rt-arrow-square-blue-Shapes4FREE.png"></a>';
print 'Ensemble Parameters';
print '</span>';
print '<span id="hidden_parameters" style="display: none;">';
print '<a href="#" onclick="hideStuff(\'shown_parameters\',\'hidden_parameters\'); return false;"><img src="../../Images/down-arrow-square-blue-Shapes4FREE.png"></a>';
print 'Ensemble Parameters';
print '<table border=1>';
print '<tr><th>Parameter ID</th><th>Parameter Value</th></tr>';
my $setup;
my $upload_dir = $SigSeeker::READ_UPLOADS.$project;
if(! -d $upload_dir)
{
    system('mkdir '.$upload_dir);
}

my $setoff;
if(-e $SigSeeker::READ_UPLOADS.$project.'/setup.tsv') # This needs to be associated with a MySQL query instead to track the user
{
    $new_project = 0;
    
    print "Setup file exists for this project, appending to it now";
    
    open(IN, $SigSeeker::READ_UPLOADS.$project.'/setup.tsv');
    while(my $record = <IN>)
    {
        chomp($record);
        my @tmp = split(/\t/,$record);
        my @samples = split(/\,/,$tmp[1]);
        foreach my $sample (@samples)
        {
            if($setoff < $sample){$setoff = $sample;}
            $setup->{$tmp[0]}->{'sample'}->{$sample} = 1;
        }
        my @controls = split(/\,/,$tmp[2]);
        foreach my $control (@controls)
        {
            if($setoff < $control){$setoff = $control;}
            $setup->{$tmp[0]}->{'control'}->{$control} = 1;
        }
    }
}

print '<tr>';
print '<td>Project ID</td>';
print '<td>';
print $project;
print '</td>';
print '</tr>';
foreach my $param ($cgi->param)
{
	if($param !~ /password/)
	{
		print '<tr>';
		print '<td>'.$param.'</td>';
		print '<td>';
		foreach my $value ($cgi->param($param))
		{
			print $value.'<br>';
		}
		print '</td>';
		print '</tr>';

		if($param eq "approach")
		{
			foreach my $value ($cgi->param($param))
			{
				$tools->{$value} = "PENDING";
			}
		}

		if($param =~ /(sample|control)\_name\_(\d+)$/)
		{
            my $set = $1;
            my $id = $setoff + $2;
            
			my $celltype = $cgi->param($param);
            #print $celltype.' - '.$set.' - '.$id.'<br>';
            
			my $upload_filehandle = $cgi->upload($set.'_file_'.$id);
			
            #Including the sample in the setup file...
            $setup->{$celltype}->{$set}->{$id} = 1;

            my $filename = $upload_dir.'/'.$project.'_'.$id.'.'.$cgi->param('file_format');

            #Uploading the file
			open ( UPLOADFILE, ">$filename" ) or die "$!";
			binmode UPLOADFILE;
			while ( <$upload_filehandle> )
			{
				print UPLOADFILE;
			}
			close UPLOADFILE;
		}
	}
}
print '</table>';
print '</span>';

if($new_project == 1)
{
    my $dsn = sprintf(
        'DBI:mysql:database=sigseeker_v2;host=localhost',
        'cdcol', 'localhost'
    );
    
    my $dbh = DBI->connect($dsn, $SigSeeker::MYSQL_USER,$SigSeeker::MYSQL_PASS);    

    my $sql = 'INSERT INTO `sigseeker_v2`.`PROJECTS` (`ID`, `ABBREVIATION`, `NAME`, `ORGANISM`) VALUES ("'.$project.'", "'.$project.'", "'.$cgi->param("projectname").'", "'.$cgi->param("organism").'");';
    print $sql.'<br>';
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    
    $sql = 'INSERT INTO `sigseeker_v2`.`PEAKPLUS` (`PROJECT`, `MACS`, `MACS2`, `Sole-Search`, `SICER`, `BROADPEAK`, `CISGENOME`) VALUES ("'.$project.'", "'.$tools->{'MACS'}.'", "'.$tools->{'MACS2'}.'", "'.$tools->{'Sole-Search'}.'", "'.$tools->{'SICER'}.'", "'.$tools->{'BROADPEAK'}.'", "'.$tools->{'CISGENOME'}.'");';
    print $sql.'<br>';
    $sth = $dbh->prepare($sql);
    $sth->execute();
}

print '<br><br>';
print '<table border=1>';
print '<tr>';
print '<th>Cell Type</th>';
print '<th>Samples</th>';
print '<th>Controls</th>';
print '</tr>';
open(OUT, ">".$upload_dir.'/setup.tsv') or die "Cannot open ".$upload_dir.'/setup.tsv';
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
print 'Initiate the analysis [<a href="./SigSeeker_PeakCalling_Start.pl?projectname='.$project.'&organism='.$cgi->param("organism").'">here</a>]<br>';

SigSeeker::footer();