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

my $parameters;

$parameters->{'Peak Assignment'}->{'A'} = "Strand Specific";
$parameters->{'Peak Assignment'}->{'B'} = "Peak Height (Read/Tag Count)";
$parameters->{'Peak Assignment'}->{'C'} = "Fold Enrichment";
$parameters->{'Peak Assignment'}->{'D'} = "Peak Height (P-Value)";
$parameters->{'Peak Assignment'}->{'E'} = "Standard Deviation";

$parameters->{'Profile Generation'}->{'A'} = "Window-based Scan - Sliding";
$parameters->{'Profile Generation'}->{'B'} = "Window-based Scan - Binning";
$parameters->{'Profile Generation'}->{'C'} = "Window-based Scan - Sliding (Strand specific)";
$parameters->{'Profile Generation'}->{'D'} = "Tag Clustering - Distance";
$parameters->{'Profile Generation'}->{'E'} = "Tag Clustering - Overlapping";
$parameters->{'Profile Generation'}->{'F'} = "KDE - Gaussian";

$parameters->{'Control Data'}->{'A'} = "Background Subtraction";
$parameters->{'Control Data'}->{'B'} = "Duplication Compensation";
$parameters->{'Control Data'}->{'C'} = "Delection Compensation";
$parameters->{'Control Data'}->{'D'} = "FDR estimation";
$parameters->{'Control Data'}->{'E'} = "Normalized Control/Fold Enrichment Comparison";
$parameters->{'Control Data'}->{'F'} = "Statistical Model Comparison";
$parameters->{'Control Data'}->{'G'} = "ROC Curve";
$parameters->{'Control Data'}->{'H'} = "A-priori intensity regions";

my $cgi = new CGI;

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

SigSeeker::header("Peak Calling");

my $hash;

my $sample_categorization;
my $control_categorization;

