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
# tested on
# This is perl 5, version 16, subversion 3 (v5.16.3) built for MSWin32-x86-multi-thread
# (with 1 registered patch, see perl -V for more detail)
# $DB::single=2;   # remember debug breakpoint
#
$gVersion = 1.34000;


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
my $opt_d;               # debug flag
my $opt_l;               # line number prefix
my $opt_v;               # CSV output
my $opt_e;               # show deleted flag
my $opt_ee;              # show only deleted flag
my $opt_future;             # monitor for LSTDATE beyond given time
my $opt_future_date;        # When 1, a future date was found
my $opt_future_date_count = 0; #count of future dates
my $opt_ix;              # output only index records
my $opt_ref;             # output reference lines
my $opt_qib;             # include QIB Columns
my $opt_sct;             # count of show keys collected
my @opt_skey;            # show keys
my $opt_sx;              # show key exclude file
my $opt_si;              # show key include file
my $opt_table;           # set tablename
my @opt_excl = ();       # set excludes to null
my $opt_txt;             # text output
my $opt_val;             # validation output
my $opt_val_nickname = "";    # validation nickname
my @opt_tc = ();         # set text columns to null
my @opt_tlim;            # txt output column display limit, 0 means all, default 256.
my $opt_test;
my $opt_showone;
my $opt_fav;
my $opt_gal = "gal";     # Assume Global Access List level
my %hQA1names;
my @tableInfo = ();          # set to null
my @favColNames = ();         # set to null
my $DEBUG = "YES";
my $opt_o;               # when defined, set output controls
my $opt_ofn;             # output filename
my $opt_z = 0;      # identify zOS reproed VSAM files
my $opt_skip = 0;
my %opt_skipx = ();
my $opt_varyrec = 0;    # varying record size in z/OS
my $opt_tr = 0;         # translate carriage return, line feed, tab into escapes
my $opt_endian = 0;     # When 1 display endian status
my $debug_now = 0;
my $curr_lstdate;

%hQA1names = (
TNODELST => 'QA1CNODL,LSTDATE,NODE,NODELIST,NODETYPE',
TNODESAV => 'QA1DNSAV,NODE,NODETYPE,GBLTMSTMP,O4ONLINE,ONLINE,THRUNODE,ORIGINNODE',
TNODESTS => 'QA1DSNOS,NODE,NODETYPE,GBLTMSTMP,O4ONLINE,ONLINE,THRUNODE',
EVNTMAP => 'QA1DEVMP,ID,LSTUSRPRF,LSTDATE,MAP',
EVNTSERVER => 'QA1DEVSR,DFLTSRVR,HOSTNAME,SRVRNAME,SRVRTYPE',
TACTYPCY => 'QA1DACTP,PCYNAME,LSTDATE,TYPESTR,CCTKEY,ACTINFO,CMD',
TAPPLPROPS => 'QA1DAPPL,ID,PRODUCT,PRODVER,SEEDSTATE,STATUS,GBLTMSTMP',
TCALENDAR => 'QA1SCALE,NAME,AUTOSTART,TYPE,LSTDATE,LSTUSRPRF,DATA',
TGROUP => 'QA1DGRPA,GRPNAME,GRPCLASS,LSTDATE,LSTUSRPRF,INFO,TEXT',
TGROUPI => 'QA1DGRPI,GRPCLASS,OBJNAME,LSTDATE,LSTUSRPRF,INFO',
TNAME => 'QA1DNAME,OBJCLASS,ID,FULLNAME',
TOBJACCL => 'QA1DOBJA,ACTIVATION,HUB,NODEL,OBJCLASS,OBJNAME,LSTDATE,LSTUSRPRF',
TOVERRIDE => 'QA1DOVRD,SITNAME,AUTOSTART,PRIORITY,LSTDATE,LSTUSRPRF',
TOVERITEM => 'QA1DOVRI,CALID,LSTDATE,DATA',
TPCYDESC => 'QA1DPCYF,PCYNAME,HUB,AUTOSTART,LSTDATE,LSTUSRPRF,PCYOPT',
TSITDESC => 'QA1CSITF,SITNAME,HUB,AUTOSTART,REEV_DAYS,REEV_TIME,PDT,CMD,SITINFO',
TUSER => 'QA1CSPRD,UNAME,LSTDATE,LSTUSRPRF,USERNAME,INFO',
SITDB => 'QA1CRULD,RULENAME,PREDICATE',
TOBJCOBJ => 'QA11CCOBJ,OBJNAME,OBJCLASS,COBJNAME,COBJCASS',
TSITSTSC => 'QA1CSTSC,SITNAME,TYPE,NODE,DELTASTAT,ORIGINNODE',
TSITSTSH => 'QA1CSTSH,GBLTMSTMP,SITNAME,NODE,ORIGINNODE,DELTASTAT,FULLNAME,ATOMIZE',
TEIBLOGT => 'QA1CEIBL,GBLTMSTMP,LSTUSRPRF,OBJNAME,OPERATION,ORIGINNODE,TABLENAME',
SYSTABLES => 'QA1CDSCA,APPL_NAME,RECTYPE,TABL_NAME,VERS_PROBE,LOCATOR,DELETER,INSERTER,UPDATER',
CCT => 'QA1DCCT,KEY,NAME,DESC,CMD,TABLES',
);

