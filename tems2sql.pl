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
# tested on Windows Activestate 5.12.2
# $DB::single=2;   # remember debug breakpoint
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
# 0.700000 : handle z/OS repro files calculate recsize from cat table, add -qib option
# 0.750000 : add != test in exclude
# 0.800000 : handle Relrec case and ignore I type table definitions needed for TSITSTSH
# 0.850000 : handle Relrec case better and figure out tablename in more cases
# 0.850000 : handle -h and absent -l better
# 0.900000 : add -sx and -si and -v controls
# 0.930000 : add -txt and -tc options
# 0.950000 : handle tables with names not beginning with I
# 0.970000 : handle excludes of null values
# 1.000000 : Remove CPAN requirements

$gVersion = 1.000000;


# no CPAN packages used

# following table is used in EBCDIC to ASCII conversion using ccsid 1047 - valid for z/OS
# adapted from CPAN module Convert::EBCDIC;
# the values are recorded in octol notation.
$ccsid1047 =
'\000\001\002\003\234\011\206\177\227\215\216\013\014\015\016\017' .
'\020\021\022\023\235\012\010\207\030\031\222\217\034\035\036\037' .
'\200\201\202\203\204\205\027\033\210\211\212\213\214\005\006\007' .
'\220\221\026\223\224\225\226\004\230\231\232\233\024\025\236\032' .
'\040\240\342\344\340\341\343\345\347\361\242\056\074\050\053\174' .
'\046\351\352\353\350\355\356\357\354\337\041\044\052\051\073\136' .
'\055\057\302\304\300\301\303\305\307\321\246\054\045\137\076\077' .
'\370\311\312\313\310\315\316\317\314\140\072\043\100\047\075\042' .
'\330\141\142\143\144\145\146\147\150\151\253\273\360\375\376\261' .
'\260\152\153\154\155\156\157\160\161\162\252\272\346\270\306\244' .
'\265\176\163\164\165\166\167\170\171\172\241\277\320\133\336\256' .
'\254\243\245\267\251\247\266\274\275\276\335\250\257\135\264\327' .
'\173\101\102\103\104\105\106\107\110\111\255\364\366\362\363\365' .
'\175\112\113\114\115\116\117\120\121\122\271\373\374\371\372\377' .
'\134\367\123\124\125\126\127\130\131\132\262\324\326\322\323\325' .
'\060\061\062\063\064\065\066\067\070\071\263\333\334\331\332\237' ;

$gWin = (-e "C:/") ? 1 : 0;       # determine Windows versus Linux/Unix for detail settings

# Work through the command line options

my $opt_h;               # help flag
my $opt_l;               # line number prefix
my $opt_v;               # CSV output
my $opt_e;               # show deleted flag
my $opt_qib;             # include QIB Columns
my $opt_s;               # show key
my $opt_sx;              # show key exclude file
my $opt_si;              # show key include file
my $opt_table;           # set tablename
my @opt_excl = ();       # set excludes to null
my $opt_txt;             # text output
my @opt_tc = ();         # set text columns to null
my $opt_test;

