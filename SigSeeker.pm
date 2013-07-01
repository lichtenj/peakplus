package SigSeeker;

use SigSeeker_Help;

$MYSQL_USER = '<USERNAME>';
$MYSQL_PASS = '<PASSWORD>';
$GOOGLE_USER = '<USERNAME>';
$GOOGLE_PASS = '<PASSWORD>';
$READ_UPLOADS = '';
$PEAK_REPOSITORY = '';
$TOOL_REPOSITORY = '';

if($ENV{SERVER_NAME} eq '165.112.60.208')
{
    $READ_UPLOADS = '/Volumes/Mac_HD_RAID/BAM_Repository/';    
    $PEAK_REPOSITORY = '/Volumes/Mac_HD_RAID/PEAK_Repository/';
    $TOOL_REPOSITORY = '/Volumes/Mac_HD_RAID/TOOL_Repository/';
}
else
{
    $READ_UPLOADS = '<YOUR BAM DIRECTORY>';
    $PEAK_REPOSITORY = '<YOUR PEAK DIRECTORY>';
    $TOOL_REPOSITORY = '<YOUR TOOL DIRECTORY>';
}

sub PeakPlus
{
	my $project = shift or die;

	print '<a href="'.$ENV{SERVER}.'/sigseeker-cgi/SigSeeker_Project_Overview_New.pl?project='.$project.'">Overview</a>';
	print '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
	print '<hr>';
}

sub FilterPlus
{
	my $project = shift or die;

	print '<hr>';
}

sub subheader
{
    my $project = shift or die;
    my $analysis = shift;
    
    print '<a href="'.$ENV{SERVER}.'/sigseeker-cgi/SigSeeker_Project_Overview_New.pl?project='.$project.'">Overview</a>';
    print '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    print '<a href="'.$ENV{SERVER}.'/sigseeker-cgi/SigSeeker_Project_Overview_NewFilter.pl?project='.$project.'">Comparisons</a>';
    print '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    print '<br/><br/>';
    print '<a href="'.$ENV{SERVER}.'/sigseeker-cgi/SigSeeker_Project_Overview_New'.$analysis.'.pl?project='.$project.'">Data</a>';
    print '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    print '<a href="'.$ENV{SERVER}.'/sigseeker-cgi/SigSeeker_Project_Overview_New'.$analysis.'.pl?project='.$project.'&visualization=1">Visualization</a>';
    print '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    print '<hr>';
}
sub header
{
	my $title = shift;

	print "Content-type: text/html\n\n";
	print '<html>'."\n";
	print '<head>'."\n";
	print '<title>SigSeeker+</title>'."\n";
    print '<script src="'.$ENV->{SERVER}.'/sorttable.js"></script>'."\n";
    if($title eq "Status")
    {
        print '<meta http-equiv="refresh" content="60" >';
    }
	print '</head>'."\n";
	print "<body>"."\n";
	print "<SCRIPT>"."\n";
	print 'function showStuff(show_id,hide_id) {'."\n";
	print 'document.getElementById(hide_id).style.display = \'block\';'."\n";
	print 'document.getElementById(show_id).style.display = \'none\';'."\n";
	print '}'."\n";

	print 'function hideStuff(show_id,hide_id) {'."\n";
	print 'document.getElementById(hide_id).style.display = \'none\';'."\n";
	print 'document.getElementById(show_id).style.display = \'block\';'."\n";
	print '}'."\n";

	print 'function displayResult(target_type,select_type)'."\n";
	print '{'."\n";
	print '		var x=document.getElementById(target_type);'."\n";
	print '		var selectedArray = new Array();'."\n";
	print '		var selObj = document.getElementById(select_type);'."\n";
	print '		var i;'."\n";
	print '		var count = 0;'."\n";
	print '		for (i=0; i < selObj.options.length; i++)'."\n";
	print '		{'."\n";
	print '			if (selObj.options[i].selected)'."\n";
	print '			{'."\n";
	print '				selectedArray[count] = selObj.options[i].value;'."\n";
	print '				count++;'."\n";
	print '				var option=document.createElement("option");'."\n";
	print '				option.text=selObj.options[i].text;'."\n";
	print '				option.value=selObj.options[i].value;'."\n";
	print '				option.selected=true;'."\n";
	print '				try'."\n";
	print '				{'."\n";
	print '					x.add(option,x.options[null]);'."\n";
	print '				}'."\n";
	print '				catch (e)'."\n";
	print '				{'."\n";
	print '					x.add(option,null);'."\n";
	print '				}'."\n";
	print '			}'."\n";
	print '		}'."\n";
	print '}'."\n";
	print '</SCRIPT>'."\n";

	print "<FORM name=\"jump1\">";
	print '<table style="width:100%">';
	print "<tr>";
	print '<td style="width:75px">';
	print '<a href="./SigSeeker.pl"><img src="http://'.$ENV{'SERVER_NAME'}.'/Images/SigSeeker.png" width=75 alt="Cannot find image"/></a>';
	print "</td><td align=\"left\" valign=\"middle\">&nbsp;Navigation:<BR>";
	print "<select name=\"myjumpbox\" OnChange=\"location.href=jump1.myjumpbox.options[selectedIndex].value\">";
	print "<option selected>Please Select...";
	print "<option value=\"./SigSeeker.pl\">Home";
	print "<option value=\"./SigSeeker_PeakCalling.pl\">Peak Calling";
	print "<option value=\"./SigSeeker_Project_Overview.pl\">Projects";
	print "</select>";
	print "</td>";
	print "</tr>";
	print '</table>';
	print "</FORM>";

	print '<table style="border-spacing:0;width:100%">';
	print '<tr align="center">';
	print '<td style="width:25px;">';
	print '</td>';
	print '<td>';
	print '<p style="font-weight:bold"><a href="./SigSeeker_Examples.pl">Examples</a></p>';
	print '</td>';
	print '<td>';
	print '<p style="font-weight:bold"><a href="./SigSeeker_HELP.pl">Documentation</a></p>';
	print '</td>';
	print '<td>';
	print '<p style="font-weight:bold"><a href="http://code.google.com/p/sigseeker">Downloads</a></p>';
	print '</td>';
	print '</tr>';
	print "</table>";
	print "<hr>";

	#Courtesy of SimplytheBest.net - http://simplythebest.net/scripts/
	print '<div id="overDiv" style="position:absolute; visibility:hide; z-index:1;">';
	print '</div>';
	print '<script LANGUAGE="JavaScript" SRC="../../overlib.js"></script>';
	
	if($title)
	{
		print "<h1>".$title."</h1>";
		print '<p style="width: 800px;">'.$SigSeeker_HELP::helphash->{$title}->{'Documentation'}.'<p>';
	}
}

sub footer
{
	print "<hr>";
	print "Copyright <a href=\"http://msseeker.org\">Jens Lichtenberg</a>";
	print "</body>";

	return;
}

1;
