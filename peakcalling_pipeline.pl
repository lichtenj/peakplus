#!/usr/bin/perl

use strict;
use Math::Combinatorics;
use lib '/home/darklichti/Dropbox/SigSeeker_CODE_05012013';
use lib '/Users/lichtenbergj/SigSeeker_CODE_05012013';
use SigSeeker;

my $project = shift or die;
my $org = shift or die;
my $peakcalling = "true";
my $encode_threshold = 10000;
my $comparison = shift or die;
my $filtering = shift or die;
my $partitioning = shift or die;
my $visualization = shift or die;

my $dsn = sprintf(
    'DBI:mysql:database=sigseeker_v2;host=localhost',
    'cdcol', 'localhost'
);

my $dbh = DBI->connect($dsn, $SigSeeker::MYSQL_USER,$SigSeeker::MYSQL_PASS);

my $sth = $dbh->prepare('SELECT * FROM PROJECTS');
my $projects = $dbh->selectall_hashref('SELECT * FROM PROJECTS', 'ID');
$sth = $dbh->prepare('SELECT * FROM PEAKPLUS');
my $peakplus = $dbh->selectall_hashref('SELECT * FROM PEAKPLUS', 'PROJECT');

my @TOOLS;
print "Running ".$project." analysis for ";
foreach my $id (keys %$peakplus)
{ 
    if($projects->{$id}->{ABBREVIATION} eq $project)
    {
        #print "IN HERE";
        foreach my $tool (keys %{$peakplus->{$id}})
        { 
            if($peakplus->{$id}->{$tool} =~ /true|pending/i)
            {
                print $tool.' ';
                push(@TOOLS,$tool);
            }
        }
    }
}
print "\n";

if(! -d $SigSeeker::PEAK_REPOSITORY.$project)
{
    system('mkdir '.$SigSeeker::PEAK_REPOSITORY.$project);
}

my $organism;
if($org =~ /mm(\d+)/){$organism = 'mm';}
if($org =~ /hg(\d+)/){$organism = 'hs';}

my $selected_tools;
foreach my $tool (@TOOLS)
{
	$selected_tools->{$tool} = 1;
}

my $setup;
my $setup_opt;
my @partitioning_files;
my $encode_filtered;
my $max_peaks = 0;

