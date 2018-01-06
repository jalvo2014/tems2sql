#!/usr/local/bin/perl -w
#------------------------------------------------------------------------------
# Licensed Materials - Property of IBM (C) Copyright IBM Corp. 2010, 2010
# All Rights Reserved US Government Users Restricted Rights - Use, duplication
# or disclosure restricted by GSA ADP Schedule Contract with IBM Corp
#------------------------------------------------------------------------------

#  perl tems2sql.pl [options] <kib_catalog> <qa1_name>
#
#  Create SQL INSERT statements using the kib.cat file and
#  a QA1 DB TEMS database file.
#
#  john alvord, IBM Corporation, 30 Dec 2010
#  jalvord@us.ibm.com
#
# tested on Windows and zLinux
#
# puzzles - in tbe TNODESAV case, there are two columns which
# map to the same position [NODE and ORIGINNODE]. It might
# be necessary to suppress one of them in the INSERT statement.
# 0        : New script qa1dump.pl
# 0.101201 : After review. aduran@us.ibm.com added help and made other minor changes.
# 0.400000 : rename to tems2sql and work with qa1 db file directly. kgldbutl failed with
#          : I/O errors in some cases
# 0.500000 : calculate recsize using header - to handle cases where the first
#            record is deleted
# 0.600000 : handle fields with embedded single quotes

$gVersion = 0.600000;

# $DB::single=2;   # remember debug breakpoint

# packages used
use Getopt::Long;                 # command line parsing

$gWin = (-e "C:/") ? 1 : 0;       # determine Windows versus Linux/Unix for detail settings

GetOptions(
           'h' => \ my $opt_h,
           'l' => \ my $opt_l,
           'e' => \ my $opt_e,
           's=s' => \my $opt_s,
           't=s' => \my $opt_table,
           'x=s' => \my @opt_excl
          );

if (!$opt_h) {$opt_h=0;}                            # help flag
if (!$opt_l) {$opt_l=0;}                            # line number
if (!$opt_e) {$opt_e=0;}                            # show deleted flag
if (!$opt_s) {$opt_s="";}                           # show key
if (!$opt_table) {$opt_table="";}                   # set tablename
if (!@opt_excl) {@opt_excl=();}                     # set excludes to null


$kibfn = $ARGV[0] if defined($ARGV[0]);
$qa1fn = $ARGV[1] if defined($ARGV[1]);

# If running on Windows initialize for Windows.
if ($gWin) {
   $ITM = 'C:/IBM/ITM';
   $ITM = $ENV{CANDLE_HOME} if ( defined($ENV{CANDLE_HOME}) );
   $ITM =~ s/\\/\//g;
   $kibfn = "$ITM/cms/rkdscatl/kib.cat"       if !defined($ARGV[0]);
   $kibfn = "$ITM/cms/rkdscatl/kib.cat"       if $ARGV[0] eq ".";
   $qa1fn = "C:/temp/nsav/QA1DNSAV.DB"        if !defined($ARGV[1]);
}

# if running on Linux/Unix initialize for Windows
else {
   $ITM = '/opt/IBM/ITM';
   $ITM = $ENV{CANDLEHOME} if ( defined($ENV{CANDLEHOME}) );
   $ITM =~ s/\\/\//g;
   $kibfn = "$ITM/cms/rkdscatl/kib.cat"    if !defined($ARGV[0]);
   $qa1fn = "/tmp/QA1DNSAV.DB"             if !defined($ARGV[1]);
}


&GiveHelp if ( $opt_h );           # print help and exit

# (1) determine the table name involved from the input parameter or from -t option
#
if ($opt_table ne "") {
   $tablefn = $opt_table;
} else {
   @words = split("\\.",$qa1fn);
   $tablefn = $words[0];
}

# (2) review the kib catalog file and see what table name
# is associated with the table filename
#
# example line from catalog
# TO4SRV   TNODESAV                                                VSAM.QA1DNSAV   KFAIBLOC                YKFAIBINSKFAIBDELKFAIBUPD

open(KIB, "< $kibfn") || die("Could not open $kibfn\n");
@kib_data = <KIB>;
close(KIB);

$l = 0;

$testfn = "VSAM." . $tablefn;
$tablename = "";
@words = ();

foreach $oneline (@kib_data)
{
   $l++;
   if (substr($oneline,0,1) ne "T") {next;}
   @words = split(" ",$oneline);
   if ($words[2] ne $testfn) {next;}
   $tablename = $words[1];
   last;
}
if ($tablename eq "") {die("kib catalog missing tablefn $testfn.\n");}

# (3) gather catalog definitions associated with the tablename

 $state = 1;       # sequence through catalog types
 $coli = -1;       # count of columns for the tablename
 @col = ();        # array of column names
 %colx = ();       # associative array column name to index
 @coldtyp = ();    # array of data types
 @colpost = ();    # array of data positions
 @collen = ();     # array of column lengths
 @colpos = ();     # array of column positions
 %dtypx = ();      # associative array datatype to index
 %postx = ();      # associative array position to index

 $l = 0;

