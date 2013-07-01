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
my $organism = $cgi->param('organism');

SigSeeker::header("Peak Calling");

if(-e $SigSeeker::READ_UPLOADS.$project.'/setup.tsv') # This needs to be associated with a MySQL query instead to track the user
{
    #print('perl peakcalling_pipeline.pl '.$project.' '.$organism.' false false false false');
    system('perl peakcalling_pipeline.pl '.$project.' '.$organism.' false false false false > log.txt 2>errorlog.txt &');
    #system('perl peakcalling_pipeline.pl '.$project.' '.$organism.' false false false false');
}

print 'Your project has been submitted for analysis and you will receive an email upon its completion<br><br>';

print 'You may check the status of the analysis <a href="./SigSeeker_Status.pl?project='.$project.'">here</a>';

SigSeeker::footer();