while (@ARGV) {
   if ($ARGV[0] eq "-h") {
      &GiveHelp;                        # print help and exit
   }
   elsif ($ARGV[0] eq "-l") {
      shift(@ARGV);
      $opt_l = 1;
   }
   elsif ($ARGV[0] eq "-v") {
      shift(@ARGV);
      $opt_v = 1;
   }
   elsif ($ARGV[0] eq "-e") {
      shift(@ARGV);
      $opt_e = 1;
   }
   elsif ($ARGV[0] eq "-qib") {
      shift(@ARGV);
      $opt_qib = 1;
   }
   elsif ($ARGV[0] eq "-s") {
      shift(@ARGV);
      $opt_s = shift(@ARGV);
      die "option -s with no following column name\n" if !defined $opt_s;
   }
   elsif ($ARGV[0] eq "-sx") {
      shift(@ARGV);
      $opt_sx = shift(@ARGV);
      die "option -sx with no following filename of includes\n" if !defined $opt_sx;
   }
   elsif ($ARGV[0] eq "-si") {
      shift(@ARGV);
      $opt_si = shift(@ARGV);
      die "option -si with no following filename of includes\n" if !defined $opt_si;
   }
   elsif ($ARGV[0] eq "-t") {
      shift(@ARGV);
      $opt_table = shift(@ARGV);
      die "option -t with no following table name\n" if !defined $opt_table;
   }
   elsif ($ARGV[0] eq "-x") {
      shift(@ARGV);
      $opt_test = shift(@ARGV);
      die "option -x with no following exclude directive\n" if !defined $opt_test;
      push(@opt_excl,$opt_test);
   }
   elsif ($ARGV[0] eq "-txt") {
      shift(@ARGV);
      $opt_txt = 1;
   }
   elsif ($ARGV[0] eq "-tc") {
      shift(@ARGV);
      $opt_test = shift(@ARGV);
      die "option -tc with no following column name\n" if !defined $opt_test;
      push(@opt_tc,$opt_test);
   }
   else {
      last;
   }

}
$kibfn = $ARGV[0] if defined($ARGV[0]);
$qa1fn = $ARGV[1] if defined($ARGV[1]);

if (!$opt_h) {$opt_h=0;}                            # help flag
if (!$opt_l) {$opt_l=0;}                            # line number prefix
if (!$opt_v) {$opt_v=0;}                            # TSV output
if (!$opt_e) {$opt_e=0;}                            # show deleted flag
if (!$opt_qib) {$opt_qib=0;}                        # include QIB Columns
if (!$opt_s) {$opt_s="";}                           # show key
if (!$opt_sx) {$opt_sx="";}                         # show key exclude file
if (!$opt_si) {$opt_si="";}                         # show key include file
if (!$opt_table) {$opt_table="";}                   # set tablename
if (!@opt_excl) {@opt_excl=();}                     # set excludes to null
if (!$opt_txt) {$opt_txt=0;}                        # text output
if (!@opt_tc)  {@opt_tc=();}                        # set text columns to null