%hTableIgnoreKeys = (
"QA1DOBJA!HUB"         => 'gal',
"QA1DOBJA!ACTIVATION"  => 'gal',
);

# following is list of modules which need a QIBCLASSID column
# That is need to ensure the replaced objects propogate from
# the hub TEMS to TEPS and other TEMS

%hQIBclassid = (
TSITDESC   => '5140',
EVNTMAP    => '2250',
EVNTSERVER => '5990',
TNODELST   => '5529',
TOBJACCL   => '5535',
TGROUP     => '2009',
TGROUPI    => '2011',
TNAME      => '2012',
TPCYDESC   => '5130',
TACTYPCY   => '5131',
TCALENDAR  => '5652',
TOVERRIDE  => '5650',
TOVERITEM  => '5651',
CCT        => '5960',
TAPPLPROPS => '5530',
);

                                        #beh initialize $kibfn, $qa1fn - to satisfy GiveHelp()
if ($gWin) {
    $kibfn = "\$CANDLE_HOME/CMS/rkdscatl/kib.cat";
    $qa1fn = "C:/temp/nsav/QA1DNSAV.DB";
}
else {
    $kibfn = "\$CANDLEHOME/cms/rkdscatl/kib.cat";
    $qa1fn = "/tmp/QA1DNSAV.DB";
}