foreach $oneline (@kib_data)
{
   $l++;
   $firstc = substr($oneline,0,1);
   @words = split(" ",$oneline);

   # State 1 - looking for A - application line
   if ($state == 1) {
      if ($firstc eq "A") { $state=2; next; }
   }

   # State 2 - looking for relevant C - column entries
   elsif ($state == 2) {
      if ($firstc ne "C") {$state=3;redo;}
      if ($words[1] ne $tablename) {next;}
      $colname = $words[2];
      $dtype = $words[3];
      $dpos = substr($words[4],8);
      $coli++;
      $col[$coli] = $colname;
      $colx{$colname} = $coli;
      $coldtyp[$coli] = $dtype;

      $dtypx{$dtype} = '' if !defined($dtypx{$dtype});
      $dtypx{$dtype} =  $dtypx{$dtype} . " " . $coli;
      $colpost[$coli] = $dpos;

      $postx{$dpos} = '' if !defined($postx{$dpos});
      $postx{$dpos} =  $postx{$dpos} . " " . $coli;
      }

   # State 3 - Processing D - datatype records
   elsif ($state == 3) {
      if ($firstc ne "D") {$state=4;redo;}
      $key = $words[1];
      next if (!defined($dtypx{$key}) || ($dtypx{$key} eq ''));
      $ki = $dtypx{$key};
      $clen = substr($words[3],4,4);
      @ix = split(" ",$ki);
      foreach $kx (@ix)
      {
         $collen[$kx] = $clen;
      }
   }

   # State 4 - skip to Position records
   elsif ($state == 4)  {
      if ($firstc eq "P") {$state=5;redo;}
   }

   # State 5 - process P position records
   elsif ($state == 5)  {
      if ($firstc ne "P") {last;}
      $key = $words[1];
      next if (!defined($postx{$key}) || ($postx{$key} eq ''));
      $ki = $postx{$key};
      $inpos = $words[3] . $words[4];
      @xpos = split(",",$inpos);
      $ilen = substr($xpos[2],3);
      $ipos = substr($xpos[4],3);
      @ix = split(" ",$ki);
      foreach $kx (@ix)
      {
         $colpos[$kx] = $ipos;
      }
   }
}

# Read the qa1fn file to extract data and
# create INSERT SQL statements

# QA1 files are endian sensive, so determine that first

my $qa_endian;      # remember endian type \ 1=little 0=big
my $recsize;        # calculated record size
my $fcount;         # count of field definitions
my $fields;

# read QA1 file in buffered binary mode

$qa1size = -s  $qa1fn;                                 # file size in bytes
                                                       # floating pointer to file position
$recpos = 0;                                           # Count of header fields
$fcount = 0;

# first bytes tells of the header size and form tells of
# big-endian versus little-endian numeric form

open(QA, "$qa1fn") || die("Could not open $qa1fn\n");  # reading in binary
binmode(QA);     # access by character

seek(QA,$recpos,0);
$num = read(QA,$buffer,2,0);                           # first 2 determines endian - big or little
die "unexpected size difference" if $num != 2;
$testend = unpack("n",$buffer);
$qa_endian = ($testend == 0) ? 0 : 1;

if ($qa_endian == 0) {                                   # bigendian
   $recpos = 2;
   seek(QA,$recpos,0);
   $num = read(QA,$buffer,2,0);
   die "unexpected size difference" if $num != 2;
   $hdrsize = unpack("n",$buffer);
}
else {
   $hdrsize = unpack("v",$buffer);          # convert little-endian short integer
}

# within the header there are a series of stings and from within that the record length
# can be calculated. Here is what it looks like
#
#     RuleName,C32.
#     Predicate,C3000.

$recpos = 4;
seek(QA,$recpos,0);
$num = read(QA,$buffer,4,0);

# extact count of field definition
$fcount = ($qa_endian == 0) ? unpack("N",$buffer) : unpack("V",$buffer);
$recpos = 8;
seek(QA,$recpos,0);                                    # position file for reading
$num = read(QA,$buffer,$hdrsize,0);                    # read 4 bytes
die "unexpected size difference" if $num != $hdrsize;  # error case
$recsize = 0;
@fstr = split(/\x00/,$buffer);                         # split $buffer by hex 00
for ($i=0;$i<$fcount;$i++) {
   @field2 = split(/,/,$fstr[$i]);                     # split field def by commas
   $size1 = substr($field2[1],1);                      # extract field size
   $recsize += $size1;                                 # add to total record size
}

$recpos = $hdrsize+8;                                 # position of first record