# If running on Windows initialize for Windows.
if ($gWin) {
   $ITM = 'C:/IBM/ITM';
   $ITM = $ENV{CANDLE_HOME} if ( defined($ENV{CANDLE_HOME}) );
   $ITM =~ s/\\/\//g;
   $kibfn = "$ITM/cms/rkdscatl/kib.cat"       if !defined($ARGV[0]);
   $kibfn = "$ITM/cms/rkdscatl/kib.cat"       if $kibfn eq ".";
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

if ($opt_sx ne "" && $opt_si ne "") {
   die("Both -sx and -si specified - only one allowed\n");

}

if ($opt_sx ne "" && $opt_s eq "") {
   die("Showkey exclude $opt_sx specified but -s is required and not specified\n");
}

if ($opt_si ne "" && $opt_s eq "") {
   die("Showkey include $opt_si specified but -s is required and not specified\n");
}

if ($opt_l + $opt_v + $opt_txt > 1) {
   die("Options -l and -v  and -txt are mutually exclusive\n");
}


my %show_exclude;

if ($opt_sx ne "") {
   open(KSX, "< $opt_sx") || die("Could not open sx $opt_sx\n");
   @ksx_data = <KSX>;
   close(KSX);

   @words = ();

   foreach $oneline (@ksx_data) {
      chop $oneline;
      $oneline =~ s/(^\s+|\s+$)//g;              # remove leading and trailing white space
      next if $oneline eq '';
      $show_exclude{$oneline} = 1;
   }

}

my %show_include;

if ($opt_si ne "") {
   open(KSI, "< $opt_si") || die("Could not open si $opt_si\n");
   @ksi_data = <KSI>;
   close(KSI);

   @words = ();

   foreach $oneline (@ksi_data) {
      chop $oneline;
      $oneline =~ s/(^\s+|\s+$)//g;              # remove leading and trailing white space
      next if $oneline eq '';                    # ignore blanks
      $show_include{$oneline} = 1;
   }

}


# (1) determine the table name involved from the input parameter or from -t option
#
$qa1fn =~ s/\\/\//g;
if ($opt_table ne "") {
   $tablefn = $opt_table;
} else {
   @words = split("\\/",$qa1fn);
   if ($#words != -1) {
      @words = split("\\.",$words[$#words]);
   }
   else {
      @words = split("\\.",$qa1fn);
   }
   $tablefn = $words[0];
}

# (2) review the kib catalog file and see what table name
# is associated with the table filename
#
# example line from catalog
# TO4SRV   TNODESAV                                                VSAM.QA1DNSAV   KFAIBLOC                YKFAIBINSKFAIBDELKFAIBUPD

open(KIB, "< $kibfn") || die("Could not open kib $kibfn\n");
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
   next if substr($tablename,0,1) eq "I";
   last;
}
if ($tablename eq "") {die("kib catalog missing tablefn $testfn.\n");}

# (3) gather catalog definitions associated with the tablename

 $state = 1;       # sequence through catalog types
 $coli = -1;       # count of columns for the tablename
 @col = ();        # array of column names
 %colx = ();       # associative array column name to index
 $cx = 0;          # index to column data
 @coldtyp = ();    # array of data types
 @colutf8 = ();    # array of UTF-8 values
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
      $intable = substr($oneline,9,10);        # input table name
      $intable =~ s/\s+$//;                    # strip trailing blanks
      next if $intable ne $tablename;          # skip if not correct table name
      $colname = substr($oneline,19,10);       # input column name
      $colname =~ s/\s+$//;                 # strip trailing blanks
      if ($opt_qib == 0) {
         next if substr($colname,0,3) eq "QIB";  # QIB columns are virtual and no data in TEMS database file
      }
      $dtype   = substr($oneline,57,10);       # input data type
      $dtype   =~ s/\s+$//;                  # strip trailing blanks
      $dpos    = substr($oneline,75,10);       # input data position
      $dpos    =~ s/\s+$//;                  # strip trailing blanks
      $coli++;
      $col[$coli] = $colname;
      $colx{$colname} = $coli;
      $coldtyp[$coli] = $dtype;
      $colutf8[$coli] = 0;
      if (substr($dtype,0,3) eq 'F8U' || substr($dtype,0,3) eq 'V8U') {$colutf8[$coli] = 1;}
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
#     $ilen = substr($xpos[2],3);
      $ipos = substr($xpos[4],3);
      @ix = split(" ",$ki);
      foreach $kx (@ix)
      {
         $colpos[$kx] = $ipos;
      }
   }
}


# now column data has been corrected, if txt style, validate the columns
if ($opt_txt == 1) {
   my $tc_errs = 0;
   my $tc_cnt = 0;
   foreach $s (@opt_tc) {                   # look at each requested column
     $tc_cnt++;
      next if defined $colx{$s};
      print STDERR "-tc option $s is an unknown column.\n";
      $tc_errs++;
   }
   if ($tc_errs > 0) {
      die "-tc errors, correct and retry\n";
   }
   if ($tc_cnt == 0) {
      die "-txt with no -tc options supplied, correct and retry\n";
   }

}

die "No columns found for table $tablefn\n" if $coli == -1;

# run through fields and record total length
# needed for z/OS Table repro
my $catsize = 0;
my $highpos = -1;
for ($i = 0; $i <= $coli; $i++) {
   next if $colpos[$i] < $highpos;
   $highpos = $colpos[$i];
   $highlen = $collen[$i];
}
$catsize = $highpos + $highlen;

