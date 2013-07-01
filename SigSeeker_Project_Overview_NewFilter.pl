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

my $cgi = new CGI;

SigSeeker::header();
SigSeeker::subheader($cgi->param("project"),'Filter');


my $dsn = sprintf(
    'DBI:mysql:database=sigseeker_v2;host=localhost',
    'cdcol', 'localhost'
);

my $dbh = DBI->connect($dsn, $SigSeeker::MYSQL_USER,$SigSeeker::MYSQL_PASS);

my $sth = $dbh->prepare('SELECT * FROM PROJECTS');
my $projects = $dbh->selectall_hashref('SELECT * FROM PROJECTS', 'ID');
$sth = $dbh->prepare('SELECT * FROM PEAKPLUS');
my $peakplus = $dbh->selectall_hashref('SELECT * FROM PEAKPLUS', 'PROJECT');

my $project = $projects->{$cgi->param("project")}->{ABBREVIATION};
my $exclusion_sample = $cgi->param("exclude_sample");
my $blacklist_overlap = $cgi->param("blacklist_overlap");

my $exclude_sample;
my @ex_sam = split(/\,/,$exclusion_sample);
foreach my $ex (@ex_sam)
{
        $exclude_sample->{$ex} = 1;
}

my @TOOLS;
#print "Running analysis for ";
foreach my $id (keys %$peakplus)
{ 
    if($id eq $cgi->param("project"))
    { 
        foreach my $tool (keys %{$peakplus->{$id}})
        { 
            if($peakplus->{$id}->{$tool} =~ /true|pending/i)
            {
#                print $tool.' ';
                push(@TOOLS,$tool);
            }
        }
    }
}
#print "\n";