my $tag_categorization;
my $peakfinding_categorization;
my $peakscoring_categorization;
my $controlassessment_categorization;
my $backgroundmodel_categorization;
foreach my $sRow (@{$objWorksheet->{entry}})
{
	if($sRow->{'gsx:installed'}[0] eq "x")
	{
		if($sRow->{'gsx:bam'}[0] eq "x")
		{
			$hash->{'Format'}->{BAM}->{$sRow->{'gsx:name'}[0]} = 1;
		}
		if($sRow->{'gsx:bedgraph'}[0] eq "x")
		{
			$hash->{'Format'}->{BEDGRAPH}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:sam'}[0] eq "x")
		{
			$hash->{'Format'}->{SAM}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:bed'}[0] eq "x")
		{
			$hash->{'Format'}->{BED}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:eland'}[0] eq "x")
		{
			$hash->{'Format'}->{ELAND}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:elandmulti'}[0] eq "x")
		{
			$hash->{'Format'}->{ELANDMULTI}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:elandmultipet'}[0] eq "x")
		{
			$hash->{'Format'}->{ELANDMULTIPET}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:elandexport'}[0] eq "x")
		{
			$hash->{'Format'}->{ELANDEXPORT}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:bowtie'}[0] eq "x")
		{
			$hash->{'Format'}->{BOWTIE}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:bampe'}[0] eq "x")
		{
			$hash->{'Format'}->{BAMPE}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:aln'}[0] eq "x")
		{
			$hash->{'Format'}->{ALN}->{$sRow->{'gsx:name'}[0]} = 1;
		}
        if($sRow->{'gsx:profilegeneration'}[0] !~ /HASH/)
        {
            my @sets = split(//,$sRow->{'gsx:profilegeneration'}[0]);
            foreach my $set (@sets)
            {
                $hash->{'Profile Generation'}->{$set}->{$sRow->{'gsx:name'}[0]} = 1;
            }
        }
        if($sRow->{'gsx:peakassignment'}[0] !~ /HASH/)
        {
            my @sets = split(//,$sRow->{'gsx:peakassignment'}[0]);
            foreach my $set (@sets)
            {
                $hash->{'Peak Assignment'}->{$set}->{$sRow->{'gsx:name'}[0]} = 1;
            }
        }
        if($sRow->{'gsx:controldata'}[0] !~ /HASH/)
        {
            my @sets = split(//,$sRow->{'gsx:controldata'}[0]);
            foreach my $set (@sets)
            {
                $hash->{'Control Data'}->{$set}->{$sRow->{'gsx:name'}[0]} = 1;
            }
        }
    }

}

print '<form action=./SigSeeker_PeakCalling_Uploads.pl method=POST>';

print '<table border=1>';
print '<tr>';
print '<th>Parameter</th>';
print '<th>Value</th>';
print '</tr>';

print '<tr>';
print '<td>Organism</td>';
print '<td>';
print '<select name="organism">';
print '<option value="mm9">Mouse (mm9)</option>';
print '<option value="hg18">Human (hg18)</option>';
print '</select>';
print '</td>';
print '</tr>';

foreach my $parameter (keys %$hash)
{
    print '<tr>';
    print '<td>'.$parameter.'</td>';
    print '<td>';
    if($parameter ne "Format")
    {
        my $varname = $parameter;
        $varname =~ s/\ /\_/g;
        print '<select multiple name="'.$varname.'">';
    }
    else
    {
        print '<select name="file_format">';
    }
    foreach my $format (keys %{$hash->{$parameter}})
    {
        if($parameter eq "Format")
        {
            print '<option value="'.$format.'">'.$format.'</option>';
        }
        else
        {
            print '<option value="'.$parameters->{$parameter}->{$format}.'" selected>'.$parameters->{$parameter}->{$format}.'</option>';
        }
    }
    print '</select>';
    print '</td>';
    print '</tr>';
}

if(0)
{
    print '<tr>';
    print '<td>File Format (Aligned Reads)</td>';
    print '<td>';
    print '<select name="file_format">';
    foreach my $format (keys %$hash)
    {
    	print '<option value="'.$format.'" selected>'.$format.'</option>';
    }
    print '</select>';
    print '</td>';
    print '</tr>';
    
    print '<tr>';
    print '<td>Tag Categorization</td>';
    print '<td>';
    print '<select name="tag_categorization" size=4 multiple>';
    foreach my $category (keys %$tag_categorization)
    {
    	print '<option value="'.$tag_categorization->{$category}.'" selected>'.$tag_categorization->{$category}.'</option>';
    }
    print '</select>';
    print '</td>';
    print '</tr>';
    
    print '<tr>';
    print '<td>Peak Finding Categorization</td>';
    print '<td>';
    print '<select name="peakfinding_categorization" size=4 multiple>';
    foreach my $category (keys %$peakfinding_categorization)
    {
    	print '<option value="'.$peakfinding_categorization->{$category}.'" selected>'.$peakfinding_categorization->{$category}.'</option>';
    }
    print '</select>';
    print '</td>';
    print '</tr>';
    
    print '<tr>';
    print '<td>Peak Scoring Categorization</td>';
    print '<td>';
    print '<select name="peakscoring_categorization" size=4 multiple>';
    foreach my $category (keys %$peakscoring_categorization)
    {
    	print '<option value="'.$peakscoring_categorization->{$category}.'" selected>'.$peakscoring_categorization->{$category}.'</option>';
    }
    print '</select>';
    print '</td>';
    print '</tr>';
    
    print '<tr>';
    print '<td>Control Assessment Categorization</td>';
    print '<td>';
    print '<select name="controlassessment_categorization" size=4 multiple>';
    foreach my $category (keys %$controlassessment_categorization)
    {
    	print '<option value="'.$controlassessment_categorization->{$category}.'" selected>'.$controlassessment_categorization->{$category}.'</option>';
    }
    print '</select>';
    print '</td>';
    print '</tr>';
    
    print '<tr>';
    print '<td>Background Model Categorization</td>';
    print '<td>';
    print '<select name="backgroundmodel_categorization" size=4 multiple>';
    foreach my $category (keys %$backgroundmodel_categorization)
    {
    	print '<option value="'.$backgroundmodel_categorization->{$category}.'" selected>'.$backgroundmodel_categorization->{$category}.'</option>';
    }
    print '</select>';
    print '</td>';
    print '</tr>';
}

print '<tr>';
print '<td>Number of Samples</td>';
print '<td>';
print '<input type="number" name="samplenumber">';
print '</td>';
print '</tr>';

print '<tr>';
print '<td>Number of Controls</td>';
print '<td>';
print '<input type="number" name="controlnumber">';
print '</td>';
print '</tr>';

print '</table>';

print '<br>';
print '<input type="submit" value="Submit">';
print ' Prepare File Upload';
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