# Read the qa1fn file to extract data and
# create INSERT SQL statements

# QA1 files are endian sensive, so determine that first
# for example, a number of 100 decimal or hex 64 would
# look like this
# 32 bit big-endian    00000064
# 16 bit big_endian    0064
# 32 bit little-endian 64000000
# 16 bit little-endian 6400
#
# Endian-ness is a hardware platform characteristic.
# IBM Z series are big endian - for example zLinux
# Intel cpus are little endian - most Linux cases
#
# The z/OS TEMS Table repo is big-endian, altho the
# data is fixed size records, so only the Variable
# length columns have the data.

# In this program, the type is determined from the
# first 4 bytes or two 16 byte integers.
# If both are non-zero, that is the z/OS table repro case.
# If the first 16 bit integer is zero, that is big endian
# If the second 16 bit integer is zero, that is little endian.

my $num;            # result of read() calls, verify expected number of bytes
my $test0;          # integer at position 0
my $test2;          # integer at position 2
my $recsize;        # calculated record size
my $fcount = 0;     # count of field definitions
my $fields;
my $qa_endian = 0;  # remember endian type \ 1=little 0=big
my $zos = 0;        # assume not z/OS repro
my $recpos = 0;                                        # pointer to file position
my $relrec = 0;     # handle relrec cases

$qa1size = -s  $qa1fn;                                 # file size in bytes

open(QA, "$qa1fn") || die("Could not open qa1 $qa1fn\n");  # reading in binary
binmode(QA);     # read QA1 file in buffered binary mode

# get first integer
seek(QA,$recpos,0);
$num = read(QA,$buffer,2,0);
die "unexpected size difference" if $num != 2;
$test0 = unpack("n",$buffer);

# get second integer
$recpos = 2;
$num = read(QA,$buffer,2,0);
die "unexpected size difference" if $num != 2;
$test2 = unpack("n",$buffer);

$zos = ($test0 != 0 && $test2 != 0);
$qa_endian = ($zos == 0 && $test2 == 0) ? 1 : 0;

# zOS repro dump is fixed length and the catalog calculation is sufficient
if ($zos == 1) {
   $recsize = $catsize;
   $recpos = 0;
}

# distribured .DB filee - use the embedded field definitions. There is a size
# difference because the .DB file records have a 4 byte length and delete header
# before each record
else {
   if ($qa_endian == 0) {                                   # bigendian
      $recpos = 2;
      seek(QA,$recpos,0);
      $num = read(QA,$buffer,2,0);
      die "unexpected size difference" if $num != 2;
      $hdrsize = unpack("n",$buffer);
   }
   else {
      $recpos = 0;
      seek(QA,$recpos,0);
      $num = read(QA,$buffer,2,0);
      die "unexpected size difference" if $num != 2;
      $hdrsize = unpack("v",$buffer);          # convert little-endian short integer
   }

   # within the header there are a series of stings and from within that the record length
   # can be calculated. Here is what it looks like
   #
   #     Relrec,H
   #     RuleName,C32.
   #     Predicate,C3000.

   $recpos = 4;
   seek(QA,$recpos,0);
   $num = read(QA,$buffer,4,0);
   # extract count of field definition
   $fcount = ($qa_endian == 0) ? unpack("N",$buffer) : unpack("V",$buffer);
   $recpos = 8;
   seek(QA,$recpos,0);                                    # position file for reading
   $num = read(QA,$buffer,$hdrsize,0);                    # read 4 bytes
   die "unexpected size difference" if $num != $hdrsize;  # error case
   $recsize = 0;
   @fstr = split(/\x00/,$buffer);                         # split $buffer by hex 00
   for ($i=0;$i<$fcount;$i++) {
      @field2 = split(/,/,$fstr[$i]);                     # split field def by commas
      if ($field2[1] eq "H"){
         $recsize += 2;
         $relrec = 2 if $field2[0] eq "Relrec";
      }
      else {
         $size1 = substr($field2[1],1);                   # extract field size
         $recsize += $size1;                              # add to total record size
      }
   }

   $recpos = $hdrsize+8;                                 # position of first record
}