if($cgi->param("visualization"))
{
    my $sets;
    my @allsets;
    
    open(IN,$SigSeeker::PEAK_REPOSITORY.$project.'/Files.tsv');
    while(my $record = <IN>)
    {
        chomp($record);
        $record =~ /^(\d+)/;
        my $id = $1;
        $record =~ s/^(\d+)\t//;
        my @tmp = split(/\_/,$record);
        my $tool = $tmp[-2];
        my $set = $tmp[-3];
        #print $record.'<br>';
        $sets->{$set} = 1;
    }
    close IN;
    
    print "<h2>Index</h2>";
    for(my $setcount = scalar(keys %$sets);$setcount > 0;$setcount--)
    {
        my $setcomb = Math::Combinatorics->new(count => $setcount,data => [keys %$sets],);
        while(my @setcombo = $setcomb->next_combination)
        {
            my $currentset;
            foreach my $tmpset (@setcombo)
            {
                $currentset->{$tmpset} = 1;
            }
            my $linkname = join(' and ', sort @setcombo);
            print '<a href="#'.$linkname.'">'.$linkname.'</a><br>';
        }
    }
    print '<hr>';
    for(my $setcount = scalar(keys %$sets);$setcount > 0;$setcount--)
    {
        my $setcomb = Math::Combinatorics->new(count => $setcount,data => [keys %$sets],);
        while(my @setcombo = $setcomb->next_combination)
        {
            my $currentset;
            foreach my $tmpset (@setcombo)
            {
                $currentset->{$tmpset} = 1;
            }
            my $linkname = join(' and ', sort @setcombo);
            print '<a id="'.$linkname.'">'.$linkname.'</a><br>';

            my $files;
            my $comparisons;
            my $lookupids;
        
            open(IN,$SigSeeker::PEAK_REPOSITORY.$project.'/Files.tsv');
            while(my $record = <IN>)
            {
                chomp($record);
                $record =~ /^(\d+)/;
                my $id = $1;
                $record =~ s/^(\d+)\t//;
                my @tmp = split(/\_/,$record);
                my $tool = $tmp[-2];
                my $set = $tmp[-3];
                #print $record.'<br>';
                if($currentset->{$set})
                {
                    $files->{$tool}->{$id} = $record;
                }
            }
            close IN;
        
            
            open(IN,$SigSeeker::PEAK_REPOSITORY.$project.'/Comparisons.tsv');
            while(my $record = <IN>)
            {
                chomp($record);
                my @tmp = split(/\t/,$record);
                $comparisons->{$tmp[0]} = $tmp[1];
        #        print $tmp[0].' - '.$tmp[1].'<br>';
            }
            close IN;
        
            #print "Analysis for ".scalar(@TOOLS).'<br>';
            if(scalar(@TOOLS) == 5)
            {
                my @n = qw(0 1 2 3 4);
                for(my $i = 1;$i<=5;$i++)
                {
                    my $combinat = Math::Combinatorics->new(count => $i,data => [@n],);
                    while(my @combo = $combinat->next_combination)
                    {
                        my @ids;
        #                print join('', sort @combo).' - ';
                        foreach my $element (sort @combo)
                        {
        #                    print $TOOLS[$element].' - ';
                            foreach my $id (keys %{$files->{$TOOLS[$element]}})
                            {
                                push (@ids,$id);
                            }
                        }
                        if($comparisons->{'Comparison_'.join('_', sort {$a<=>$b} @ids)})
                        {
                            $lookupids->{'ID_'.join('', sort @combo)} = $comparisons->{'Comparison_'.join('_', sort {$a<=>$b} @ids)};
                        }
                        else
                        {
                            $lookupids->{'ID_'.join('', sort @combo)} = '0';
                        }
        #                print 'ID_'.join('', sort @combo).' - '.$comparisons->{'Comparison_'.join('_', sort {$a<=>$b} @ids)}.'<br>';
                    }
                }
                print '<div style="position:absolute;z-index:1">';
                print '<div style="position:absolute;z-index:100;top: 10px; left: 400px;width: 100px;height: 10px;">'.$TOOLS[0].'</div>'; #A-Title
                print '<div style="position:absolute;z-index:100;top: 150px;left: 550px;width: 100px;height: 10px;">'.$TOOLS[1].'</div>'; #B-Title
                print '<div style="position:absolute;z-index:100;top: 600px;left: 550px;width: 100px;height: 10px;">'.$TOOLS[2].'</div>'; #C-Title
                print '<div style="position:absolute;z-index:100;top: 600px;left: 250px;width: 100px;height: 10px;">'.$TOOLS[3].'</div>'; #D-Title
                print '<div style="position:absolute;z-index:100;top: 150px;left: 10px; width: 100px;height: 10px;">'.$TOOLS[4].'</div>'; #E-Title
                
                print '<div style="position:absolute;z-index:100;top: 50px; left: 310px;width: 100px;height: 10px;">'.$lookupids->{'ID_0'}.'</div>'; #A
                print '<div style="position:absolute;z-index:100;top: 200px;left: 550px;width: 100px;height: 10px;">'.$lookupids->{'ID_1'}.'</div>'; #B
                print '<div style="position:absolute;z-index:100;top: 550px;left: 455px;width: 100px;height: 10px;">'.$lookupids->{'ID_2'}.'</div>'; #C
                print '<div style="position:absolute;z-index:100;top: 550px;left: 200px;width: 100px;height: 10px;">'.$lookupids->{'ID_3'}.'</div>'; #D
                print '<div style="position:absolute;z-index:100;top: 220px;left: 40px; width: 100px;height: 10px;">'.$lookupids->{'ID_4'}.'</div>'; #E
                
                print '<div style="position:absolute;z-index:100;top: 180px;left: 450px;width: 100px;height: 10px;">'.$lookupids->{'ID_01'}.'</div>'; #AB
                print '<div style="position:absolute;z-index:100;top: 520px;left: 390px;width: 100px;height: 10px;">'.$lookupids->{'ID_02'}.'</div>'; #AC
                print '<div style="position:absolute;z-index:100;top: 120px;left: 330px;width: 100px;height: 10px;">'.$lookupids->{'ID_03'}.'</div>'; #AD
                print '<div style="position:absolute;z-index:100;top: 145px;left: 215px;width: 100px;height: 10px;">'.$lookupids->{'ID_04'}.'</div>'; #AE
                print '<div style="position:absolute;z-index:100;top: 420px;left: 490px;width: 100px;height: 10px;">'.$lookupids->{'ID_12'}.'</div>'; #BC
                print '<div style="position:absolute;z-index:100;top: 445px;left: 130px;width: 100px;height: 10px;">'.$lookupids->{'ID_13'}.'</div>'; #BD
                print '<div style="position:absolute;z-index:100;top: 320px;left: 500px;width: 100px;height: 10px;">'.$lookupids->{'ID_14'}.'</div>'; #BE
                print '<div style="position:absolute;z-index:100;top: 520px;left: 275px;width: 100px;height: 10px;">'.$lookupids->{'ID_23'}.'</div>'; #CD
                print '<div style="position:absolute;z-index:100;top: 220px;left: 120px;width: 100px;height: 10px;">'.$lookupids->{'ID_24'}.'</div>'; #CE
                print '<div style="position:absolute;z-index:100;top: 350px;left: 115px;width: 100px;height: 10px;">'.$lookupids->{'ID_34'}.'</div>'; #CD
                
                print '<div style="position:absolute;z-index:100;top: 445px;left: 390px;width: 100px;height: 10px;">'.$lookupids->{'ID_012'}.'</div>'; #ABC
                print '<div style="position:absolute;z-index:100;top: 180px;left: 420px;width: 100px;height: 10px;">'.$lookupids->{'ID_013'}.'</div>'; #ABD
                print '<div style="position:absolute;z-index:100;top: 270px;left: 455px;width: 100px;height: 10px;">'.$lookupids->{'ID_014'}.'</div>'; #ABE
                print '<div style="position:absolute;z-index:100;top: 520px;left: 295px;width: 100px;height: 10px;">'.$lookupids->{'ID_023'}.'</div>'; #ACD
                print '<div style="position:absolute;z-index:100;top: 165px;left: 205px;width: 100px;height: 10px;">'.$lookupids->{'ID_024'}.'</div>'; #ACE
                print '<div style="position:absolute;z-index:100;top: 180px;left: 330px;width: 100px;height: 10px;">'.$lookupids->{'ID_034'}.'</div>'; #ADE
                print '<div style="position:absolute;z-index:100;top: 445px;left: 210px;width: 100px;height: 10px;">'.$lookupids->{'ID_123'}.'</div>'; #BCD
                print '<div style="position:absolute;z-index:100;top: 400px;left: 490px;width: 100px;height: 10px;">'.$lookupids->{'ID_124'}.'</div>'; #BCE
                print '<div style="position:absolute;z-index:100;top: 375px;left: 130px;width: 100px;height: 10px;">'.$lookupids->{'ID_134'}.'</div>'; #BDE
                print '<div style="position:absolute;z-index:100;top: 270px;left: 160px;width: 100px;height: 10px;">'.$lookupids->{'ID_234'}.'</div>'; #CDE
                
                print '<div style="position:absolute;z-index:100;top: 445px;left: 290px;width: 100px;height: 10px;">'.$lookupids->{'ID_0123'}.'</div>'; #ABCD
                print '<div style="position:absolute;z-index:100;top: 375px;left: 420px;width: 100px;height: 10px;">'.$lookupids->{'ID_0124'}.'</div>'; #ABCE
                print '<div style="position:absolute;z-index:100;top: 220px;left: 390px;width: 100px;height: 10px;">'.$lookupids->{'ID_0134'}.'</div>'; #ABDE
                print '<div style="position:absolute;z-index:100;top: 220px;left: 225px;width: 100px;height: 10px;">'.$lookupids->{'ID_0234'}.'</div>'; #ACDE
                print '<div style="position:absolute;z-index:100;top: 375px;left: 160px;width: 100px;height: 10px;">'.$lookupids->{'ID_1234'}.'</div>'; #BCDE
                
                print '<div style="position:absolute;z-index:100;top: 320px;left: 290px;width: 100px;height: 10px;">'.$lookupids->{'ID_01234'}.'</div>'; #ABCDE
                
                print '<img src="'.$ENV->{SERVER}.'/Images/5Venn.gif" width="640"/>';
                print '</div>';
            }
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
            print '<br>';
        }
    }
#    print '<h3>Raw Data</h3>';
#    print '<a href="'.$ENV->{SERVER}.'/Alexandria/Peak_Repository/'.$project.'/Box_Part.png"><img src="'.$ENV->{SERVER}.'/Alexandria/Peak_Repository/'.$project.'/Box_Part.png" width=400></a>';
#    print '<h3>Encode Optimized Data</h3>';
#    print '<a href="'.$ENV->{SERVER}.'/Alexandria/Peak_Repository/'.$project.'/Box_Part_Optimized.png"><img src="'.$ENV->{SERVER}.'/Alexandria/Peak_Repository/'.$project.'/Box_Part_Optimized.png" width=400></a>';
}
else
{
    my $results;
    my $tools;
    
    print '<h3>Replicate Comparison</h3>';
    open(IN,$SigSeeker::PEAK_REPOSITORY.$project.'/Replicates.tsv');
    while(my $record = <IN>)
    {
        chomp($record);
        my @field = split(/\t/,$record);
        #SET    SUB     TOOL    PEAK
        $results->{$field[0]}->{$field[1]}->{$field[2]} = $field[3];
        $tools->{$field[2]} = 1;
    }
    close IN;

    print '<table border=1>';
    print '<tr>';
    print '<th>Set</th>';
    print '<th>Sub</th>';
    foreach my $tool (sort {$a cmp $b} keys %$tools)
    {
        print '<th>'.$tool.'</th>';
    }
    print '</tr>';
    foreach my $set (keys %$results)
    {
        foreach my $sub (keys %{$results->{$set}})
        {
            print '<tr>';
            print '<td>'.$set.'</td>';
            print '<td>'.$sub.'</td>';
            foreach my $tool (sort {$a cmp $b} keys %$tools)
            {
                print '<td>'.$results->{$set}->{$sub}->{$tool}.'</td>';
            }
            print '</tr>';
        }
    }
    print '</table>';

    my $results_comparisons;
    my $files;

    print '<h3>In-depth Tool Comparisons</h3>';

    print '<table border=1 class="sortable">';
    print '<tr>';
#    print '<th>Files</th>';
    foreach my $set (keys %$results)
    {
        foreach my $sub (keys %{$results->{$set}})
        {
            print '<th>'.$set.'-'.$sub.'</th>';
        }
    }
    print '<th>Covered Sets</th>';
    foreach my $tool (sort {$a cmp $b} keys %$tools)
    {
        print '<th>'.$tool.'</th>';
    }
    print '<th>Covered Tools</th>';
    print '<th>Predicted Peaks</th>';
    print '</tr>';
    open(IN,$SigSeeker::PEAK_REPOSITORY.$project.'/Files.tsv');
    while(my $record = <IN>)
    {
        chomp($record);
        my @fields = split(/\t/,$record);
        $files->{'ID'.$fields[0]} = $fields[1];
    }
    close IN;
    
    open(IN,$SigSeeker::PEAK_REPOSITORY.$project.'/Comparisons.tsv');
    while(my $record = <IN>)
    {
        print '<tr>';
        my $infohash;
#        print $record.' - ';
        chomp($record);

        $record =~ /(\d+)$/;
        my $count = $1;
        $record =~ s/\s\d+$//;

#        print '<td>';
        my @fields = split(/\_/,$record);
        foreach my $id (@fields)
        {
            if($id ne "Comparison")
            {
                my $info = $files->{'ID'.$id};
                #my $path = $SigSeeker::PEAK_REPOSITORY.$project;
                $info =~ s/.+\///;
#                print $id.' - '.$info.'<br>';
 
                my @fieldinfo = split(/\_/,$info);
                $infohash->{$fieldinfo[1]} = 1;
                $infohash->{$fieldinfo[2]} = 1;
            }
        }
#        print '</td>';
        my $setcount = 0;
        foreach my $set (keys %$results)
        {
            foreach my $sub (keys %{$results->{$set}})
            {
                if($infohash->{$set.'-'.$sub})
                {
                    $setcount++;
                    print '<td>X</td>';
                }
                else
                {
                    print '<td></td>';
                }
            }
        }
        print '<td>'.$setcount.'</td>';
        
        my $toolcount = 0;
        foreach my $tool (sort {$a cmp $b} keys %$tools)
        {
            if($infohash->{$tool})
            {
                $toolcount++;
                print '<td>X</td>';
            }
            else
            {
                print '<td></td>';
            }
        }
        print '<td>'.$toolcount.'</td>';
        print '<td>'.$count.'</td>';
#        print '<td>'.$record.'</td>';
        print '</tr>';
#        my @field = split(/\t/,$record);
#        #SET    SUB     TOOL    PEAK
#        $results->{$field[0]}->{$field[1]}->{$field[2]} = $field[3];
#        $tools->{$field[2]} = 1;
    }
    close IN;
    print '</table>';

}

SigSeeker::footer();

1;