$l = 0;               # count of progress through data dump
$cnt = 1;             # count of output SQL statements
my $cpydata;          # column data
my $lpre;             # output prefix
my $del;              # deletion detection
my $s;
my @exwords;          # exclude words
my $showkey;          # header attribute

TOP: while ($recpos < $qa1size) {
   seek(QA,$recpos,0);                                 # position file for reading
   if ($qa_endian == 0) {                              # big_endian
      $num = read(QA,$buffer,2,0);                     # read 2 bytes
      die "unexpected size difference" if $num != 2;
      $del = unpack("n",$buffer);
      $recpos += 2;
   } else {
      $recpos += 2;
      seek(QA,$recpos,0);                              # position file for reading
      $num = read(QA,$buffer,2,0);                     # read 2 bytes
      die "unexpected size difference" if $num != 2;
      $del = unpack("v",$buffer);                      # 0000 or FFFF so no endian differences
   }
   $recpos += 2;
   seek(QA,$recpos,0);                                 # position file for reading
   $recpos += $recsize;                                # calculate position of next record
   if ($del != 0) {                                    # deleted record
      next if $opt_e == 0;
   }
   $num = read(QA,$buffer,$recsize,0);                 # read data record
   die "unexpected size difference - expected $recsize got $num l=$l $recpos" if $num != $recsize;
   # record is now in $buffer

   $l++;                           # count logical records
   $showkey = "";
   # data record found. Generate insert SQL which has this form:
   # INSERT INTO O4SRV.TNODESTS (O4ONLINE, LSTUSRPRF, NODE, THRUNODE ) VALUES ( "D", "cmw", "xxxxx", "" );

   # create initial portion of SQL.

   $insql = "INSERT INTO O4SRV." . $tablename . " (";

   # column names
   for ($i = 0; $i <= $coli; $i++) {
      $insql .= $col[$i];
      if ($i < $coli) {
         $insql .= ", ";
      }
   }
   $insql .= ") VALUES (";


   # extract column data from buffer
   for ($i = 0; $i <= $coli; $i++) {
      $dpos = $colpos[$i];                       # provisional starting point of data
      $clen = $collen[$i];                       # provisional length of data
      $firstc = substr($coldtyp[$i],0,1);        # if first character
      if ($firstc eq "V") {                      # is V...
         if ($qa_endian == 0) {                  # big_endian size
            $clen = unpack("n",substr($buffer,$dpos,2));
         } else {                                # else little endian size
            $clen = unpack("v",substr($buffer,$dpos,2));  # pick out length
         }
         $dpos += 2;                                   # and adjust starting point of data
      }
      $cpydata = substr($buffer,$dpos, $clen);   # first stab at data
      $firstc = substr($cpydata,0,1);            # if first character binary zero, set string to null
      if (ord($firstc) == 0) {
         $cpydata = "";
      }
      $cpydata =~ s/(^\s+|\s+$)//g;              # remove leading/trailing spaces
      $cpydata =~ s/(\x00+$)//g;                 # remove/trailing binary zeroes
      foreach $s (@opt_excl) {                   # exclude sql logic
         @exwords = split('=',$s);
         if ($col[$i] eq $exwords[0]) {
            if ($exwords[1] eq substr($cpydata,0,length($exwords[1]))){
               next TOP;
            }
         }
      }
      $cpydata =~ s/\'/\'\'/g;                   # convert embedded single quotes into doubled single quotes
      if ($opt_s eq $col[$i]) {
         $showkey = $cpydata;
      }


      $insql .= "\'" . $cpydata . "\'";          # place into SQL prototype
      if ($i < $coli) {
         $insql .= ", ";
      }
   }
   $insql .= ");";
   $cnt++;

   # prepare line number and delete flaf if options are set that way
   $lpre = "";
   if ($opt_l) {
      $lpre = "[" . $l;
      if ($del != 0) {$lpre .= "-deleted";}
      if ($showkey ne "") {$lpre .= " " . $showkey;}
      $lpre .=  "] ";
   }
   print $lpre . $insql . "\n";          # SQL printed to standard outout
}

print STDERR "Wrote $cnt insert SQL statements for $tablename\n";

# all done

exit 0;

#------------------------------------------------------------------------------
sub GiveHelp
{
  $0 =~ s|(.*)/([^/]*)|$2|;
  print <<"EndOFHelp";

  $0 v$gVersion

  This script creates SQL INSERT statements using the kib.cat file and
  a QA1* TEMS database file.

  Default values:
    kib_catalog: $kibfn
    qa1_dump   : $qa1fn

  Run as follows:
    $0  <kib_catalog> <qa1_file>

  Options
    -h              Produce help message
    -l              show input line number
    -e              include deleted lines
    -t              specify table name
    -s key          show key value before INSERT SQL
    -x key=value    exclude rows where column data starts with value

  Examples:
    $0  $kibfn QA1DNSAV.DB > insert_nsav.sql

EndOFHelp
exit;
}

#------------------------------------------------------------------------------