$l = 0;               # track progress through data dump - helps debugging
$cnt = 0;             # count of output SQL statements
my $cpydata;          # column data
my $lpre;             # output listing prefix
my $del;              # deletion flag
my $s;
my @exwords;          # exclude words
my $showkey;          # header attribute
my $eof;              # zos check of end of file
my $quotech = "'";
my %txtfrag = ();     # associative array for txt output by column

if ($opt_v == 1) {                                    # TSV output, emit header line
   $quotech = '"';
   $insql = "";
   if ($opt_s ne "") {
      $insql .= "ShowKey\t";
   }
   if ($opt_e == 1) {
      $insql .= "Delete\t";
   }
   # column names
   for ($i = 0; $i <= $coli; $i++) {
      $insql .= $col[$i];
      if ($i < $coli) {
         $insql .= "\t";
      }
   }
   print $insql . "\n";                     # header line printed to standard output
   ++$cnt;

}
elsif ($opt_txt == 1) {
my $len;
my $pos = 0;
   $insql = "*";
   foreach $s (@opt_tc) {                   # look at each requested column
      $cx = $colx{$s};                      # index to column data
      $len = $collen[$cx];
      $len -= 2 if $coldtyp[$cx] eq "V";
      $insql .= $s . "@" . $pos . "," . $len . " ";
      $pos += $len + 1;
   }
   print $insql . "\n";                     # header line printed to standard output
   ++$cnt;

}

