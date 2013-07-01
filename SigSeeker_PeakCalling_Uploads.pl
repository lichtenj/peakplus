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

use SigSeeker;

SigSeeker::header("Peak Calling");

my $cgi = new CGI;

my $parameters;
my $samples;
my $controls;

print '<form action="./SigSeeker_PeakCalling_Submission.pl" method=POST enctype="multipart/form-data">';
if(! $cgi->param("projectname"))
{
    # Configure the program
    # The various parameters passed in the UA POST are documented on Google's page
    # Authentication: http://bit.ly/1apxYA
    # Spreadsheets access: http://bit.ly/Qfcxg
    
    # Create browser and XML objects, and send a request for authentication
    my $objUA = LWP::UserAgent->new;
    my $objXML = XML::Simple->new;
    my $objResponse = $objUA->post(
            'https://www.google.com/accounts/ClientLogin',
            {
    	        accountType     => 'GOOGLE',
                Email           => $SigSeeker::GOOGLE_USER,
    	        Passwd          => $SigSeeker::GOOGLE_PASS,
    	        service         => 'wise',
    	        source          => 'Populate Database',
    	        "GData-Version" => '2',
            }
    );
    
    # Fail if the HTTP request didn't work
    die "\nError: ", $objResponse->status_line unless $objResponse->is_success;
    
    my $authtoken = ExtractAuth($objResponse->content);
    $objUA->default_header('Authorization' => "GoogleLogin auth=$authtoken");
    
    my $key = '0AijOb-M7RXOYdEJFOXZpc0ozeks3d29HZDRUbU5uN0E';
    $objResponse = Fetch($objUA, "http://spreadsheets.google.com/feeds/list/".$key."/od6/private/full");
    my $objWorksheet = $objXML->XMLin($objResponse, ForceArray => 1);
        
    my $hash;
    
    foreach my $sRow (@{$objWorksheet->{entry}})
    {
    	if($sRow->{'gsx:installed'}[0] eq "x")
    	{
    		$hash->{$sRow->{'gsx:name'}[0]}->{citation} = $sRow->{'gsx:citation'}[0];
    
    		$hash->{$sRow->{'gsx:name'}[0]}->{tag_categorization} = $sRow->{'gsx:wilbankssequencetagcategorization'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{peakfinding_categorization} = $sRow->{'gsx:wilbankspeakfindingcategorization'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{peakscoring_categorization} = $sRow->{'gsx:wilbankspeakscoringcategorization'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{controlassessment_categorization} = $sRow->{'gsx:wilbankscontrolassessment'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{backgroundmodel_categorization} = $sRow->{'gsx:wilbanksbackgroundmodelcategorization'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{bam} = $sRow->{'gsx:bam'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{bedgraph} = $sRow->{'gsx:bedgraph'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{sam} = $sRow->{'gsx:sam'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{bed} = $sRow->{'gsx:bed'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{eland} = $sRow->{'gsx:eland'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{elandmulti} = $sRow->{'gsx:elandmulti'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{elandmultipet} = $sRow->{'gsx:elandmultipet'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{elandexport} = $sRow->{'gsx:elandexport'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{bowtie} = $sRow->{'gsx:bowtie'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{bampe} = $sRow->{'gsx:bampe'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{aln} = $sRow->{'gsx:aln'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{samplecategorization} = $sRow->{'gsx:samplecategorization'}[0];
    		$hash->{$sRow->{'gsx:name'}[0]}->{controlcategorization} = $sRow->{'gsx:controlcategorization'}[0];
    	}
    }
    
    print '<h2>Ensemble Parameters</h2>';
    print '<table border=1>';
    print '<tr><th>Parameter ID</th><th>Parameter Value</th></tr>';
    foreach my $param ($cgi->param)
    {
    	print '<input type="hidden" name="'.$param.'" value="'.$cgi->param($param).'">';
    
    	if($param !~ /password/)
    	{
    		print '<tr>';
    		print '<td>'.$param.'</td>';
    		print '<td>';
    		foreach my $value ($cgi->param($param))
    		{
    			print $value.'<br>';
    			if($param =~ /categorization/)
    			{
    				$parameters->{$param}->{$value} = 1;
    			}
    			if($param eq "samplenumber")
    			{
    				$samples = $value;
    			}
    			if($param eq "controlnumber")
    			{
    				$controls = $value;
    			}
    		}
    		print '</td>';
    		print '</tr>';
    	}
    }
    print '</table>';
    
    my $included_tools;
    foreach my $tool (keys %$hash)
    {
    	my $include = 1;
    	foreach my $param (keys %$parameters)
    	{
    		if($parameters->{$param}->{$hash->{$tool}->{$param}} != 1 && $hash->{$tool}->{$param} ne 'unknown')
    		{
    			print "Eliminated $tool".'<br>';
    			$include = 0;
    		}
    	}
    
    	if($hash->{$tool}->{samplecategorization} eq 'unknown')
    	{
    		print "Eliminated $tool based on sample categrization as unknown".'<br>';
    		$include = 0;
    	}
    	if($hash->{$tool}->{controlcategorization} eq 'unknown')
    	{
    		print "Eliminated $tool based on control categrization as unknown".'<br>';
    		$include = 0;
    	}
    
    #	if($hash->{$tool}->{samplecategorization} eq 'OO' && $samples != 1)
    #	{
    #		print "Eliminated $tool based on sample categrization as OO".'<br>';
    #		$include = 0;
    #	}
    #	if($hash->{$tool}->{samplecategorization} eq 'ZOO' && $samples > 1)
    #	{
    #		print "Eliminated $tool based on sample categrization as ZOO".'<br>';
    #		$include = 0;
    #	}
    #	if($hash->{$tool}->{controlcategorization} eq 'OO' && $controls != 1)
    #	{
    #		print "Eliminated $tool based on control categrization as OO".'<br>';
    #		$include = 0;
    #	}
    #	if($hash->{$tool}->{controlcategorization} eq 'ZOO' && $controls > 1)
    #	{
    #		print "Eliminated $tool based on control categrization as ZOO".'<br>';
    #		$include = 0;
    #	}
    	if($hash->{$tool}->{controlcategorization} eq 'Z' && $controls > 0)
    	{
    		print "Eliminated $tool based on control categrization as Z".'<br>';
    		$include = 0;
    	}
    
    	if($include == 1)
    	{
    		$included_tools->{$tool} = 1;
    	}
    }
    
    print '<h2>Included Tools</h2>';
    print '<table border=1>';
    print '<tr><th>Tool Name</th><th>Citation</th></tr>';
    foreach my $tool (keys %$included_tools)
    {
    	print '<input type=hidden name="approach" value="'.$tool.'">';
    	print '<tr>';
    	print '<td>'.$tool.'</td>';
    	print '<td>'.$hash->{$tool}->{citation}.'</td>';
    	print '</tr>';
    }
    print '</table>';
    
    print '<h2>General Project Information</h2>';
    print 'Project Name: <INPUT TYPE=TEXT NAME="projectname"/><br/><br/>';
}
else
{
    print '<h2>General Project Information</h2>';
    print 'Project Name: '.$cgi->param("projectname").'<br/><br/>';
    print '<INPUT TYPE=HIDDEN NAME="projectname" VALUE="'.$cgi->param("projectname").'"/>';
    $samples = 1;
    $controls = 1;
}

print '<h2>Upload Aligned Reads</h2>';

print '<table border=1>';

print '<tr><th>Category</th>';
print '<th>Cell Type</th>';
print '<th>File Upload</th></tr>';

for(my $i = 1; $i <= $samples; $i++)
{
	print '<tr>';
	if($i == 1)
	{
		print '<td rowspan='.$samples.'>Samples</td>';
	}
	print '<td><INPUT TYPE=TEXT NAME="sample_name_'.$i.'"/></td>';
    print '<td><INPUT TYPE=FILE NAME="sample_file_'.$i.'"></td>';
	print '</tr>';
}
for(my $i = 1+$samples; $i <= $samples+$controls; $i++)
{
	print '<tr>';
	if($i == 1+$samples)
	{
		print '<td rowspan='.$controls.'>Controls</td>';
	}
	print '<td><INPUT TYPE=TEXT NAME="control_name_'.$i.'"/></td>';
    print '<td><INPUT TYPE=FILE NAME="control_file_'.$i.'"></td>';
	print '</tr>';
}
print '</table>';

print '<br>';
print '<input type="submit" value="Submit">';
print ' File Upload and Data Analysis'; 
print '</form>';

SigSeeker::footer();

# Extract the authorization token from Google's return string
sub ExtractAuth {
	# Split the input into lines, loop over and return the value for the 
	# one starting Auth=
   	for (split /\n/, shift) { 
   		return $1 if $_ =~ /^Auth=(.*)$/; 
   	}
   	return '';
 }
 
# Fetch a URL
sub Fetch {
	# Create the local variables and pull in the UA and URL
	my ($objUA, $sURL) = @_;
 
	# Grab the URL, but fail if you can't get the content
	my $objResponse = $objUA->get($sURL);
	die "Failed to fetch $sURL " . $objResponse->status_line if !$objResponse->is_success;
 
	# Return the result
	return $objResponse->content;
}

1;