if($peakcalling eq "true")
{
    open(PEAKS, ">".$SigSeeker::PEAK_REPOSITORY.$project.'/Called_Peaks.tsv');

    open(IN, $SigSeeker::READ_UPLOADS.$project.'/setup.tsv') or die "setup.tsv not specified for $project";
    while(my $record = <IN>)
    {
    	print $record;
    
    	chomp($record);
    	my @entry = split(/\t+/,$record);
    
    	my @samples = split(/\,/,$entry[1]);
    	my @controls = split(/\,/,$entry[2]);
    
    	my $temp = $entry[0];
    	$temp =~ s/CFU\-E/CFUE/;
        $temp =~ s/CFU\-MEG/CFUMEG/;
        $temp =~ s/CD34\-High/CD34High/;
        $temp =~ s/CD34\-Low/CD34Low/;

        my @breakdown = split(/[\-\_]/,$temp);
        if(!$breakdown[1]){$breakdown[1] = "MBD2";}
        
    	foreach my $sample (@samples)
    	{
		    #if($sample != 75){next;}
            if($selected_tools->{"BROADPEAK"})
            {
                my $control = "BLANK";
                
                push(@partitioning_files,$entry[0].'_'.$sample.'_'.$control.'_BROADPEAK_peaks.bed');
                if(! -e $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_BROADPEAK_peaks.bed' || -z $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_BROADPEAK_peaks.bed')
        	    {
   				    print "---------------------------------------------------\n";
	    			print "BroadPeak\n";
		    		print "---------------------------------------------------\n";

                    if(! -e $project.'/'.$project.'_'.$sample.'.bedgraph' || -z $project.'/'.$project.'_'.$sample.'.bedgraph')
        			{
						print "Conversion Sample\n";
                        
    					system('genomeCoverageBed -ibam '.$project.'/'.$project.'_'.$sample.'.BAM -g /usr/local/share/'.$org.'.genome -bg > '.$project.'/'.$project.'_'.$sample.'.bedgraph');
    				}

    				system('/var/www/follow/Tool_Peak_Calling_Ensemble/Tools/BroadPeak/BroadPeak -i '.$project.'/'.$project.'_'.$sample.'.bedgraph -m '.$project.'_'.$sample.' -t unsupervised');
                    system('cp '.$project.'_'.$sample.'/'.$project.'_'.$sample.'_broad_peak_unsupervised/'.$project.'_'.$sample.'_broad_peak_unsupervised.bed '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_BROADPEAK_peaks.bed');
                    system('rm -rf '.$project.'_'.$sample);
                }
                
                remove_junk($SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_BROADPEAK_peaks.bed');

                my $cmd = 'wc -l '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_BROADPEAK_peaks.bed';
                my $count = `$cmd`;
                $count =~ /(\d+)/;
                my $peaks = $1;
                if($max_peaks < $peaks){$max_peaks = $peaks;}
                if($peaks >= $encode_threshold)
                {
                    $setup_opt->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"BROADPEAK"} = $peaks;
                }
                else
                {
                    $encode_filtered->{$sample}->{$control} = 1;
                }
                $setup->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"BROADPEAK"} = $peaks;
                
                print PEAKS $breakdown[0]."\t".$breakdown[1]."\t".$sample."\t".$control."\t"."BROADPEAK"."\t".$peaks."\n";
            }

    		foreach my $control (@controls)
    		{
    			print "Set: ".$sample."\t".$control."\n";
    
                #$setup->{$entry[0]}->{$sample}->{$control} = 1;

                if($selected_tools->{"SICER"})
                {
                    push(@partitioning_files,$entry[0].'_'.$sample.'_'.$control.'_SICER_peaks.bed');
                    if(! -e $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_SICER_peaks.bed' || -z $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_SICER_peaks.bed')
        		    {
       				    print "---------------------------------------------------\n";
    	    			print "SICER\n";
    		    		print "---------------------------------------------------\n";

                        if(! -e $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.bed' || -z $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.bed')
            			{
    						print "Conversion Sample\n";
                            my $cmd = 'bamToBed -i '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.BAM > '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.bed';
        					system($cmd);
        				}

                        if(! -e $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.bed' || -z $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.bed')
                		{
    						print "Conversion Control\n";
                            my $cmd = 'bamToBed -i '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.BAM > '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.bed';
        					system($cmd);
        				}

        				system('sh '.$SigSeeker::TOOL_REPOSITORY.'SICER/SICER.sh '.$SigSeeker::READ_UPLOADS.$project.' '.$project.'_'.$sample.'.bam.bed '.$project.'_'.$control.'.bam.bed '.$SigSeeker::PEAK_REPOSITORY.$project.' '.$org.' 1 200 150 0.74 600 .01');
                        system('cp '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-W200-G600-FDR.01-island.bed '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_SICER_peaks.bed');

                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-W200-G600-FDR.01-island.bed');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-W200-G600-FDR.01-islandfiltered.bed');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-W200-G600-FDR.01-islandfiltered-normalized.bed');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-W200-G600-islands-summary-FDR.01');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-W200-G600-islands-summary');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-W200-G600.scoreisland');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-W200-normalized.wig');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-W200.graph');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$sample.'.bam-1-removed.bed');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$project.'_'.$control.'.bam-1-removed.bed');
    			    }
                    
                    remove_junk($SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_SICER_peaks.bed');

                    my $cmd = 'wc -l '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_SICER_peaks.bed';
                    my $count = `$cmd`;
                    $count =~ /(\d+)/;
                    my $peaks = $1;
                    if($max_peaks < $peaks){$max_peaks = $peaks;}
                    if($peaks >= $encode_threshold)
                    {
                        $setup_opt->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"SICER"} = $peaks;
                    }
                    else
                    {
                        $encode_filtered->{$sample}->{$control} = 1;
                    }
                    $setup->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"SICER"} = $peaks;
                    
                    print PEAKS $breakdown[0]."\t".$breakdown[1]."\t".$sample."\t".$control."\t"."SICER"."\t".$peaks."\n";
                }
                
                if($selected_tools->{"CISGENOME"})
                {
                    push(@partitioning_files,$entry[0].'_'.$sample.'_'.$control.'_CISGENOME_peaks.bed');
                    if(! -e $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_CISGENOME_peaks.bed' || -z $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_CISGENOME_peaks.bed')
            	    {
       				    print "---------------------------------------------------\n";
    	    			print "CISGENOME\n";
    		    		print "---------------------------------------------------\n";

                        if(! -e $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.aln' || -z $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.aln')
            			{
    						print "Conversion Sample\n";
                            
                            if(! -e $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.bed' || -z $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.bed')
                		    {
                                system('bamToBed -i '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.BAM > '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.bed');
                		    }
                            
                            system($SigSeeker::TOOL_REPOSITORY.'cisgenome_project/bin/file_bed2aln -i '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.bed -o '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.aln');
        				}

                        if(! -e $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.aln' || -z $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.aln')
                		{
    						print "Conversion Control\n";
                            
                            if(! -e $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.bed' || -z $SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.bed')
                    	    {
        					    system('bamToBed -i '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.BAM > '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.bed');
                    	    }
                            
                            system($SigSeeker::TOOL_REPOSITORY.'cisgenome_project/bin/file_bed2aln -i '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.bed -o '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.aln');
        				}

                        open(CGOUT,">"."CG_".$sample.'_'.$control);
                        print CGOUT $project.'/'.$project.'_'.$sample.'.aln'."\t1\n";
                        print CGOUT $project.'/'.$project.'_'.$control.'.aln'."\t0\n";
                        close CGOUT;

        				system($SigSeeker::TOOL_REPOSITORY.'cisgenome_project/bin/seqpeak -i CG_'.$sample.'_'.$control.' -d '.$SigSeeker::PEAK_REPOSITORY.$project.' -o CG_'.$project.'_'.$sample.'_'.$control);
                        system($SigSeeker::TOOL_REPOSITORY.'cisgenome_project/bin/file_cod2bed -i '.$SigSeeker::PEAK_REPOSITORY.$project.'/CG_'.$project.'_'.$sample.'_'.$control.'_peak.cod -o '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_CISGENOMEunsorted_peaks.bed');
                        system('sort -k1,1 -k2,2g -o '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_CISGENOME_peaks.bed '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_CISGENOMEunsorted_peaks.bed');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_CISGENOMEunsorted_peaks.bed');
    			    }

                    remove_junk($SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_CISGENOME_peaks.bed');

                    my $cmd = 'wc -l '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_CISGENOME_peaks.bed';
                    my $count = `$cmd`;
                    $count =~ /(\d+)/;
                    my $peaks = $1;
                    if($max_peaks < $peaks){$max_peaks = $peaks;}
                    if($peaks >= $encode_threshold)
                    {
                        $setup_opt->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"CISGENOME"} = $peaks;
                    }
                    else
                    {
                        $encode_filtered->{$sample}->{$control} = 1;
                    }
                    $setup->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"CISGENOME"} = $peaks;
                    
                    print PEAKS $breakdown[0]."\t".$breakdown[1]."\t".$sample."\t".$control."\t"."CISGENOME"."\t".$peaks."\n";
                }
                
                if($selected_tools->{"MACS"})
                {
                    push(@partitioning_files,$entry[0].'_'.$sample.'_'.$control.'_MACS_peaks.bed');
                    if(! -e $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS_peaks.bed' || -z $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS_peaks.bed')
    			    {
       				    print "---------------------------------------------------\n";
    	    			print "MACS\n";
    		    		print "---------------------------------------------------\n";
                        
                        #print('macs14 -t '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.BAM -c '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.BAM -p 1e-5 -g '.$organism.' -n '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS')."\n";
                        
        				system('macs14 -t '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.BAM -c '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.BAM -p 1e-5 -g '.$organism.' -n '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS');
        
        				system('R --vanilla < '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS_model.r');
        				system('convert '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS_model.pdf '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS_model.png');
    			    }

                    remove_junk($SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS_peaks.bed');

                    my $cmd = 'wc -l '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS_peaks.bed';
                    my $count = `$cmd`;
                    $count =~ /(\d+)/;
                    my $peaks = $1;
                    if($max_peaks < $peaks){$max_peaks = $peaks;}
                    if($peaks >= $encode_threshold)
                    {
                        $setup_opt->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"MACS"} = $peaks;
                    }
                    else
                    {
                        $encode_filtered->{$sample}->{$control} = 1;
                    }
                    $setup->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"MACS"} = $peaks;
                    
                    print PEAKS $breakdown[0]."\t".$breakdown[1]."\t".$sample."\t".$control."\t"."MACS"."\t".$peaks."\n";
                }

                if($selected_tools->{"MACS2"})
                {
                    push(@partitioning_files,$entry[0].'_'.$sample.'_'.$control.'_MACS2_peaks.bed');
                    if(! -e $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS2_peaks.bed' || -z $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS2_peaks.bed')
    			    {
    				    print "---------------------------------------------------\n";
    				    print "MACS2\n";
    				    print "---------------------------------------------------\n";
        
        				system('macs2 callpeak -t '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.BAM -c '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.BAM -p 1e-5 -g '.$organism.' -n '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS2');
        
        				system('R --vanilla < '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS2_model.r');
        				system('convert '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS2_model.pdf '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS2_model.png');
    			    }

                    remove_junk($SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS2_peaks.bed');


                    my $cmd = 'wc -l '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_MACS2_peaks.bed';
                    my $count = `$cmd`;
                    $count =~ /(\d+)/;
                    my $peaks = $1;
                    if($max_peaks < $peaks){$max_peaks = $peaks;}
                    if($peaks >= $encode_threshold)
                    {
                        $setup_opt->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"MACS2"} = $peaks;
                    }
                    else
                    {
                        $encode_filtered->{$sample}->{$control} = 1;
                    }
                    $setup->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"MACS2"} = $peaks;
                    
                    print PEAKS $breakdown[0]."\t".$breakdown[1]."\t".$sample."\t".$control."\t"."MACS2"."\t".$peaks."\n";
                }
    
    			if($selected_tools->{"Sole-Search"})
                {
                    push(@partitioning_files,$entry[0].'_'.$sample.'_'.$control.'_Sole-Search_peaks.bed');
                    if(! -e $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_Sole-Search_peaks.bed' || -z $SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_Sole-Search_peaks.bed')
        			{
#    	    			print "---------------------------------------------------\n";
#		    			print "Sole-Search\n";
#	    				print "---------------------------------------------------\n";
        
        				if(! -e $SigSeeker::TOOL_REPOSITORY.'sole-search/'.$project.'_'.$sample.'.eland' || -z $SigSeeker::TOOL_REPOSITORY.'sole-search/'.$project.'_'.$sample.'.eland')
        				{
    						print "Conversion Sample\n";
                            
        					print($SigSeeker::TOOL_REPOSITORY.'pyicos convert '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.BAM '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.eland -f bam -F eland');
                            print "\n";
                            
            				system($SigSeeker::TOOL_REPOSITORY.'pyicos convert '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.BAM '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.eland -f bam -F eland');
		               	    system('cp '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$sample.'.bam.eland '.$SigSeeker::TOOL_REPOSITORY.'sole-search/'.$project.'_'.$sample.'.eland');
        				}
        				if(! -e $SigSeeker::TOOL_REPOSITORY.'sole-search/'.$project.'_'.$control.'.eland' || -z $SigSeeker::TOOL_REPOSITORY.'sole-search/'.$project.'_'.$control.'.eland')
        				{
   					        print "Conversion Control\n";
                           
           				    print ($SigSeeker::TOOL_REPOSITORY.'pyicos convert '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.BAM '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.eland -f bam -F eland');
                            print "\n";
                           
                            system($SigSeeker::TOOL_REPOSITORY.'pyicos convert '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.BAM '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.eland -f bam -F eland');
       	           			system('cp '.$SigSeeker::READ_UPLOADS.$project.'/'.$project.'_'.$control.'.bam.eland '.$SigSeeker::TOOL_REPOSITORY.'sole-search/'.$project.'_'.$control.'.eland');
        				}
        				chdir($SigSeeker::TOOL_REPOSITORY.'sole-search');
        				if(! -e $project.'_'.$sample.'.export.txt_full-length.txt' || -z $project.'_'.$sample.'.export.txt_full-length.txt')
        				{
        				    print "Parsing Sample\n";
                            
                            print('sh parse_eland.sh '.$project.'_'.$sample.'.eland '.$project.'_'.$sample.'.export.txt');
                            print "\n";

                            system('sh parse_eland.sh '.$project.'_'.$sample.'.eland '.$project.'_'.$sample.'.export.txt');
        				}
        				if(! -e $project.'_'.$control.'.export.txt_full-length.txt' || -z $project.'_'.$control.'.export.txt_full-length.txt')
        				{
    					    print "Parsing Control\n";
                            
            				print('sh parse_eland.sh '.$project.'_'.$control.'.eland '.$project.'_'.$control.'.export.txt');
                            print "\n";
                            
                            system('sh parse_eland.sh '.$project.'_'.$control.'.eland '.$project.'_'.$control.'.export.txt');
    			    	}
        				if(! -e $project.'_'.$control.'.export.txt_full-length.txt' || -z $project.'_'.$control.'.export.txt_full-length.txt')
        				{
    						print "Normalizing Control\n";
                            
        					print('perl normalize_sd.pl -a 0.001 '.$project.'_'.$control.'.export.txt_full-length.txt');
                            print "\n";
                            
                            system('perl normalize_sd.pl -a 0.001 '.$project.'_'.$control.'.export.txt_full-length.txt');
        				}
				    	print "Sole-Searching\n";
                        
                        print('perl Sole-searchV2.pl -t '.$project.'_'.$control.'.export.txt_tags.txt -c '.$project.'_'.$control.'.export.txt_full-length.txt_corrected_0.001.sgr -p '.$project.'_'.$control.'.1.export.txt_full-length.txt_duplications.gff '.$project.'_'.$sample.'.export.txt_full-length.txt 2> /dev/null > /dev/null');
                        print "\n";
                        
    					system('perl Sole-searchV2.pl -t '.$project.'_'.$control.'.export.txt_tags.txt -c '.$project.'_'.$control.'.export.txt_full-length.txt_corrected_0.001.sgr -p '.$project.'_'.$control.'.1.export.txt_full-length.txt_duplications.gff '.$project.'_'.$sample.'.export.txt_full-length.txt 2> /dev/null > /dev/null');
                    
				    	print "Conversion of Significant Peaks\n";
                    
	            		print('perl convert_gff2bed.pl '.$project.'_'.$sample.'.export.txt_full-length.txt_signifpeaks.gff > '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_Sole-Searchunsorted_peaks.bed');
                        print "\n";
                    
                        system('perl convert_gff2bed.pl '.$project.'_'.$sample.'.export.txt_full-length.txt_signifpeaks.gff > '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_Sole-Searchunsorted_peaks.bed');
                        
        				chdir($SigSeeker::READ_UPLOADS);
                        
                        system('sort -k1,1 -k2,2g -o '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_Sole-Search_peaks.bed '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_Sole-Searchunsorted_peaks.bed');
                        system('rm '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_Sole-Searchunsorted_peaks.bed');
                    }
                    remove_junk($SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_Sole-Search_peaks.bed');
                
                    my $cmd = 'wc -l '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$entry[0].'_'.$sample.'_'.$control.'_Sole-Search_peaks.bed';
                    my $count = `$cmd`;
                    $count =~ /(\d+)/;
                    my $peaks = $1;
                    if($max_peaks < $peaks){$max_peaks = $peaks;}
                    if($peaks >= $encode_threshold)
                    {
                        $setup_opt->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"Sole-Search"} = $peaks;
                    }
                    else
                    {
                        $encode_filtered->{$sample}->{$control} = 1;
                    }
                    $setup->{$breakdown[0]}->{$breakdown[1]}->{$sample}->{$control}->{"Sole-Search"} = $peaks;
                    
                    print PEAKS $breakdown[0]."\t".$breakdown[1]."\t".$sample."\t".$control."\t"."Sole-Search"."\t".$peaks."\n";
                }
            }
    	}
    }
    close IN;

    print "Peak Call Visualization\n";

    #Peak Call Visualization
    my @set_order = ("HSC","CMP","MEP","GMP","CFUMEG","MEG","CFUE","ERY");
    my $order = "";
    #my @set_order = keys %$setup;
    
    my $vis_norm = "true";
    if($vis_norm eq "true")
    {
        my $sets;
        my $subs;
    	my $samples;
    	my $tools;
    	
    	foreach my $set (@set_order)
    	{
            my $bool = 0;
    		foreach my $sub (keys %{$setup->{$set}})
    		{
    			foreach my $sample (keys %{$setup->{$set}->{$sub}})
    			{
                    $bool = 1;
    				my $tool;
    				foreach my $control (keys %{$setup->{$set}->{$sub}->{$sample}})
    				{
    					foreach my $app (keys %$selected_tools)
    					{
                            if($setup->{$set}->{$sub}->{$sample}->{$control}->{$app})
                            {
        						$sets .= '"'.$set.'",';
        						$subs .= '"'.$sub.'",';
        						$tool->{$app} .= $setup->{$set}->{$sub}->{$sample}->{$control}->{$app}.',';			
        						$tools .= '"'.$app.'",';
                            }
    					}
    				}
    				foreach my $app (keys %$tool)
    				{
    					chop($tool->{$app});
    					if(scalar(keys %{$setup->{$set}->{$sub}->{$sample}}) > 1)
    					{
    						$samples .= 'c('.$tool->{$app}.'),';
                        }
    					else
    					{
    						$samples .= $tool->{$app}.',';
                        }
   				}
    			}
    		}
            if($bool == 1)
            {
                $order .= '"'.$set.'",';
            }
    	}
        chop $order;
        
        open(R, ">peaks.r");
        print R 'library(ggplot2)'."\n";
        print R 'peaks = data.frame('."\n";
        chop($sets);
        print R '  set = c('.$sets.'),'."\n";
        chop($subs);
        print R '  sub = c('.$subs.'),'."\n";
        chop($samples);
        print R '  peaks = c('.$samples.'),'."\n";
        chop($tools);
        print R '  tool = c('.$tools.')'."\n";
        print R ')'."\n";
        print R 'png(file = "'.$SigSeeker::PEAK_REPOSITORY.$project.'/Box_Part.png", width = 1024, height = 640, units = "px", pointsize = 12, bg="transparent")'."\n";
        if($order)
        {
            #print R 'qplot(set, peaks, data = peaks,geom="boxplot",main = "Peak Calling") + aes(ymin=0,ymax='.($max_peaks + 1000).') + scale_y_continuous(breaks=seq(0,'.$max_peaks.',10000)) + scale_x_discrete(limits=c('.$order.')) + geom_jitter(position=position_jitter(w=0.1, h=0.1)) + ylab("#\\ Peaks") + xlab("Cell Types") + facet_grid(sub~tool) + theme(text = element_text(size=20), axis.text.x = element_text(angle = 90, hjust = 1))'."\n";
            print R 'qplot(set, peaks, data = peaks,geom="boxplot",main = "Peak Calling") + aes(ymin=0,ymax='.($max_peaks + 1000).') + scale_y_continuous(breaks=seq(0,'.$max_peaks.',10000)) + scale_x_discrete(limits=c('.$order.')) + geom_jitter(position=position_jitter(w=0.1, h=0.1)) + ylab("#\\ Peaks") + xlab("Cell Types") + facet_grid(sub~tool) + theme(text = element_text(size=20))'."\n";
        }
        else
        {
            #print R 'qplot(set, peaks, data = peaks,geom="boxplot",main = "Peak Calling") + aes(ymin=0,ymax='.($max_peaks + 1000).') + scale_y_continuous(breaks=seq(0,'.$max_peaks.',10000)) + geom_jitter(position=position_jitter(w=0.1, h=0.1)) + ylab("#\\ Peaks") + xlab("Cell Types") + facet_grid(sub~tool) + theme(text = element_text(size=20), axis.text.x = element_text(angle = 90, hjust = 1))'."\n";
            print R 'qplot(set, peaks, data = peaks,geom="boxplot",main = "Peak Calling") + aes(ymin=0,ymax='.($max_peaks + 1000).') + scale_y_continuous(breaks=seq(0,'.$max_peaks.',10000)) + geom_jitter(position=position_jitter(w=0.1, h=0.1)) + ylab("#\\ Peaks") + xlab("Cell Types") + facet_grid(sub~tool) + theme(text = element_text(size=20))'."\n";
        }
        print R 'dev.off()'."\n";
        
        close R;
        
        system('R --vanilla < peaks.r 2> /dev/null > /dev/null');
    }

    my $optimized = "true";
    if($optimized eq "true")
    {
        my $order = "";
        my $sets;
        my $subs;
        my $samples;
    	my $tools;
    	
    	foreach my $set (@set_order)
    	{
            my $bool = 0;
    		foreach my $sub (keys %{$setup->{$set}})
    		{
    			foreach my $sample (keys %{$setup->{$set}->{$sub}})
    			{
                    #print scalar(keys %{$encode_filtered->{$sample}})."\t".(scalar(keys %{$setup->{$set}->{$sub}->{$sample}}) * 0.75)."\n";
                    if(scalar(keys %{$encode_filtered->{$sample}}) < scalar(keys %{$setup->{$set}->{$sub}->{$sample}}) * 0.75)
                    {
                        $bool = 1;
                        my $tool;
        				foreach my $control (keys %{$setup->{$set}->{$sub}->{$sample}})
        				{
        					foreach my $app (keys %$selected_tools)
        					{
                                if($setup->{$set}->{$sub}->{$sample}->{$control}->{$app})
                                {
            						$sets .= '"'.$set.'",';
            						$subs .= '"'.$sub.'",';
                            
            						$tool->{$app} .= $setup->{$set}->{$sub}->{$sample}->{$control}->{$app}.',';
            						$tools .= '"'.$app.'",';
                                }
        					}
        				}
        				foreach my $app (keys %$tool)
        				{
        					chop($tool->{$app});
        					if(scalar(keys %{$setup->{$set}->{$sub}->{$sample}}) > 1)
        					{
        						$samples .= 'c('.$tool->{$app}.'),';
                            }
        					else
        					{
        						$samples .= $tool->{$app}.',';
                            }
        				}
                    }
    			}
    		}
            if($bool == 1)
            {
                $order .= '"'.$set.'",';
            }
    	}
        chop $order;
        
        open(R, ">peaks_opt.r");
        print R 'library(ggplot2)'."\n";
        print R 'peaks = data.frame('."\n";
        chop($sets);
        print R '  set = c('.$sets.'),'."\n";
        chop($subs);
        print R '  sub = c('.$subs.'),'."\n";
        chop($samples);
        print R '  peaks = c('.$samples.'),'."\n";
        chop($tools);
        print R '  tool = c('.$tools.')'."\n";
        print R ')'."\n";
        print R 'png(file = "'.$SigSeeker::PEAK_REPOSITORY.$project.'/Box_Part_Optimized.png", width = 1024, height = 640, units = "px", pointsize = 12, bg="transparent")'."\n";
        if($order)
        {
            print R 'qplot(set, peaks, data = peaks,geom="boxplot",main = "Peak Calling") + aes(ymin=0,ymax='.($max_peaks + 1000).') + scale_y_continuous(breaks=seq(0,'.$max_peaks.',10000)) + scale_x_discrete(limits=c('.$order.')) + geom_jitter(position=position_jitter(w=0.1, h=0.1)) + ylab("#\\ Peaks") + xlab("Cell Types") + facet_grid(sub~tool) + theme(text = element_text(size=20), axis.text.x = element_text(angle = 90, hjust = 1))'."\n";
        }
        else
        {
            print R 'qplot(set, peaks, data = peaks,geom="boxplot",main = "Peak Calling") + aes(ymin=0,ymax='.($max_peaks + 1000).') + scale_y_continuous(breaks=seq(0,'.$max_peaks.',10000)) + geom_jitter(position=position_jitter(w=0.1, h=0.1)) + ylab("#\\ Peaks") + xlab("Cell Types") + facet_grid(sub~tool) + theme(text = element_text(size=20), axis.text.x = element_text(angle = 90, hjust = 1))'."\n";
        }
        print R 'dev.off()'."\n";
        
        close R;
        
        system('R --vanilla < peaks_opt.r 2> /dev/null > /dev/null');
    }

    close PEAKS;

    system('mutt -s "Done with Peak Calling" lichtenberg@msseeker.org -a '.$SigSeeker::PEAK_REPOSITORY.$project.'/Box_Part.png -a '.$SigSeeker::PEAK_REPOSITORY.$project.'/Box_Part_Optimized.png -F /var/.muttrc < '.$SigSeeker::PEAK_REPOSITORY.$project.'/Called_Peaks.tsv');
}


if($comparison eq "true")
{
    my $replicate_files;
    
    print "Replicate Joining\n";
    open(OUT,">".$SigSeeker::PEAK_REPOSITORY.$project.'/Replicates.tsv');
    open(FILES,">".$SigSeeker::PEAK_REPOSITORY.$project."/Files.tsv");
    
    my $count = 0;
    foreach my $tool (keys %$selected_tools)
    {
        foreach my $set (keys %$setup)
        {
            foreach my $sub (keys %{$setup->{$set}})
            {
                my $cmd = 'multiIntersectBed -cluster -i ';
                #print "\t".$sub."\n";
                foreach my $sample (keys %{$setup->{$set}->{$sub}})
                {
                    #print "\t\t".$sample."\n";
                    foreach my $control (keys %{$setup->{$set}->{$sub}->{$sample}})
                    {
                        if(-e $SigSeeker::PEAK_REPOSITORY.$project.'/'.$set.'-'.$sub.'_'.$sample.'_'.$control.'_'.$tool.'_peaks.bed')
                        {
                            $cmd .= $SigSeeker::PEAK_REPOSITORY.$project.'/'.$set.'-'.$sub.'_'.$sample.'_'.$control.'_'.$tool.'_peaks.bed ';
                        }
                    }
                }
                $count++;
                $replicate_files->{$count} = $SigSeeker::PEAK_REPOSITORY.$project.'/Replicates_'.$set.'-'.$sub.'_'.$tool.'_peaks.bed';
                print FILES $count."\t".$replicate_files->{$count}."\n";
                $cmd .= ' > '.$SigSeeker::PEAK_REPOSITORY.$project.'/Replicates_'.$set.'-'.$sub.'_'.$tool.'_peaks.bed';
                system($cmd);
                
                $cmd = 'wc -l '.$SigSeeker::PEAK_REPOSITORY.$project.'/Replicates_'.$set.'-'.$sub.'_'.$tool.'_peaks.bed';
                my $count = `$cmd`;
                $count =~ /(\d+)/;
                my $peaks = $1;
                
                print OUT $set."\t".$sub."\t".$tool."\t".$peaks."\n";
            }
        }
    }
    
    print "Comparison\n";
    my $cmd = 'multiIntersectBed -header -names ';
    foreach my $file (sort {$a <=> $b} keys %$replicate_files)
    {
        $cmd .= $file.' ';
    }
    $cmd .= '-cluster -i ';
    foreach my $file (sort {$a <=> $b} keys %$replicate_files)
    {
        $cmd .= $replicate_files->{$file}.' ';
    }

    $cmd .= '> '.$SigSeeker::PEAK_REPOSITORY.$project.'/Comparisons.bed';

    system($cmd);

    my $comps;
    open(COMP, $SigSeeker::PEAK_REPOSITORY.$project.'/Comparisons.bed');
    
    my $header = <COMP>;
    chomp($header);
    my @head = split(/\t/,$header);
    
    my $count = 0;
    
    while(my $rec = <COMP>)
    {
        $count++;
        
        chomp($rec);
        my @tmp = split(/\t/,$rec);
        $tmp[4] =~ s/\,/\_/g;
        
        #Remove useless comparisons
        my @files = split(/\_/,$tmp[4]);
        my $bool = 0;
        my $tmp_hash;
        my $tmp_tools;
        foreach my $fid (@files)
        {
            my $file = $replicate_files->{$fid};
            my @tmpdir = split(/\//,$file);
            my @tmpfile = split(/\_/,$tmpdir[-1]);
            $tmp_hash->{$tmpfile[1]}->{$tmpfile[2]} = 1;
            $tmp_tools->{$tmpfile[2]} = 1;
        }
        
#if($count == 10){exit;}

        foreach my $tool (keys %$tmp_tools)
        {
            foreach my $set (keys %$tmp_hash)
            {
#                print ">>>>".$tool."\t".$set."\n";
                if(! $tmp_hash->{$set}->{$tool})
                {
                    $bool = 1;
                }
            }
        }

        #Store usefule entries
        if($bool == 0)
        {
#            print $tmp[4]."\n";
            my @tmpbool = split(/\_/,$tmp[4]);
#            foreach my $fbool (@tmpbool)
#            {
#                print "\t".$replicate_files->{$fbool}."\n";    
#            }
            $comps->{'Comparison_'.$tmp[4]}->{$rec} = 1;
            #print $filenames->{$fn}."\n".$bool."\n";
        }
    }
    close COMP;

    open(COMPOUT,">".$SigSeeker::PEAK_REPOSITORY.$project."/Comparisons.tsv");
    foreach my $fn (keys %$comps)
    {
        print COMPOUT $fn."\t".scalar(keys %{$comps->{$fn}})."\n";
        
        push(@partitioning_files, $fn);
        
        open(COMPBED,">".$SigSeeker::PEAK_REPOSITORY.$project.'/'.$fn.'.bed');
        foreach my $record (keys %{$comps->{$fn}})
        {
            print COMPBED $record."\n";
        }
        close COMPBED;
    }
}

if($filtering eq "true")
{
    print "Filtering\n";
    my @filtered_files;
    open(OUT,">".$SigSeeker::PEAK_REPOSITORY.$project."/Filters.tsv");
    foreach my $file (@partitioning_files)
    {
        print OUT $file."\t";
        my $cmd = 'perl peakfiltering.pl '.$SigSeeker::PEAK_REPOSITORY.$project.'/'.$file.'.bed '.$org.' '.$SigSeeker::PEAK_REPOSITORY.$project.'/Filter_'.$file;  
    #    print OUT `$cmd`;
        print OUT `$cmd`;
        print OUT "\n";
    }
    close OUT;
}

if($partitioning eq "true")
{
    open(OUT,">".$SigSeeker::PEAK_REPOSITORY.$project."/Partitions.tsv");
    foreach my $file (@partitioning_files)
    {
        print OUT $file."\t";
        my $cmd = "";
        if($file =~ /^Filter/)
        {
            $cmd = 'perl overlap_analysis.pl '.$SigSeeker::PEAK_REPOSITORY.$project.'/Filter_'.$file.'.bed '.$SigSeeker::PEAK_REPOSITORY.$org.'_refFlat.txt '.$SigSeeker::PEAK_REPOSITORY.$project.'/Partition_'.$file;
        }
        else
        {
            $cmd = 'perl overlap_analysis.pl '.$SigSeeker::PEAK_REPOSITORY.$project.'/Comparison_'.$file.'.bed '.$SigSeeker::PEAK_REPOSITORY.$org.'_refFlat.txt '.$SigSeeker::PEAK_REPOSITORY.$project.'/Partition_'.$file;
        }
        print OUT `$cmd`;
    }
    close OUT;
}

if($visualization eq "true")
{
    foreach my $currenttools (keys %$setup)
    {
    	open(R, ">partitioning.r");
    	
    	my $sets;
    	my $subs;
    	my $samples;
    	my $partitions;
    	
    	foreach my $set (keys %{$setup->{$currenttools}})
    	{
    		foreach my $sub (keys %{$setup->{$currenttools}->{$set}})
    		{
    			foreach my $sample (keys %{$setup->{$currenttools}->{$set}->{$sub}})
    			{
    				my $parts;
    				foreach my $control (keys %{$setup->{$currenttools}->{$set}->{$sub}->{$sample}})
    				{
    					foreach my $partition (keys %{$setup->{$currenttools}->{$set}->{$sub}->{$sample}->{$control}})
    					{
    						$sets .= '"'.$set.'",';
    						$subs .= '"'.$sub.'",';
    						$parts->{$partition} .= $setup->{$currenttools}->{$set}->{$sub}->{$sample}->{$control}->{$partition}.',';			
    	#					$samples .= $setup->{$currenttools}->{$set}->{$sub}->{$sample}->{$control}->{$partition}.',';					
    						$partitions .= '"'.$partition.'",';
    					}
    				}
    				foreach my $part (keys %$parts)
    				{
    					chop($parts->{$part});
    					if(scalar(keys %{$setup->{$currenttools}->{$set}->{$sub}->{$sample}}) > 1)
    					{
    						$samples .= 'c('.$parts->{$part}.'),';
    					}
    					else
    					{
    						$samples .= $parts->{$part}.',';
    					}
    				}
    			}
    		}
    	}
    
    	print R 'library(ggplot2)'."\n";
    	print R 'partitions = data.frame('."\n";
    	chop($sets);
    	print R '  set = c('.$sets.'),'."\n";
    	chop($subs);
    	print R '  sub = c('.$subs.'),'."\n";
    	chop($samples);
    	print R '  peaks = c('.$samples.'),'."\n";
    	chop($partitions);
    	print R '  part = c('.$partitions.')'."\n";
    	print R ')'."\n";
    	print R 'png(file = "'.$SigSeeker::PEAK_REPOSITORY.$project.'/Box_Part.'.$currenttools.'.png",bg="transparent")'."\n";
    	$currenttools =~ s/\|/\,/g;
    	print R 'qplot(set, peaks, data = partitions,geom="boxplot",main = "'.$currenttools.'") + geom_jitter(position=position_jitter(w=0.1, h=0.1)) + ylab("#\\ Peaks") + xlab("Cell Types") + facet_grid(sub~part)'."\n";
    	print R 'dev.off()'."\n";
    	
    	close R;
    
    	system('R --vanilla < partitioning.r 2> r2.log > r.log');
    }
}

print "Done\n";

sub remove_junk
{
    my $inputfile = shift or die;
    open(RIN, $inputfile);
    open(ROUT,">CLEANTMP") or die "Cannot open temporary cleaning file";
    while(my $record = <RIN>)
    {
        if($record =~ /^chr[\dXY]+\t/)
        {
            print ROUT $record;
        }
    }
    close ROUT;
    close RIN;
    system ('mv CLEANTMP '.$inputfile);
}