TOP: while ($recpos < $qa1size) {
   seek(QA,$recpos,0);                                 # position file for reading
   if ($zos == 1) {
      $del = 0;                                        # no detection of deleted records in zOS
      $num = read(QA,$buffer,4,0);                     # read 2 bytes
      die "unexpected size difference" if $num != 4;
      $eof = unpack("N",$buffer);
      last if $eof == 4294967295;                      # eof key
      seek(QA,$recpos,0);                              # re-position file for reading
      $recpos += $recsize;                             # calculate position of next record
   }
   else {
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
      seek(QA,$recpos,0);                                 # re-position file for reading
      $recpos += $recsize;                                # calculate position of next record
      if ($del != 0) {                                    # deleted record
         next TOP if $opt_e == 0;
      }
   }
   $num = read(QA,$buffer,$recsize,0);                 # read data record

   die "unexpected size difference - expected $recsize got $num l=$l $recpos" if $num != $recsize;
   # record is now in $buffer

   $l++;                           # count logical records



   $showkey = "";
   $insql = "";
   if ($opt_v == 0 && $opt_txt == 0) {
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
   }



   # extract column data from buffer
COLUMN: for ($i = 0; $i <= $coli; $i++) {
      $dpos = $colpos[$i];                       # starting point of data
      $dpos += $relrec;                          # skip over relative record internal key
      $clen = $collen[$i];                       # length of data
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
      $cpydata =~ s/(\x00+$)//g;                 # remove trailing binary zeroes

      # Some z/OS columns are not in ASCII. For those ones convert to ascii

      if ($zos == 1 && $colutf8[$i] == 0 ) {
         eval '$cpydata =~ tr/\000-\377/' . $ccsid1047 . '/';
      }

      $cpydata =~ s/(^\s+|\s+$)//g;              # remove leading and trailing white space

      # if there are excludes and this data matches, then skip this one

      foreach $s (@opt_excl) {
         if (index($s,"!=") > 0) {
            @exwords = split('!=',$s);
            if ($exwords[1] eq "''"){
               next if $cpydata ne "";
            }
            if ($col[$i] eq $exwords[0]) {
               if ($exwords[1] ne substr($cpydata,0,length($exwords[1]))){
                  next TOP;
               }
           }
         }
         else {
            @exwords = split('=',$s);
            if ($exwords[1] eq "''"){
               next if $cpydata eq "";
            }
            if ($col[$i] eq $exwords[0]) {
               if ($exwords[1] eq substr($cpydata,0,length($exwords[1]))){
                  next TOP;
               }
           }
         }
      }

      # if a show column is specified, record it now

      if ($opt_s eq $col[$i]) {
         $showkey = $cpydata;
         if ($opt_sx ne "") {                               # if doing showkey excludes, ignore record if in include list
            next TOP if defined $show_exclude{$showkey};
         }
         if ($opt_si ne "") {                               # if doing showkey include, ignore record if not in include list
            next TOP if !defined $show_include{$showkey};
         }
      }

      if ($opt_v == 1) {                            # for TSV style, emit just tab
         if ($cpydata ne "") {
            if (index($cpydata,"\"") == -1)  {
               $insql .= $cpydata;                  # place into TSV prototype
            }
            else {
               $cpydata =~ s/"/""/g;                   # convert embedded double quotes into two double quotes
               $insql .= '"' . $cpydata . '"';         # place into TSV prototype
            }
         }
         if ($i < $coli) {
            $insql .= "\t";
         }
      }
      elsif ($opt_txt == 1) {                       # txt style
         foreach $s (@opt_tc) {                     # look at each requested column
            next if $s ne $col[$i];
            if ($coldtyp[$i] eq "V") {                      # is V, skip 2 bytes of length
               $txtfrag{$s} = $cpydata . " " x ($collen[$i] + 1 - length($cpydata) - 2);
            }
            else {
               $txtfrag{$s} = $cpydata . " " x ($collen[$i] + 1 - length($cpydata));
            }
            last;
         }
      }
      else {                                        # INSERT SQL style
         $cpydata =~ s/\'/\'\'/g;                   # convert embedded single quotes into two single quotes
         $insql .= "\'" . $cpydata . "\'";          # place into SQL prototype
         if ($i < $coli) {
            $insql .= ", ";
         }
      }
   }

   if ($opt_v == 1) {                            # Tab separated data style
      $lpre = "";
      if ($opt_s ne "") {
         if ($showkey ne "") {
            $lpre = $showkey . "\t";
         }
      }
      if ($opt_e == 1) {
         if ($del != 0) {
            $lpre .= "D\t";
         }
         else {
            $lpre .= "\t";
         }
      }
      ++$cnt;
   }
   elsif ($opt_txt == 1) {                       # txt style
      $lpre = "";
      $insql = "";
      foreach $s (@opt_tc) {                     # look at each requested column
         $insql .= $txtfrag{$s};
      }
   }
   else {                                   # TSV processing
      $insql .= ");";

      # prepare line number/delete/showkey depending on options
      $lpre = "";
      if ($opt_l) {
         $lpre = "[" . $l;
         if ($del != 0) {$lpre .= "-deleted";}
         if ($showkey ne "") {$lpre .= " " . $showkey;}
         $lpre .=  "] ";
      }
   }
   ++$cnt;
   print $lpre . $insql . "\n";          # SQL printed to standard outout
}

print STDERR "Wrote $cnt lines for $tablename\n";

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
    -v              Product tab delimited .txt file for Excel
    -txt            formatted text output
    -tc             columns to display on output [multiple allowed]
    -e              include deleted rows
    -qib            include QIB columns
    -s key          show key value before INSERT SQL
    -sx file        exclude rows where showkey contained in this file
    -si file        include rows where showkey contained in this file
    -t table             specify table name
    -x key=value    exclude rows where column data starts with value

    -e and -s only have effect if -l show line number is present
    -l and -v and -txt are mutually exclusive

  Examples:
    $0  $kibfn QA1DNSAV.DB > insert_nsav.sql

EndOFHelp
exit;
}
#------------------------------------------------------------------------------