while (@ARGV) {
   if ($ARGV[0] eq "-h") {
      &GiveHelp;                        # print help and exit
   }
   elsif ($ARGV[0] eq "-d") {
      shift(@ARGV);
      $opt_d = 1;
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
   elsif ($ARGV[0] eq "-ee") {
      shift(@ARGV);
      $opt_e = 1;
      $opt_ee = 1;
   }
   elsif ($ARGV[0] eq "-future") {
      shift(@ARGV);
      $opt_future = shift(@ARGV);
      die "option -future with no following date stamp\n" if !defined $opt_future;
   }
   elsif ($ARGV[0] eq "-ix") {
      shift(@ARGV);
      $opt_ix = 1;
   }
   elsif ($ARGV[0] eq "-endian") {
      shift(@ARGV);
      $opt_endian = 1;
   }
   elsif ($ARGV[0] eq "-ref") {
      shift(@ARGV);
      $opt_ref = 1;
   }
   elsif ($ARGV[0] eq "-qib") {
      shift(@ARGV);
      $opt_qib = 1;
   }
   elsif ($ARGV[0] eq "-s") {
      shift(@ARGV);
      $opt_test = shift(@ARGV);
      $opt_showone = $opt_test if !defined $opt_showone;
      die "option -s with no following column name\n" if !defined $opt_test;
      push(@opt_skey,$opt_test);
   }
   elsif ($ARGV[0] eq "-sx") {
      shift(@ARGV);
      $opt_sx = shift(@ARGV);
      die "option -sx with no following filename of excludes\n" if !defined $opt_sx;
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
   elsif ($ARGV[0] eq "-z") {
      shift(@ARGV);
      $opt_z = 1;
   }
   elsif ($ARGV[0] eq "-val") {
      shift(@ARGV);
      $opt_val = 1;
      if (defined $ARGV[0]) {
         $opt_val_nickname = shift(@ARGV) if substr($ARGV[0],0,1) ne "-";
      }
      $opt_val_nickname = "default" if $opt_val_nickname eq "";
   }
   elsif ($ARGV[0] eq "-f") {
      shift(@ARGV);
      $opt_fav = 1;
   }
   elsif ($ARGV[0] eq "-nogal") {
      shift(@ARGV);
      $opt_gal = "nogal";
   }
   elsif ($ARGV[0] eq "-tc") {
      shift(@ARGV);
      $opt_test = shift(@ARGV);
      die "option -tc with no following column name\n" if !defined $opt_test;
      if (index($opt_test,",") == -1){
         push(@opt_tc,$opt_test);           # add single column to txt array
      } else {
         push(@opt_tc,split(/,/,$opt_test));# add an list of columns to txt array
      }
   }
   elsif ($ARGV[0] eq "-tlim") {
      shift(@ARGV);
      $opt_tlim = shift(@ARGV);
      die "option -tlim with no following number\n" if !defined $opt_tlim;
   }
   elsif ($ARGV[0] eq "-varyrec") {
      shift(@ARGV);
      $opt_varyrec = 1;
   }
   elsif ($ARGV[0] eq "-tr") {
      shift(@ARGV);
      $opt_tr = 1;
   }
   elsif ($ARGV[0] eq "-skip") {
      shift(@ARGV);
      $opt_skip = 1;
      my $skip_from = shift(@ARGV);
      die "option -skip without two following numbers\n" if !defined $skip_from;
      my $skip_to = shift(@ARGV);
      die "option -skip without two following numbers\n" if !defined $skip_to;
      $opt_skipx{$skip_from} = $skip_to;
   }
   elsif ($ARGV[0] eq "-o") {           # -o filename, set output
      $opt_o = "";                      # -o calculate output name based on function
      shift(@ARGV);                     # otherwise send to STDOUT
      if (defined $ARGV[0]) {
         if (substr($ARGV[0],0,1) ne "-") {
            $opt_o = $ARGV[0];
            shift(@ARGV);
         }
      }
   }
   else {
      last;
   }
}


$kibfn = $ARGV[0] if defined($ARGV[0]);
$qa1fn = $ARGV[1] if defined($ARGV[1]);

die "Catalog file missing from command line\n" if !defined  $ARGV[0];
die "QA1 file missing from command line\n" if !defined  $ARGV[1];
die "Catalog file missing\n" unless -e $ARGV[0];
die "QA1 file missing\n" unless -e $ARGV[1];

if (!defined $opt_h) {$opt_h=0;}                            # help flag
if (!defined $opt_d) {undef $DEBUG;}                        # debug mode is turned off
if (!defined $opt_l) {$opt_l=0;}                            # line number prefix
if (!defined $opt_v) {$opt_v=0;}                            # TSV output
if (!defined $opt_e) {$opt_e=0;}                            # show deleted flag
if (!defined $opt_ee) {$opt_ee=0;}                          # show only deleted flag
if (!defined $opt_ix) {$opt_ix=0;}                          # output only index records
if (!defined $opt_ref) {$opt_ref=0;}                        # output reference lines
if (!defined $opt_qib) {$opt_qib=0;}                        # include QIB Columns
if (!@opt_skey) {@opt_skey=();}                             # show keys
if (!defined $opt_sx) {$opt_sx="";}                         # show key exclude file
if (!defined $opt_si) {$opt_si="";}                         # show key include file
if (!defined $opt_table) {$opt_table="";}                   # set tablename
if (!@opt_excl) {@opt_excl=();}                             # set excludes to null
if (!defined $opt_txt) {$opt_txt=0;}                        # text output
if (!defined $opt_val)  {$opt_val=0;}                       # text output
if (!defined $opt_fav) {$opt_fav=0;}                        # favorite (preferred) table columns
if (!@opt_tc)  {@opt_tc=();}                                # set text columns to null
if (!defined $opt_tlim)  {$opt_tlim=256;}                   # txt display column limit

my $got_qibclassid = 0;                             # when 1 a QIBCLASSID was found

# If running on Windows initialize for Windows.
if ($gWin) {
   $ITM = 'C:/IBM/ITM';
   $ITM = $ENV{CANDLE_HOME} if ( defined($ENV{CANDLE_HOME}) );
   $ITM =~ s/\\/\//g;
   $kibfn = "$ITM/cms/rkdscatl/kib.cat"       if !defined($ARGV[0]);
   $kibfn = "$ITM/cms/rkdscatl/kib.cat"       if $kibfn eq ".";
   $qa1fn = "$ITM/cms"                        if !defined($ARGV[1]);;
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

if ($opt_sx ne "" && $#opt_skey == -1) {
   die("Showkey exclude $opt_sx specified but -s is required and not specified\n");
}

if ($opt_si ne "" && $#opt_skey == -1) {
   die("Showkey include $opt_si specified but -s is required and not specified\n");
}

if ($opt_ix != 0  && $#opt_skey == -1) {
   die("Index only output -ix specified but -s is required and not specified\n");
}

if ($opt_ref != 0  && $#opt_skey == -1) {
   die("Reference output -ref specified but -s is required and not specified\n");
}

if ($opt_l + $opt_v + $opt_txt + $opt_ix + $opt_val + $opt_ref > 1) {
   die("Options -l and -v  and -txt and -ix and -val and -ref are mutually exclusive\n");
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
      next if $oneline eq "";                    # ignore blanks
      $show_include{$oneline} = 1;
   }
}


# (1) determine the table name involved from the input parameter or from -t option
#
$qa1fn =~ s/\\/\//g;

if ($opt_table ne "") {
    $tablefn = $opt_table;

##? Unix style option needed
#    open FILE, ">c:/tmp/" . $opt_table . ".txt";
#    select FILE; # print will use FILE instead of STDOUT
} else {

    # get internal table name from $qa1fn
    @words = split("\\/",$qa1fn);

    if ($#words != -1) {
        @words = split("\\.",$words[$#words]);
    }
    else {
        @words = split("\\.",$qa1fn);
    }
    $tablefn = $words[0];
}
if (defined $opt_o) {
   if ($opt_o ne "") {
      $opt_ofn = $opt_o;
   } else {
      if ($opt_ix) { $opt_ofn = $tablefn . "\.DB\.IX" }
      elsif ($opt_l) { $opt_ofn = $tablefn . "\.DB\.LST" }
      elsif ($opt_ref) { $opt_ofn = $tablefn . "\.DB\.REF" }
      elsif ($opt_txt) { $opt_ofn = $tablefn . "\.DB\.TXT" }
      elsif ($opt_val) { $opt_ofn = $tablefn . "\.DB\.VAL" }
      elsif ($opt_v) { $opt_ofn = $tablefn . "\.DB\.CSV" }
      else { $opt_ofn = $tablefn . "\.DB\.sql" }
   }
   $opt_ofn =~ s|\\|\/|g;  # convert backslash to forward slash
   open FILE, ">$opt_ofn" or die "Unable to open output file $opt_ofn\n";
   select FILE;              # print will use FILE instead of STDOUT
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
   if ($opt_table ne "") {
     next if $words[1] ne $opt_table;
   }
   $tablename = $words[1];
   next if substr($tablename,0,1) eq "I";
   last;
}
if ($tablename eq "") {die("kib catalog missing tablefn $testfn.\n");}

print STDERR "opt_table=$opt_table; tablefn=$tablefn; kibfn=$kibfn; qa1fn=$qa1fn\n" if $DEBUG;

if ($opt_fav) {
   @tableInfo = split(/,/, $hQA1names{$tablename});
   for $i (1..scalar(@tableInfo) -1) {
      push @favColNames, $tableInfo[$i];
   }
}

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
      $colname =~ s/\s+$//;                    # strip trailing blanks
      if (substr($colname,0,3) eq "QIB") {
        $got_qibclassid = 1 if $colname eq "QIBCLASSID";
        next if $opt_qib == 0;
      }
      $dtype   = substr($oneline,57,10);      # input data type
      $dtype   =~ s/\s+$//;                   # strip trailing blanks
      if ($tablename ne "SYSTABLES") {
        $dpos    = substr($oneline,75,10);    # input data position
      }
      else {
        $dpos    = substr($oneline,75,15);     # input data position for SYSTABLES per KDS.CAT file
      }

      $dpos    = substr($oneline,75,10);       # input data position
      $dpos    =~ s/\s+$//;                    # strip trailing blanks
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
      print STDERR "coli=$coli; col=$col[$coli]; dpos=$dpos; postx=$postx{$dpos}\n" if $DEBUG;
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
    print STDERR "key=" . $key . ";\n" if $DEBUG;
      next if (!defined($postx{$key}) || ($postx{$key} eq ''));
      $ki = $postx{$key};
    print STDERR "ki=" . $ki . ";\n" if $DEBUG;
      $inpos = $words[3] . $words[4];
      @xpos = split(",",$inpos);
#     $ilen = substr($xpos[2],3);
      $ipos = substr($xpos[4],3);
       print STDERR "ipos=" . $ipos . "; inpos=" . $inpos . ";\n" if $DEBUG;
      @ix = split(" ",$ki);
      foreach $kx (@ix)
      {
         $colpos[$kx] = $ipos;
           print STDERR "colpos[" . $kx . "]=" . $colpos[$kx] . ";\n" if $DEBUG;
      }
   }
}

# now column data has been corrected, if txt style, validate the columns
if ($opt_txt == 1) {
   my $tc_errs = 0;
   my $tc_cnt = 0;

   if (@opt_tc) { #beh
       foreach $s (@opt_tc) {                   # look at each requested column
         $tc_cnt++;
          next if defined $colx{$s};
          print STDERR "-tc option $s is an unknown column.\n" if $DEBUG;
          $tc_errs++;
       }
       if ($tc_errs > 0) {
          die "-tc errors, correct and retry\n";
       }
       if ($tc_cnt == 0) {
          die "-txt with no -tc options supplied, correct and retry\n";
       }
   }                    #beh
   else {               #beh
    @opt_tc = @col;     #beh Direct copy; this supports -txt for ALL columns in the table
   }
}

die "No columns found for table $tablefn\n" if $coli == -1;

# run through fields and record total length
# needed for z/OS Table repro
my $catsize = 0;
my $highpos = -1;

for ($i = 0; $i <= $coli; $i++) {
#   printf STDERR "$col[$i] $colpos[$i] $collen[$i]\n";   # debug
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
my $recpos = 0;                                        # pointer to file position
my $crecpos = 0;                                       # pointer to current record file position
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

if ($opt_z == 1) {
   $qa_endian = 0;
} else {
   $qa_endian = 1 if $test2 == 0;
}

print STDERR "Endian [$qa_endian]\n" if $opt_endian == 1;

# most zOS repro dump is fixed length and the catalog calculation is sufficient
# if this a Relrec type, starts with zero and then a two byte sequence number
if ($opt_z == 1) {
   if (($test0 == 0) && ($test2 == 1)) {
     $recsize = $catsize+2;
     $recpos = 2;
     $relrec = 2;
   } else {
     $recsize = $catsize;
     $recpos = 0;
   }
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
      } elsif ($field2[1] eq "L"){
         $recsize += 4;
      }
      else {
         $size1 = substr($field2[1],1);                   # extract field size
         $recsize += $size1;                              # add to total record size
      }
   }

   $recpos = $hdrsize+8;                                 # position of first record
}
# printf STDERR "record size $recsize\n";  # debug

$l = 0;               # track progress through data dump - helps debugging
$cnt = 0;             # count of output SQL statements
my $cpydata;          # column data
my $cpydata_raw;      # raw column data
my $lpre;             # output listing prefix
my $del;              # deletion flag
my $s;
my @exwords;          # exclude words
my $showkey;          # header attribute
my $eof;              # zos check of end of file
my $quotech = "'";
my %txtfrag = ();     # associative array for txt output by column
my $ctitle;
my $cvalue;

if ($opt_v == 1) {                                    # TSV output, emit header line
   $quotech = '"';
   $insql = "";
   if ($#opt_skey != -1) {
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
   $insql = "";
   $fmtStr = "";
   $underCol = "";

   print "Table: " . $tablename . "  Internal Name: " . $tablefn . "\n\n";
   $cnt += 2;

   @opt_tc = @favColNames if $opt_fav;      #beh Direct copy
   foreach $s (@opt_tc) {                   # look at each requested column
      $cx = $colx{$s};                      # index to column data
      $len = $collen[$cx];
      $len -= 2 if $coldtyp[$cx] eq "V";
      $len = length($s) if length($s) > $len; # beh:BEGIN

      if ($opt_tlim > 0) {
         if ( $len < $opt_tlim ) {
            $uLen =  $len;
         } else {
            $uLen = $opt_tlim;
            $len = $opt_tlim;
         }
      } else {
        $uLen = $len;
      }

      $fmtStr = "%-" . $len . "s ";
      $insql .= sprintf $fmtStr, $s;
      $underline = "-" x  $uLen;
      $underCol .= $underline . " ";          # beh:END
   }

   print $insql . "\n";                     # header line printed to standard output
   ++$cnt;
   print $underCol . "\n";                  # beh print underline
   ++$cnt;

}
elsif ($opt_val == 1) {
   print "Nickname:" . $opt_val_nickname . " Table:" . $tablename . "  Internal Name:" . $tablefn . "\n\n";
   $ctitle = "showkey ";
   # column names
   for ($i = 0; $i <= $coli; $i++) {
      next if $col[$i] eq "LSTDATE";
      next if $col[$i] eq "LSTUSRPRF";
      next if $col[$i] eq "LOCFLAG";
      next if $col[$i] eq "GBLTMSTMP";
      next if $col[$i] eq "LCLTMSTMP";
      $ctitle .= "|" if $ctitle ne "showkey ";
      $ctitle .= $col[$i];
   }
   $cnt += 2;
   print "$ctitle\n";
   $cnt += 1;
}

TOP: while ($recpos < $qa1size) {
#$DB::single=2;
#$DB::single=2 if $recpos >= 132328;
   seek(QA,$recpos,0);                                 # position file for reading
   $crecpos = $recpos;                                 # current record file position
   $curr_lstdate = "";
   if ($opt_z == 1) {
      $del = 0;                                        # no detection of deleted records in zOS
      seek(QA,$recpos,0);                              # position file for reading
      $num = read(QA,$buffer,4,0);                     # read 2 bytes
      die "unexpected size difference" if $num != 4;
      $eof = unpack("N",$buffer);
      last if $eof == 4294967295;                      # eof key
      seek(QA,$recpos,0);                                 # re-position file for reading
      $num = read(QA,$cpydata_raw,$recsize);              # Remember raw data
      die "unexpected size difference" if $num != $recsize;
      my $next_recsize = $recsize;

      # One zOS case had varying record lengths, with the excess padded with ASCII blanks
      # Adapt to that using some heuristics. That is needed because the raw data does not
      # contain any lengths.
      if ($opt_varyrec == 1)  {
         my $k;
         my $cp;
         my $gotlen = 0;
         if ($tablename eq "TSITDESC") {

            # case 1 - TSITDESC record was 2092 bytes long instead of 3994. Look ahead at the LOCFLAG.
            #          That will normally be blank or null... unless it points into the next records
            $cp = $recpos + 2096;                        # position at LOCFLAG
            seek(QA,$cp,0);                              # re-position file for reading
            $num = read(QA,$buffer,1,0);                 # read data record
            my $char_ord = ord(substr($buffer,0,1));
            if (($char_ord != 64) && ($char_ord != 0)) {
               $debug_now = 1;
               $k = 2092-3994;
               $gotlen = 1;
            }

            # case 2 - For the 3842, look beyond end of record into the first byte of the
            #          LSTDATE field in the next records. 241 = X'F1' = EBCDIC number 1.
            #          That detects that case.
            $cp = $recpos + 3482 + 283;
            seek(QA,$cp,0);                              # re-position file for reading
            $num = read(QA,$buffer,1,0);                 # read data record
            $char_ord = ord(substr($buffer,0,1));
            if (($char_ord == 241)) {
               $debug_now = 1;
               $k = 3482-3994;
               $gotlen = 1;
            }
         }
         if ($tablename eq "TOBJACCL") {
            # case 3 - For the 120 byte TOBJACCL record, look at the INFO record.
            #          That detects that case.
            $cp = $recpos + 120;                         # INFO
            seek(QA,$cp,0);                              # re-position file for reading
            $num = read(QA,$buffer,1,0);                 # read data record
            my $char_ord = ord(substr($buffer,0,1));
            if (($char_ord != 64) && ($char_ord != 0)) {
               $debug_now = 1;
               $k = 120-476;
               $gotlen = 1;
            }
         }
         # case 4 - If not detected yet, look for trailing ascii blanks and continue
         #          until that runs out.
         if ($gotlen != 1) {
            for ($k=0; $k<4096; $k++) {
               $cp = $recpos + $k;
               seek(QA,$cp,0);                           # re-position file for reading
               $num = read(QA,$buffer,1,0);                 # read data record
               if (ord(substr($buffer,0,1)) == 32) {
                  $debug_now = 1;
                  next;
               }
               last;
#           last if ord(substr($buffer,0,1)) != 32;
            }
         }
         $next_recsize = $recsize + $k;
      }
      seek(QA,$recpos,0);                              # re-position file for reading
      $recpos += $next_recsize;                          # calculate position of next record
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
      $num = read(QA,$cpydata_raw,$recsize);              # Remember raw data
      die "unexpected size difference" if $num != $recsize;
      seek(QA,$recpos,0);                                 # re-position file for reading
      $crecpos = $recpos;                                 # set current position
      $recpos += $recsize;                                # calculate position of next record
      seek(QA,$recpos,0);                                 # re-position file for reading
      if ($del == 0) {                                    # deleted record
         next TOP if $opt_ee == 1;                        # only deleted records wanted
      }
      if ($del != 0) {                                    # deleted record
         next TOP if $opt_e == 0;
      }
   }


   if ($opt_skip == 1) {                                  # if a skip point, change $recpos to the skip_to point
      my $sk = $opt_skipx{$recpos};
      $recpos = $sk if defined $sk;
   }

   seek(QA,$crecpos,0);                                 # re-position file for reading
   $num = read(QA,$buffer,$recsize,0);                  # read data record
   die "unexpected size difference - expected $recsize got $num l=$l $recpos" if $num != $recsize;
   # record is now in $buffer

   $l++;                           # count logical records
#   print "working on line $l\n";  ##debug
   $showkey = "";
   $opt_sct = -1;
   $insql = "";

   if ($opt_v == 0 && $opt_txt == 0 && $opt_ix == 0 && $opt_val == 0 && $opt_ref == 0) {
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
      if ($got_qibclassid == 1) {
         my $hx = $hQIBclassid{$tablename};
         $insql .= ", QIBCLASSID" if defined  $hx;
      }
      $insql .= ") VALUES (";
   }

$opt_future_date = 0;                               # asume date is not in future
$cvalue = "";

   # extract column data from buffer
COLUMN: for ($i = 0; $i <= $coli; $i++) {
#if ($col[$i] eq 'PDT') {
#}
      $dpos = $colpos[$i];                       # starting point of data
      $dpos += $relrec;                          # skip over relative record internal key
      $clen = $collen[$i];                       # length of data
      if ($col[$i] eq "LSTDATE") {
         $curr_lstdate = substr($buffer,$dpos, $clen);   # save LSTDATE if found
         eval '$curr_lstdate =~ tr/\000-\377/' . $ccsid1047 . '/' if $opt_z == 1;
      }
      if ($coldtyp[$i] eq "O4I2") {              # Short Integer
         if ($qa_endian == 0) {                  # big_endian size
            $cpydata = unpack("n",substr($buffer,$dpos,2));
         } else {                                # else little endian size
            $cpydata = unpack("v",substr($buffer,$dpos,2));  # pick out length
         }
      } elsif ($coldtyp[$i] eq "O4I4") {         # Full Integer
         if ($qa_endian == 0) {                  # big_endian size
            $cpydata = unpack("n",substr($buffer,$dpos,4));
         } else {                                # else little endian size
            $cpydata = unpack("v",substr($buffer,$dpos,4));  # pick out length
         }
      } else {
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
         # at least one site had an ADVISE column that was in EBCDIC from pre IBM times
         # Identify that case and translate anyway.

         if ($opt_z == 1) {
            my $translate = 0;
            $translate = 1 if $colutf8[$i] == 0;
            if ($tablename eq "TSITDESC") {
               if ($col[$i] eq "ADVISE") {
                  $translate = 1 if ord(substr($cpydata,-1,1)) == 64;
               }
            }
            eval '$cpydata =~ tr/\000-\377/' . $ccsid1047 . '/' if $translate == 1;
         }

        $cpydata =~ s/(^\s+|\s+$)//g;              # remove leading and trailing white space
      }

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
      if ($col[$i] eq "LSTDATE"){                          # If checking LSTDATE record that fact
         if (defined $opt_future) {
            if ($cpydata gt $opt_future) {
               $opt_future_date = 1;
               $opt_future_date_count += 1;
            }
         }
      }

      # if a show column is specified, record it now

      # If there are show key columns, calculate the show key
      if ($#opt_skey != -1) {
         foreach $s (@opt_skey) {
            if ($s eq $col[$i]) {
               $showkey .= "|" if $showkey ne "";
               $showkey .= $cpydata;
               $opt_sct  += 1;
               last;
            }
         }
        if ($#opt_skey == $opt_sct) {
           if ($opt_sx ne "") {                               # if doing showkey excludes, ignore record if in include list
              next TOP if defined $show_exclude{$showkey};
           }
           if ($opt_si ne "") {                               # if doing showkey include, ignore record if not in include list
              next TOP if !defined $show_include{$showkey};
           }
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
         if ($opt_tr == 1) {
            $cpydata =~ s/\x09/\\t/g;
            $cpydata =~ s/\x0A/\\n/g;
            $cpydata =~ s/\x0D/\\r/g;
         }
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
      elsif ($opt_val == 1) {                       # validate style - line per column
         next if $col[$i] eq "LSTDATE";
         next if $col[$i] eq "LSTUSRPRF";
         next if $col[$i] eq "LOCFLAG"; ;
         next if $col[$i] eq "GBLTMSTMP";
         next if $col[$i] eq "LCLTMSTMP";
         my $tkey = $tablefn . "!" . $col[$i];
         my $tx = $hTableIgnoreKeys{$tkey};
         if (defined $tx) {
            $cpydata = "" if $tx eq $opt_gal;
         }
         $cvalue .= "|" if $i > 0;
         $cvalue .= $cpydata;
      }
      else {                                        # INSERT SQL style
         $cpydata =~ s/\'/\'\'/g;                   # convert embedded single quotes into two single quotes
         $insql .= "\'" . $cpydata . "\'";          # place into SQL prototype
         if ($i < $coli) {
            $insql .= ", ";
         } elsif ($got_qibclassid == 1) {
            my $hx = $hQIBclassid{$tablename};
            $insql .= ",\'" . $hQIBclassid{$tablename} . "\'" if defined $hx;
         }
      }
   }

   if ($opt_v == 1) {                            # Tab separated data style
      $lpre = "";
      if ($#opt_skey != -1) {
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
   }
   elsif ($opt_txt == 1) {                       # txt style
      $lpre = "";
      $insql = "";
      foreach $s (@opt_tc) {                      # look at each requested column
         $cx = $colx{$s};                         # index to column data
         $len = $collen[$cx];
         $len -= 2 if $coldtyp[$cx] eq "V";
         $len = length($s) if length($s) > $len;
         $len++;

         my $extra_space = "";
         if ($opt_tlim > 0) {
            if ( $len < $opt_tlim ) {
               $fmtCol = "%-" . $len . "s";
            } else {
               $fmtCol = "%." . $opt_tlim . "s";
            }
         } else {
            $fmtCol = "%s";
         }


         $insql .= sprintf $fmtCol, $txtfrag{$s}; # beh:END
         $insql .= $extra_space;
      }
      $insql =~ s/(\s+$)//g;                     # remove trailing white space
   } elsif ($opt_val == 1) {                     # validate style print record key
      $insql = $showkey . " " x (128 + 1 - length($showkey));
      $insql .= sprintf("%04d", length($cvalue));
      $insql .= " " . "$cvalue\n";
      print $insql;
      $cnt +=1;
      next;
   } elsif ($opt_ix == 1) {                      # index only output
      $lpre = "";
      $insql = $showkey;
   } elsif ($opt_ref == 1) {                      # reference output
      $lpre = "";
      $insql = "";
      $cx = $colx{$opt_showone};                 # index for showkey

      # Prepare current record position
      $insql .= sprintf("%06X:", $crecpos) . " ";  # label position in hex

      # Next sixteen bytes displayed in hex at thhe showkey position
      for($i=0; $i < 16; $i++) {                                              # for each input character
         $char = substr($cpydata_raw,$i+$colpos[$cx],1);                                     # select out one byte
         $insql .= sprintf( "%02X", ord($char));                              # convert to hex
      }
      # Next LSTDATE if present
      $insql .= "  ";
      $insql .= sprintf( "%16s", $curr_lstdate);


      # Next ASCII value of showkey
      my $len = $collen[$cx];
      my $pos = $colpos[$cx];
      $insql .= "  ";
      for($i=0; $i < $len; $i++) {
         $char = substr($cpydata_raw,$pos+$i,1);                                      # select out one byte
         $insql .= ($char =~ m#[!-~ ]# ) ? $char : '.';                     # add as character if printable or period if not
      }
      $insql .= "  ";
      for($i=0; $i < $len; $i++) {
         $char = substr($cpydata_raw,$pos+$i,1);                                      # select out one byte
         if (ord($char)< 64) {
            $insql .= " ";
         } else {
            eval '$char =~ tr/\000-\377/' . $ccsid1047 . '/';
            $insql .= $char;
         }
      }

      $insql =~ s/(\s+$)//g;                     # remove trailing white space
   } else {                                   # TSV processing
      $insql .= ");";

      # prepare line number/delete/showkey depending on options
      $lpre = "";
      if ($opt_l) {
         $lpre = "[" . $l;
         if ($del != 0) {$lpre .= "-deleted";}
         $lpre .= "-future" if $opt_future_date;
         if ($showkey ne "") {$lpre .= " " . $showkey;}
         $lpre .=  "] ";
      }
   }
   ++$cnt;
   print $lpre . $insql . "\n";          # SQL printed to standard outout
}

print STDERR "Wrote $cnt lines for $tablename\n";

if ($opt_future) {
   print STDERR "Found $opt_future_date_count LSTDATEs beyond $opt_future in $qa1fn\n" if $opt_future_date_count > 0;
}

# all done

exit 0;

#------------------------------------------------------------------------------
sub GiveHelp
{
  $0 =~ s|(.*)/([^/]*)|$2|;
  $0 =~ s|\\|\/|g;  # convert backslash to forward slash
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
    -d              write debug messages to STDERR
    -l              show input line number
    -v              produce tab delimited .txt file for Excel
    -txt            format 'pretty' text output; all columns output if -f or -tc are not also used
    -f              output only 'favorite' table columns; used in conjunction with -txt
    -ix             output only show key values
    -tc             columns to display on output [ e.g. -tc NODE,NODELIST,NODETYPE ]
    -e              include both normal and deleted rows
    -ee             output only deleted rows
    -qib            include QIB columns
    -future itmstamp   produce error when LSTDATE is in the future
    -s key          show key value before INSERT SQL
    -sx file        exclude rows where showkey contained in this file
    -si file        include rows where showkey contained in this file
    -t table        specify 'friendly' table name, i.e. TNODELST, TOBJACCL, ...
    -x key=value    exclude rows where column data starts with value
    -nogal          Do not ignore the TOBJACCL HUB AND ACTIVATION rows - before ITM 623 GA level

    -e and -s only have effect if -l show line number is present
    -l and -v and -txt are mutually exclusive
    -f and -tc are mutually exclusive; -f only used w/ -txt, -tc may be used w/ -txt or other options

  Examples:
    $0  $kibfn $qa1fn > insert_nsav.sql

EndOFHelp
exit;
}
#------------------------------------------------------------------------------
# History
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
# 1.050000 : Handle I2 and I4 type columns
# 1.100000 : Handle tables with multiple show keys
# 1.150000 : Index only and delete only added
# 1.160000 : truncate trailing blanks on TXT output lines
# 1.170000 : Handle tables with L type columns
# 1.200000 : Adopt and extend Bill Horne enhancements
#            Add -f favorite columns for -txt option
#            Better output format for -txt
#            Allow -tc to set multiple columns
#            Add -o option for output control
# 1.210000 : Better checking on arguments make sure cat and qa1 file exist
# 1.220000 : add QIBCLASSID column for certain table which have that column
# 1.230000 : add some QIBCLASSID table id values
# 1.240000 : -future itmstamp to create error report on LSTDATE beyond that stamp
# 1.250000 : -va option to create validate files
#            add temsval.pl to package
# 1.260000 : -nogal  to not ignore TOBJACCL and AND ACTIVATION columns
# 1.270000 : -z to identify z/OS VSAM REPROed to sequential files
#            auto identification did not work
#            -tlim 0 did not work
# 1.280000 : correct problem with non-zos case
# 1.290000 : Add -ref reference output to help identify database broken cases
#          : Add -skip to skip over database broken sections
#          : Add -varyrec to handle zome z/OS cases
# 1.300000 : Correct length calculation in none z/OS case
# 1.310000 : Correct line count in message for -v option
# 1.320000 : on -o outputs, upper case extension. Needed for non-Windows environments
# 1.330000 : add -tr to clarify text attributes with embedded tabs, carriage returns and line feeds
# 1.340000 : Add -endian option to show type of distributed QA1 file - big endian or little endian
