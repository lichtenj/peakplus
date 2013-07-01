use strict;
use lib '/home/darklichti/Dropbox/SigSeeker_CODE_05012013';
use lib '/Users/lichtenbergj/SigSeeker_CODE_05012013';
use SigSeeker;

my $file = shift or die;
my $organism = shift or die;
my $id = shift or die;

my @filters;
push(@filters,$SigSeeker::PEAK_REPOSITORY.$organism.'_conservation_top1.bed');
push(@filters,$SigSeeker::PEAK_REPOSITORY.$organism.'_CpG_Islands.bed');

push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM1067274_Erythroid_GATA1_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM1067276_Erythroid_NFE2_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM1067278_Erythroid_p300_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM1067280_Erythroid_H3K4me3_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM908051_H3K27ac-A_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM970258_GATA1-A_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM1067275_Erythroid_KLF1_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM1067277_Erythroid_TAL1_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM1067279_Erythroid_H3K4me2_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM908049_H3K9ac-A_peaks.bed');
push(@filters,$SigSeeker::FILTER_REPOSITORY.'GSM908059_NFE2-A_peaks.bed');

open(IN, $file);
open(OUT, ">".$id.'_modified.bed') or die "Cannot write modified BED file".$id.'_modified.bed';
while(my $record = <IN>)
{
	my @field = split(/\t/,$record);
	print OUT $field[0]."\t";
	print OUT $field[1]."\t";
	print OUT $field[2]."\n";
}
close OUT;
close IN;

foreach my $filter (@filters)
{
#	print "\t".$filter."\n";
    my $filter_id = $filter;
    $filter_id =~ /\/([\w\_\-\.]+)$/;
    $filter_id = $1;
	my $output = $id.'_'.$filter_id.'.bed';
	if(! -e $output || -z $output)
	{
		my $cmd = 'intersectBed -a '.$id.'_modified.bed -b '.$filter.' > '.$output.' 2> /dev/null';
		`$cmd`;
#        print $cmd."\n";
	}
    my $cmd = 'wc -l '.$output;
    my $count = `$cmd`;
    $count =~ /^(\d+)/;
    print $1.' ';
}
