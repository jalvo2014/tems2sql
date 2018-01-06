

**TEMS2SQL – Convert a TEMS Database file into INSERT SQL Statements or Text file or CSV file… and more**

By John Alvord

Version 1.37000 - IBM Corporation, 9 March 2015

Overview

In Windows/Linux/Unix, the TEMS database tables are kept on indexed sequential disk files files. These have a name in this form &quot;QA1CSITF.DB&quot; for data and &quot;QA1CSITF.IDX&quot; for the index. On different platforms, the files are similar in structure however differ in detail. The QA1 characters are always the same. The fourth character can be C or D and the file extension is always DB or IDX.

In z/OS the same data is recorded in a VSAM file and the last qualifier in the dataset name is the same QA1 filename.

The TEMS2SQL package can be used to explore the existing table data. It can also be used to recover data from a backup. On Distributed deleted situations can be recovered.  The resulting INSERT SQL statements can be used to insert the data into another TEMS environment if the usage is well understood. The Excel file option is very convenient for studying the table contents. The TXT option is used to extract column data into a fixed format file for input to other processing.

At version 1.25 a new tool TEMS validate has been added. This allows you to do a comprehensive comparison between two QA1 files.

At version 1.29, new z/OS logic added to handle cases where earlier levels of database have been carried forward.

Credits

In October 2013 Bill Horne in ITM L3 Support sent a set of interesting changes. I have adopted them after testing. The -o option takes the place of some hard coded Windows logic. Otherwise the changes are a significant usage improvement.



Prerequisites

TEMS2SQL is implemented in Perl. It has been tested on

Windows Activestate v5.20.2

No CPAN packages are used

It has also been tested in a Linux on z environment

This is perl, v5.8.7 built for s390-linux

I expect the program will work most Linux/Unix environments.

Command Syntax

TEMS2SQL  [-o] [-h] [-d] [-l] [-v] [-txt] [-ix] [-f] [-tc column(s)] [-tlim] [-e] [-ee] [-qib] [-s key] [-sx exfile] [-si infile] [-t tablename] [-x key=value] kibfn qa1fn

Where

kibfn is the fully qualified filename of the kib.cat file. That is typically found in

Windows:  &lt;installdir&gt;\cms\RKDSCATL]

Linux/Unix - &lt;installdir&gt;/tables/&lt;temsname&gt;/RKDSCATL

qa1fn is the filename of the QA1\*.DB file. This is typically found in

Windows:  &lt;installdir&gt;\cms\

 Linux/Unix - &lt;installdir&gt;\tables\&lt;temsname&gt;

It is always best to work on copies of such files.

-h   Display help file and exit

-d   Produce some debug progress messages on STDERR

-z                     File is a binary REPRO of a z/OS TEMS VSAM file

-l  Display line number and show key before INSERT SQL statement

-v  Create a tab delimited file for Excel viewing

-txt  Create txt output file with specified columns

-o  If present, set output file otherwise STDOUT

-ix  Output only the showkey or index values

-endian  Document endian-ness of DB, Big or Little

-ref  Create a txt file with hex dump, SHOWKEY column in ASCII/EBCDIC

-varyrec Handle z/OS cases with varying record lengths

-val [file] Output a validation file – each column in a different line

-tc column Specify column(s) wanted in txt style

-tlim size Maximum column display size

-f  Show favorite columns in txt file

-e  Include deleted records in output with indication in prefix

-ee    Output only deleted records
-last                  With -ee output only the most recent deleted object

-future itmstamp include -future in prefix if LSTDATE is past given timestamp

-qib                  Include virtual QIB columns which should never be needed

-s key  ShowKey - include the value of that column(s) before INSERT SQL

-sx exfile List of ShowKey lines to exclude

-si infile List of ShowKey lines to include

-t tablename Force the tablename [e.g. QA1CSITF] if not part of filename

-x key=value Exclude any record where the column data begins with this value.

-x key!=value Exclude any record where the column data does not begin with this value.

-nogal               do \*not\* ignore TOBJACCL HUB and ACTIVATION columns in -val

There can be multiple -s show key definitions and -x exclude definitions and -tc column specifications.

Only one of -sx and -si option can be used at one time. The -sx and -si options only take effect if a -s ShowKey is defined.

Only one of -l and -v and -txt and -ix and -val and -ref options can be set at one time.

The -v option produces a txt file. When that is opened by Excel, it goes through conversion process dialogs. Select the default at each stage. Some of the columns may need cell formatting to display correctly.

The -tc option can supply multiple column names separated by commas and with no blanks. Example: -tc SITNAME,PDT,CMD.

The -o option must always be first to avoid considering the kib file as the output file. If -o is present without a file specification, the output file will be the QA1 file name with the following appended depending on output type

 (nothing)  .sql

 -txt   .txt

 -l   .lst

 -v   .csv

 -ix   .ix
 -val   .val

 -ref   .ref

By default -txt will show a maximum of 256 characters per column. The -tlim can modify that where 0 means the column size.

The -f setting and -txt will show a list of favorite columns per table name. This was defined and created by Bill Horne.

Usage

The INSERT SQL lines are printed to standard output and can be captured with redirection.

Perl tems2sql.pl -l -s SITNAME  kib.cat qa1csitf.db &gt;qa1csitf.db.sql.lst

