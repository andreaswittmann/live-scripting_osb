#!/usr/bin/perl -w
# wls_weblogic-log-analyis.pl: Script that can be used to analyse weblogic logs
#

use strict;
                                  # globals
use vars qw($Me $Errors $verbose $debug $Filename $FragmentStart $FragmentEnd $Epoch_Start $Epoch_End $CurrentLine $opt %error_map %errorcount_map);
#my ($opt);                       # opt - ref to hash w/ command line options

init();                           # initialize globals
($opt) = parse_args();            # parse command
main();
exit(2) if $Errors;
exit(1);

################################### USAGE
sub usage {
        die <<EOF
usage: $Me [Options] logfilename

Options:
 \t h \t print help text
 \t v \t verbose output
 \t d \t debug output
 \t u \t print usage
Filter Options:
 \t r \t count Error Lines
 \t R \t prints Error Lines
 \t a \t count Alert Lines
 \t A \t prints Alert Lines
 \t w \t count Warning Lines
 \t W \t prints Warning Lines
 \t t \t count Server Starts
 \t T \t prints Server Start Lines
 \t c \t Classify Errors
 \t g \t Garbege Colletion Analyis

Fragment Options:
 \t s \t STARTTIME of analysis periode, Use Timeformat dd-mm-yyyy-hh:mm:ss
 \t e \t ENDTIME of analysis periode, Use Timeformat dd-mm-yyyy-hh:mm:ss
 \t S \t analyze since last Server Start
 \t l \t MINUTES, analyze the last MINUTES only

EOF
}
################################### HELP
sub help {
        die <<EOF
This programm analyses a weblogic log file and prints out analysis information.
It provides the following features:
-it reports the number of errors, alerts, warnings  and Server starts in a weblogic logfile
-it prints the the Error, Warning, Alert, and Server Start lines preceeded by the line number
-it reports the time of the frist an last logentry
-it accpets a starttime and endtime to analyse specific time periodes
-it can limit the analysis to the time periode since the last Server start.
-it can classify errors, i.e. it prints a list with all different Errors in one logfile.

NOTE: WLS interprets hours in logfile dates differently than the time module of Perl.
In Weblogic 12:00:00 AM is 00:00:00 European Time and 12:00:01 PM is 00:00:01 European time, i.e. the first second of the next day.
This there is a workaround implemented in this script to convert to european format.


EOF
}
################################## INIT
sub init {
    ($Me = $0) =~ s!.*/!!;        # get basename of program, "tcgrep"
    $Errors = 0;                  # initialize global counters
    $verbose = 0;
    $debug = 0;
    $Filename = "no file";                #
    $| = 1;                       # autoflush output
    $FragmentStart = 0;                   # start logfile analysis form line1
    $FragmentEnd = -1;                    # end logfile analysis at EOF
    $CurrentLine = 0;                     # indicator of the current line of the file.
    $Epoch_Start = 0;                     # hold the epoch for the starttime of fragment
    $Epoch_End = 0;                       # hold the epoch for the endtime of fragment
}
################################### PARSE_ARGS
sub parse_args {
    use Getopt::Std;
    my ($optstring, $zeros, $nulls, %opt);

    $optstring = "hvdugs:e:l:rRaAwWtTSc";

    $zeros = 'vdg';                 # options to init to 0 (prevent warnings)
    $nulls = 'huf';               # options to init to "" (prevent warnings)

    @opt{ split //, $zeros } = ( 0 )  x length($zeros);
    @opt{ split //, $nulls } = ( '' ) x length($nulls);

    getopts($optstring, \%opt) or usage();

    if ($opt{h}) {                # -h helpfile
        help;
    }
    if ($opt{u}) {                # usage
        usage;
    }
    if ($opt{v}) {                # verbose
        $verbose = 1;
        print "verbose is on \n" if $verbose;
    }
    if ($opt{d}) {                # debug
        $debug = 1;
        print "debug is on \n" if $debug;
    }
    if ($opt{s}) {                # get STARTTIME
        verbose("Option -s is on");
    }
    if ($opt{e}) {                # get ENDTIME
        verbose("Option -e is on");
        #print "Option -e not implemented\n" and exit(2);
    }
    if ($opt{l}) {                # last Minutes
        print "Option -l not implemented\n" and exit(2);
    }
    if ($opt{r}) {                # count Errors
        verbose("Option -r is on");
    }
    if ($opt{R}) {                # print Errors
        verbose("Options -R: Error print is on");
    }
    if ($opt{a}) {                # count Alerts
        verbose("Option -a is on");
    }
    if ($opt{A}) {                # print Alerts
        verbose("Options -A is on");
    }
    if ($opt{t}) {                # count Server Starts
        verbose("Option -t is on");
    }
    if ($opt{T}) {                # print Server Starts
        verbose("Options -T is on");
    }
    if ($opt{S}) {                # analyze since last Server Start
        verbose("Options -S is on");
    }
    if ($opt{c}) {                # analyze since last Server Start
        verbose("Options -c is on");
    }
    if ($opt{g}) {                # analyze since last Server Start
        verbose("Options -g is on");
    }
    $Filename = shift @ARGV or usage;     # get the input filename
                                                          # todo: handle empty filename
        return (\%opt);
}
################################### VERBOsE
sub verbose{
        my $arg1 = shift;
        print "$arg1 \n" if $verbose;
}
################################### Debug
sub debug{
        my $arg1 = shift;
        print "[DEBUG] $arg1 \n" if $debug;
}
################################### MAIN
sub main{
        #verbose("$Me - log File Analysis...");
        findFragment($opt);
        analyzeFragment($opt);
}
##################################### FINDFRAGMENT
sub findFragment{                       ### find the fragment to analyze
        use Time::Local;
        $opt = shift;                   # reference to option hash
        $Epoch_Start = 0;                               # Var for the Fragment start by given Start Date.

        if($opt->{'s'}){                                ### Read in the start date
                my $startdate = $opt->{'s'};# Start date format should be dd-mm-yyyy-hh:mm:ss
                my $dd = 0;
                my $mm = 0;
                my $yyyy = 0;
                my $hour = 0;
                my $min = 0;
                my $sec = 0;
                ($dd, $mm, $yyyy, $hour, $min, $sec) = ($startdate =~ /(\d{1,2})-(\d{1,2})-(\d{4})-(\d{1,2}):(\d{2}):(\d{2})/);
                $Epoch_Start = timelocal($sec, $min, $hour, $dd, $mm-1, $yyyy); # calcualte epoch
                debug("Start Date is $startdate");
                debug("Start Epoche is $Epoch_Start");
        }
        if($opt->{'e'}){                                ### Read in the end date
                my $enddate = $opt->{'e'};      # End date format should be dd-mm-yyyy-hh:mm:ss
                my $dd = 0;
                my $mm = 0;
                my $yyyy = 0;
                my $hour = 0;
                my $min = 0;
                my $sec = 0;
                ($dd, $mm, $yyyy, $hour, $min, $sec) = ($enddate =~ /(\d{1,2})-(\d{1,2})-(\d{4})-(\d{1,2}):(\d{2}):(\d{2})/);
                $Epoch_End = timelocal($sec, $min, $hour, $dd, $mm-1, $yyyy); # calcualte epoch
                debug("End Date is $enddate");
                debug("Ende Epoche is $Epoch_End");
        }
        ### Main Loop                                   # Loop through the file to find the fragments.
        $CurrentLine = 0;                               # reset Currentline
        open INPUT, "$Filename" or  die "Can't open $Filename for reading $!\n";
        while ( <INPUT> )
        {
                $CurrentLine = $CurrentLine + 1; # Set the current line.
            my $line = "$_";
            my $Epoch_Current = 0;              # Epoche of the current line.

                                                                # get the epoche of the current line only if we need it
            if ($opt->{'s'} || $opt->{'e'}){
                #if( $line =~ /^<((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec).{21})/){
                if( $line =~ /<((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec).{21})/){
                                my $TimeString= "$1";
                                $Epoch_Current = weblogicLogstringToEpoch( $TimeString );
                        }
                }
            if($opt->{'s'}){                    # Determine the Fragment start by Given Start Date.
                if ( ($Epoch_Current > 0) and ($FragmentStart == 0) and ($Epoch_Start <= $Epoch_Current)){
                        $FragmentStart = $CurrentLine;
                }
            }
            if($opt->{'e'}){                    # Determine the Fragment end by Given End Date.
                if ( ($Epoch_Current > 0)  and ($Epoch_End >= $Epoch_Current)){
                        $FragmentEnd = $CurrentLine;
                }
            }
            if($opt->{'S'}){                    # Determine the Fragment Start by Server start.
                if($line =~ /<Starting\sWebLogic/ ){
                        $FragmentStart = $CurrentLine;
                }
            }
        }
}
######################################### ANALYZEFRAGMENT
sub analyzeFragment{                            # analyze the fragment between the given lines
    use Time::Local;
        my $ErrorCount = 0;
        my $WarningCount = 0;
        my $AlertCount = 0;
        my $ServerStartCount = 0;
        my $Epoch_FirstLine = 0;
        my $Epoch_LastLine = 0;
        my $NurseryAfterOC = 0;
        my $ParallelNurseryMaxKByteDiff = 0;
        my $ParallelNurseryMaxKByteLine = "";
        my $ParallelNurseryMaxKByteLineNumber = 0;
        my $ParallelNurseryMaxTime = 0;
        my $ParallelNurseryMaxTimeLine = "";
        my $ParallelNurseryMaxTimeLineNumber = 0;

        $CurrentLine = 0;                                       # reset Currentline

        $opt = shift;                           # reference to option hash
        verbose("Option -R is on") if $opt->{'R'};
        verbose("Option -W is on") if $opt->{'W'};
        verbose("Option -w is on") if $opt->{'w'};


        open INPUT, "$Filename" or  die "Can't open $Filename for reading $!\n";
        debug("before While");
        while ( <INPUT> )
        {
                my $epoch = 0;
                my $TimeString = 0;                             # Hold the time for last and first line
                $CurrentLine = $CurrentLine + 1;# Set the current line.
                my $line = "$_";
                #<Apr 24, 2007 5:28:30 PM CEST> <Info> <Management> <BEA-141107>
                #####<May 2, 2007 11:49:14 AM CEST>
                #if( $line =~ /^\#\#\#\#<((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec).{21})/){
                if( $line =~ /^<((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec).{21})/){
                  debug("Matched line is: $line")
                }
                if ($verbose){                                  ### Extract time for first and last entry if verbose is on
                                                                                # parse line for the timestring
                                                                                        if( $line =~ /^\#\#\#\#<((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec).{21})/){
                                                                                        #if( $line =~ /^<((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec).{21})/){
                        $TimeString= "$1";
                                                                                # get the epoch for the first entry.
                        if( $Epoch_FirstLine == 0 ){
        $Epoch_FirstLine = weblogicLogstringToEpoch( $TimeString );
        debug("First Line Time String is: $TimeString");
        debug("First Line Time Epoch  is: $Epoch_FirstLine");
      }
                                                        # get the epoch for the last entry.
                        $Epoch_LastLine = weblogicLogstringToEpoch( $TimeString );
                        }
                }
                                                                        ### analyse fragment or the whole file if no fragment is given
            if( ($CurrentLine >= $FragmentStart && $CurrentLine <= $FragmentEnd) || #read until fragment from start to end demarcation
                ($CurrentLine >= $FragmentStart && $FragmentEnd == -1)   ){         #or read till the end if there is no end demarcation



                    if ($opt->{'r'}){                   # count Errors
                        if($line =~ /<Error>/ ){$ErrorCount = $ErrorCount + 1;}
                    }
                    if ($opt->{'R'}){                   # print Errors
                        if($line =~ /<Error>/ ){print "Line $CurrentLine: $line\n"}
                    }
                    if ($opt->{'w'}){                   # count Warnings
                        if($line =~ /<Warning>/ ){$WarningCount = $WarningCount + 1;}
                    }
                    if ($opt->{'W'}){                   # print Warnings
                        if($line =~ /<Warning>/ ){print "Line $CurrentLine: $line\n"}
                    }
                    if ($opt->{'a'}){                   # count Warnings
                        if($line =~ /<Alert>/ ){$AlertCount = $AlertCount + 1;}
                    }
                    if ($opt->{'A'}){                   # print Warnings
                        if($line =~ /<Alert>/ ){print "Line $CurrentLine: $line\n"}
                    }
                    if ($opt->{'t'}){                   # count Warnings
                        if($line =~ /<Starting\sWebLogic/ ){$ServerStartCount = $ServerStartCount + 1;}
                    }
                    if ($opt->{'T'}){                   # print Warnings
                        if($line =~ /<Starting\sWebLogic/ ){print "Line $CurrentLine: $line\n"}
                    }
        #############################################################################
        ############### Garbage Collection Analyis
        #############################################################################
                    if ($opt->{'g'}){                   # garbage Collection Analyis
                        if($line =~ /\[INFO\s\]\[memdbg\s\]/ ){
              #debug("$line");
               #[INFO ][memdbg ] Nursery size after OC: 268435456
               if($line =~ /Nursery\ssize\safter\sOC/ ){
                  #debug(" Nursery: $line");
                  ($NurseryAfterOC) = ($line =~ /Nursery.*\s(\d+)\Z/);
                  #debug("$NurseryAfterOC");
               }
            }
            #[INFO ][memory ] 601.825: parallel nursery GC 1275792K->1039121K (1638400K), 200.094 ms
                        if($line =~ /\[INFO\s\]\[memory\s\]/ ){
               if($line =~ /parallel\snursery\sGC/ ){
                  my $start = 0;
                  my $end = 0;
                  my $ms = 0;
                  debug(" parallel nursery GC $line");
                  ($start, $end, $ms) = ($line =~ /GC\s(\d+)K->(\d+)K.*,\s(\d+.\d+)\s/);
                  ### Calculate the Maximum Heap Differenz of this GC Cycle
                  debug("start: $start");
                  debug("end: $end");
                  debug("ms: $ms");
                  my $diff = $start - $end;
                  debug("Diff: $diff");
                  if($diff > $ParallelNurseryMaxKByteDiff){
                    $ParallelNurseryMaxKByteDiff = $diff;
                    $ParallelNurseryMaxKByteLine = $line;
                        $ParallelNurseryMaxKByteLineNumber = $CurrentLine;
                        }
                        debug("Maximum KByte: $ParallelNurseryMaxKByteDiff");
                        debug("Line $CurrentLine: $ParallelNurseryMaxKByteLine");
                        ### Calculate the Maximum duration of this GC Cycle
                        if($ms > $ParallelNurseryMaxTime){
                    $ParallelNurseryMaxTime = $ms;
                    $ParallelNurseryMaxTimeLine = $line;
                        $ParallelNurseryMaxTimeLineNumber = $CurrentLine;
                  };
                        debug("Maximum Duration: $ParallelNurseryMaxTime ms");
                        debug("Line $ParallelNurseryMaxTimeLineNumber: $ParallelNurseryMaxTimeLine");

               }
                    }
        }
                    if ($opt->{'c'}){                   # classify Errors
                        if($line =~ /<Error>/ ){
                            if($line =~ /<BEA-(\d+)>/){
                                $error_map{ $1 } = "$line";
                                if(not $errorcount_map{ $1 } ) {
                                        $errorcount_map{ $1 } = 1;
                                }else{
                                        $errorcount_map{$1} += 1;
                                }
                            }
                        }
                    }
                }
        }

        verbose("Filename: $Filename ");
        verbose("Total Lines: $CurrentLine ");
        verbose("Logfile starts at:\t" . formatEpoch($Epoch_FirstLine) );
        verbose("Logfile ends at:\t" . formatEpoch($Epoch_LastLine) );
        if ($Epoch_Start == 0){ $Epoch_Start = $Epoch_FirstLine};
        if ($FragmentStart <= 0){ $FragmentStart = 1};
        if( ($Epoch_FirstLine > $Epoch_Start) or ( $Epoch_Start >  $Epoch_LastLine)){
                verbose("STARTDATE OUT OFF RANGE !!!!!!!!!!!!!!!!!!");
        }
        verbose("Fragment starts at:\t" . formatEpoch($Epoch_Start) . " Line: $FragmentStart");
        if ($Epoch_End == 0){ $Epoch_End = $Epoch_LastLine};
        if ($FragmentEnd == -1){ $FragmentEnd = $CurrentLine};
        if( ($Epoch_FirstLine > $Epoch_End) or ( $Epoch_End >  $Epoch_LastLine)){
                verbose("ENDDATE OUT OFF RANGE !!!!!!!!!!!!!!!!!!");
        }

        verbose("Fragment ends at:\t" . formatEpoch($Epoch_End) . " Line: $FragmentEnd");


        print "Errors   = $ErrorCount \n" if $opt->{'r'};
        print "Warnings = $WarningCount \n" if $opt->{'w'};
        print "Alerts   = $AlertCount \n" if $opt->{'a'};
        print "Server Starts   = $ServerStartCount \n" if $opt->{'t'};
        if ($opt->{'g'}){
          print "GARBEGE COLLECTION ANALYSIS - PARALLEL GC:\n";
    print"Maximum KByte: $ParallelNurseryMaxKByteDiff\n";
    print"Line $CurrentLine: $ParallelNurseryMaxKByteLine";
    print"Maximum Duration: $ParallelNurseryMaxTime ms\n";
    print"Line $ParallelNurseryMaxTimeLineNumber: $ParallelNurseryMaxTimeLine\n";
        }
        if ($opt->{'c'}){
                print "Error List   (BEA Error Number - Example Error) \n";
                while ( my( $k, $v ) = each %error_map )
                {
                        print "$k - $v \n";
                }
                print "Error List   (BEA Error Number - Count) \n";
                while ( my( $k, $v ) = each %errorcount_map )
                {
                        print "$k - $v \n";
                }
        }


}

##################################### WEBLOGICLOGSTRINGTOEPOCH
                                                                        # return the epoche time of a weblogic timestring
sub weblogicLogstringToEpoch{           # Example Timestring from logfile is "Jun 21, 2004 4:53:12 PM"
        use Time::Local;

        my $TimeString = shift;
        my $epoch = 0;                                  # initinalize the return value

        my $mm = 0;                                             # initalize local vars to hold the time components
        my $dd = 0;
        my $yyyy =  0;
        my $hour = 0;
        my $min = 0;
        my $sec = 0;
        my $pm = 0;
        my $month = "none";
                                                                        # parse month and change to numeric value
        ($month) = ($TimeString =~ /(\w{3})/);
        if ($month eq "Jan"){$mm = 0};
        if ($month eq "Feb"){$mm = 1};
        if ($month eq "Mar"){$mm = 2};
        if ($month eq "Apr"){$mm = 3};
        if ($month eq "May"){$mm = 4};
        if ($month eq "Jun"){$mm = 5};
        if ($month eq "Jul"){$mm = 6};
        if ($month eq "Aug"){$mm = 7};
        if ($month eq "Sep"){$mm = 8};
        if ($month eq "Oct"){$mm = 9};
        if ($month eq "Nov"){$mm = 10};
        if ($month eq "Dec"){$mm = 11};
                                                                                        # get the rest of the date/time string
        ($dd, $yyyy, $hour, $min, $sec, $pm) = ($TimeString =~ /(\d{1,2}),\s(\d{4})\s(\d{1,2}):(\d{2}):(\d{2})\s(\w{2})/);
        if($hour == 12){$hour = 0};                     # handle wls feature (see help file), convert 12:xx:xx  to 00:xx:xx
        if($pm eq "PM"){$hour = $hour + 12};    # handle am / pm converto 24-hour-format
        if($hour ==  24){$hour = 0};                    # the Time Module expects 24 as 0 o'clock
        $epoch = timelocal($sec, $min, $hour, $dd, $mm, $yyyy); # calcualte epoch
        return $epoch;
}

##################################### takes an epoch and converts it into a String using the format: dd-mm-yyyy-hh:mm:ss
sub formatEpoch{                                #
        use Time::Local;

        my $epoch = shift;                              # get the epoche as input paramtere

        my $TimeString = "Mon Jan 01 00:00:00 1900";       # initinalize the return value
        my $mm = 0;                                             # initalize local vars to hold the time components
        my $dd = 0;
        my $yyyy =  0;
        my $hour = 0;
        my $min = 0;
        my $sec = 0;
        my $pm = 0;
        my $month = "none";

        $TimeString = localtime($epoch);# convert epoch into timestring
                                                                        # Example for timestring:  Mon Jun 21 16:53:12 2004
        ($month, $dd, $hour, $min, $sec, $yyyy) = ($TimeString =~ /\w{3}\s(\w{3})\s+(\d{1,2})\s(\d{1,2}):(\d{2}):(\d{2})\s(\d{4})/);
                                                                        # convert month
    if ($month eq "Jan"){$mm = 1};
        if ($month eq "Feb"){$mm = 2};
        if ($month eq "Mar"){$mm = 3};
        if ($month eq "Apr"){$mm = 4};
        if ($month eq "May"){$mm = 5};
        if ($month eq "Jun"){$mm = 6};
        if ($month eq "Jul"){$mm = 7};
        if ($month eq "Aug"){$mm = 8};
        if ($month eq "Sep"){$mm = 9};
        if ($month eq "Oct"){$mm = 10};
        if ($month eq "Nov"){$mm = 11};
        if ($month eq "Dec"){$mm = 12};
                                                                        # create formtatted timestring
        $TimeString =  "$dd-$mm-$yyyy-$hour:$min:$sec"  ;
        return $TimeString;
}


