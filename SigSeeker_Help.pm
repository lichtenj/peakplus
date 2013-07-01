package SigSeeker_Help;

use DBI;
use LWP::UserAgent;
use XML::Simple;

$MYSQL_USER = '<USERNAME>';
$MYSQL_PASS = '<PASSWORD>';
$GOOGLE_USER = '<USERNAME>';
$GOOGLE_PASS = '<PASSWORD>';
my $key = '<PEAKPLUS HELP TABLE ID>';

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
	        Email           => $GOOGLE_USER,
	        Passwd          => $GOOGLE_PASS,
	        service         => 'wise',
	        source          => 'Populate Database',
	        "GData-Version" => '2',
        }
);

# Fail if the HTTP request didn't work
die "\nError: ", $objResponse->status_line unless $objResponse->is_success;


my $authtoken = ExtractAuth($objResponse->content);
$objUA->default_header('Authorization' => "GoogleLogin auth=$authtoken");

$objResponse = Fetch($objUA, "http://spreadsheets.google.com/feeds/list/".$key."/od6/private/full");
my $objWorksheet = $objXML->XMLin($objResponse, ForceArray => 1);

our $helphash;

foreach my $sRow (@{$objWorksheet->{entry}}) 
{
	my $source = $sRow->{'gsx:source'}[0];
	my $id = $sRow->{'gsx:id'}[0];
	my $description = $sRow->{'gsx:description'}[0];

	$helphash->{$source}->{$id} = $description;

#	print $source."\n";
#	print $id."\n";
#	print $description."\n";
}

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