Perl tems2sql.pl -v -s SITNAME  kib.cat qa1csitf.db &gt;qa1csitf.db.sql.txt

Perl tems2sql.pl -l -z –varyrec -o -s SITNAME kib.cat qa1csitf.db



Notes:

1) The TEMS2SQL logic is reverse engineered from the current structure of the TEMS database files. That could change in the future and make this package obsolete.

2) If you are working with a TEMS database file, determine what maintenance level the TEMS is running. Get a copy of the related kib.cat to be sure. Some tables have been unchanged over time, but others tables were introduced and others have had new columns introduced. You can certainly work with older kib.cat files, but avoid using the resulting SQL without careful study and advice.  Some tables are defined in other cat files such as kdy.cat.

3) The z/OS table is a VSAM file and must be REPRO&#39;d to a sequential file on z/OS and that sequential file ftped to a workstation in binary mode. Use the -t option to specify a table name. Use the -z option to specify this type of file. Some rare table columns are mixed ASCII and EBCDIC and will not display correctly.

4) Sometimes a table cannot be updated alone. For example a situation with a long name requires an update to the TNAME table and the TSITDESC table at the same time.

5) To update the TEMS database, best practice is to use the KfwSQLClient. The program works with the existing TEPS connection to the TEMS and thus does not need any special configuration or knowledge. The input is not constrained in any special way. Here are notes on running that program.

For a Windows TEPS, login to the server running the TEPS, make c:\IBM\ITM\cnps the current directory. Put the file of SQL statements in some directory – the cnps\sqllib directory is convenient. Next run the commands as follows:

KfwSQLClient /f sqllib\sql.txt

In a Linux/Unix environment, login to the server running the TEPS process and make &lt;installdir&gt;/bin the current directory. Store the SQL file into a convenient directory such as &lt;installdir&gt;/tmp/sql.txt. Next run the command like this:

./itmcmd execute cq &quot;KfwSQLClient /f /opt/IBM/ITM/tmp/sql.txt&quot;

You can redirect the output into a file and review for errors. If you redirect the output file, use /opt/IBM/ITM/tmp because that is world writeable.

6) After the SQL is used to update the TEMS database, the TEPS and TEMS may have to be recycled before some of the objects will be seen.

7) This has been used for a recovery after an upgrade lost all user custom objects. The -l option was used at first. Later on a number of -x options were added to exclude product provided situations. In that case three tables were involved TSITDESC, TNODELST, TOBJACCL for situation description, MSL definition, and distribution definition.  After all definitions were recovered and the TEPS was recycled, the next step was a detailed review of all custom objects and verification of function. Nothing in this process can avoid the step of verification of presence and proper operation.

8) The ShowKey include and exclude lines are useful when establishing differences in old database tables from new. For example, use an list of the new table and put the names of the ShowKeys in a separate file. Then use that as a -sx ShowKey exclude. The resulting listing only includes old objects not in the new table.

9) The -txt option is good for putting the table data in a fixed position file ready for processing by some other program. The first line of the output file is tells the names of the columns and the position and length of the data in the following lines. The positions are zero based in the Perl and C language style.

10) The -varyrec option works with the -z option to extract data from z/OS sequential repro dumps gathered by the z/OS PDCOLLCT program. The records are of varying record size but there is no embedded length data. Therefore some heuristic log is applied to determine the cases. The customer data in some cases went back to 1996.



Summary

This is a draft document and the tems2sql.pl program has been well tested. However I expect that testing will uncover missing features and possibly defects. Please advise me of such cases and I will respond promptly.

If you want to make improvements to the tems2sql.pl program, please send the result to me and I will evaluate the changes for incorporation along with a line crediting you if so desired.



History:

# 0.750000 : add != test in exclude

# 0.800000 : handle Relrec case and ignore I type table definitions - needed for TSITSTSH

# 0.850000 : handle Relrec better and remove necessity of –t parameter  by analyzing input file.

# 0.900000 : add -v, -si and -sx options.

# 0.930000 : add -txt and -tc options

# 0.950000: handle all table names except I

# 0.970000: allow exclusion of null column values

# 1.000000: remove dependence on CPAN modules

# 1.050000: Handle O4I2 and O4I4 column types, especially the ID column eventdest

# 1.100000: Allow multiple show keys

# 1.150000: Index only and delete only added

# 1.160000: truncate trailing blanks on TXT output line

# 1.170000 : Handle tables with L type columns

# 1.200000 : Adopt and extend Bill Horne enhancements

#                   Add -f favorite columns for -txt option

#                   Better output format for -txt

#                   Allow -tc to set multiple columns

#                   Add -o option for output control

# 1.210000:  More parameter checking and document -o should be first.

# 1.220000 : add QIBCLASSID column for certain table which have that column

# 1.230000 : add some QIBCLASSID table id values

# 1.240000 : -future itmstamp to create error report on LSTDATE beyond that stamp

# 1.250000 : -va option to create validate files

#                    Add TEMS validate [temsval.pl] to package

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

# 1.350000 : Add -last which with -ee will only output the most recent deleted object

# 1.360000 : Add minimal support for QA1CDSCA and SYSTABLES - actually packages

#            QA1CDSCA is not described in a .cat file but the logic fakes it
