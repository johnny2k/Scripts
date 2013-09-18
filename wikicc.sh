#!/bin/bash
# Script to download, extract, process and import wikipedia
# Usage: wikicc.sh [DATE] [PASSWORD]
# Wikimedia content control script. 
### DEFAULT VARIABLES and variables necessary for script to work                                  
### By default this script will not work without a date specified. Wikipedia didn't exist in 1982. (>:^|)
NO_ARGS=0
OPTIND=1
E_OPTERROR=85

wiki="enwiki"
wiki_dir="/cygdrive/g/wikipedia"
wdate="19821019" ##YYYYMMDD

mysql_data_dir="/cygdrive/g/mysql/data"
mysql_pass="" 

wm_functions=(setup_dirs download_files extract_files xml2sql convert2txt create_db disable_index import_data rebuild_index)
function_count=${#wm_functions[@]} 

usage ()
{
  echo -e "Name:\\n\\t{$basename $0} -  Wikimedia content control script. \\n"
  echo -e "Description:\\n"
  echo -e "\tThis script will attempt to perform each process of creating a mirror of the wiki you specify."
  echo -e "\tEach step is dependent on the previous step so make sure you start with option -1."
  echo -e "\tConfirm the success of each step before moving on. You can also try to run through each step automatically with -0. Good luck! \\n"
  echo -e "Usage:\\n\\t{$basename $0} [-d date_of_wiki] [-p mysql_password] [-w wiki_type] \\n\\t\\t[-W wiki_dir] [-m mysql_data_dir] [-0..9]\\n"
}

print_help ()
{ 
  echo -e "Command Summary:\\n"
  echo "		-1 		Setup directories "
  echo "		-2		Download files "
  echo " 		-3 		Extract Files"
  echo "		-4		Convert XML to SQL "
  echo "		-5		Convert SQL to text  "
  echo " 		-6		Create database"
  echo "		-7		Disable indexing "
  echo " 		-8		Import data "
  echo "		-9		Rebuild indexes "
  echo "		-0 		Attemp to do all steps. Good luck! "
  echo "		-d		Data of wiki in the YYYYMMDD format REQUIRED "
  echo "                -p 		MySQL password REQUIRED "
  echo " 		-w 		Type of wiki: enwiki, commonswiki, etc." 
  echo "                Default: enwiki"
  echo " 		-W		Main wikipedia directory, contains this script."
  echo "                Default: /cygdrive/g/wikipedia"
  echo "		-m 		Mysql data directory."
  echo "                Default /cygdrive/g/mysql/data " 
  echo "	    -h 		Displays this help. "
  echo "		-t      Test your options before starting. "
  echo " 	    -X 		Show all the variables set. Debugging."
  exit
 }

# Set up the directories
setup_dirs ()
{
if [ -d "$wiki_dir/$wiki" ]
then  
  echo "Setting up directories in $wiki_dir/$wiki/$wdate..."
  cd $wiki_dir/$wiki
  mkdir -p $wdate/Downloads $wdate/TextImport $wdate/UnzippedDownloads
else 
  echo "$wiki_dir/$wiki doesn't exist!"
  echo "Are you sure you specified the right values for -W -w -d options?"
fi
}

# Download all the files
# We could do each of these as a background process to speed things up but I doubt the wiki devs would like that. 
download_files () 
{  
  if [ -d "$wiki_dir/$wiki/$wdate/Downloads" ]
  then
    echo "Downloading all files..."
    cd $wiki_dir/$wiki/$wdate/Downloads
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-redirect.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-protected_titles.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-page_props.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-pages-articles.xml.bz2
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-page_restrictions.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-category.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-interwiki.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-langlinks.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-externallinks.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-templatelinks.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-imagelinks.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-categorylinks.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-pagelinks.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-oldimage.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-image.sql.gz
    wget -nv http://download.wikimedia.org/$wiki/$wdate/$wiki-$wdate-site_stats.sql.gz
  else 
    echo "$wiki_dir/$wiki/$wdate/Downloads doesn't exist!"
  fi
}


###########################
##### PROCESSING FILES ####
###########################

# Extract all to UnzippedDownloads
# Each file is unzipped in a background process so before we move on to converting we need to wait for this to finish.
extract_files ()
{
  if [ -d "$wiki_dir/$wiki/$wdate/Downloads" ]
  then
    cd $wiki_dir/$wiki/$wdate/Downloads
    echo "Extracting files..."
    for i in *.gz
      do STEM=$(basename "${i}" .gz) 
        gunzip -c "${i}" > ../UnzippedDownloads/"${STEM}" &
      done
    echo "Done."
  else 
    echo "$wiki_dir/$wiki/$wdate/Downloads doesn't exist!"
  fi
}

# Convert all with convert2txt.pl 
# Each file is converted in a background process so before we move on to importing we need to wait for this to finish.
convert2txt ()
{
  if [ -d $wiki_dir/$wiki/$wdate/UnzippedDownloads ]
  then
    cd $wiki_dir/$wiki/$wdate/UnzippedDownloads
    echo "Converting .sql to .txt..."
    for i in *.sql
      do 
        perl $wiki_dir/convert2txt.pl $i ../TextImport/$i.txt &
      done
    echo "Done."
  else
    echo "$wiki_dir/$wiki/$wdate/UnzippedDownloads doesn't exist!"
  fi
  wait
}


# xml2sql: Beware of the <redirect> tag problem. Keep checking for a version of xml2sql that 
#          deals with this correctly. Until then: 'grep -v' them out. 
xml2sql ()
{
  if [ -d $wiki_dir/$wiki/$wdate/Downloads ]
  then 
    cd  $wiki_dir/$wiki/$wdate/Downloads
    echo "Converting pages-articles.xml.bz2 to sql files with xml2sql..."
    bzcat.exe -c $wiki-$wdate-pages-articles.xml.bz2 | grep -v "<redirect />" | $wiki_dir/xml2sql/xml2sql.exe -v -m -o ../TextImport/ & 
    echo "Done"
  else
    echo "$wiki_dir/$wiki/$wdate/Downloads doesn't exist!"
  fi
}



################################
######## Database work #########
################################

# Create Database
create_db ()
{
  if [ -d $wiki_dir ] && [ -f $wiki_dir/tables.sql ]
  then 
     echo "Creating and setting up database..."
     cd $wiki_dir
     mysql -u root --password=$mysql_pass -e "create database $wiki_$wdate" 
     mysql -u root --password=$mysql_pass $wiki_$wdate -e "SOURCE tables.sql"
  else
     echo "$wiki_dir doesn't exist or tables.sql is not in $wiki_dir!"
  fi
}


# Disable Indexing
disable_index ()
{ 
  if [ -d $mysql_data_dir/$wiki_$wdate ]
  then
    mysqladmin -u root --password=$mysql_pass shutdown
    myisamchk --keys-used=0 -rq $mysql_data_dir/$wiki_$wdate/*
    net start MySQL
    mysqladmin flush-tables -u root --password=$mysql_pass
    echo "Done."
  else 
  echo "$mysql_data_dir/$wiki_$wdate doesn't exist!"
  fi
}
# Begin importing all the data after background processes are finished
import_data ()
{
  if [ -d $wiki_dir/$wiki/$wdate/TextImport ]
  then 
    echo "Importing data. This will take a long time..."
    cd $wiki_dir/$wiki/$wdate/TextImport
    ls $PWD/*.sql.txt | awk '{FS = "[.-]+"}{print "LOAD DATA INFILE \x27" $0 "\x27 IGNORE INTO TABLE "$3 " FIELDS TERMINATED BY \",\" ENCLOSED BY \"\x27\" LINES TERMINATED BY \"\\n\";" }' > commands.sql
    mysql -u root --password=$mysql_pass $wiki_$wdate < commands.sql
    mysql -u root --password=$mysql_pass $wiki_$wdate < page.sql
    mysql -u root --password=$mysql_pass $wiki_$wdate < text.sql
    # To prevent 1136 error we need to drop some columns, import, and add the columns back after importing.
    mysql -u root --password=$mysql_pass $wiki_$wdate -e "ALTER TABLE revision DROP COLUMN rev_len, DROP COLUMN rev_parent_id"
    mysql -u root --password=$mysql_pass $wiki_$wdate < TextImport/revision.sql 
    mysql -u root --password=$mysql_pass $wiki_$wdate -e "ALTER TABLE revision ADD COLUMN rev_len INT(10) UNSIGNED DEFAULT NULL AFTER rev_deleted, ADD COLUMN rev_parent_id INT(10) UNSIGNED DEFAULT NULL AFTER rev_len"
    echo "Done importing all that data."
  else 
    echo "$wiki_dir/$wiki/$wdate/TextImport doesn't exist!"
  fi
}

# Rebuild Indexes. For some of the MYI files you might need to change -rq to -roq. The (safe) -o option is slower. 
rebuild_index ()
{
  if [ -d $mysql_data_dir/$wiki_$wdate ]
  then
    echo "Rebuiling indexes."
    cd $mysql_data_dir/$wiki_$wdate
    myisamchk --fast --force --update-state --key_buffer_size=1024M --sort_buffer_size=1024M --read_buffer_size=1024M --write_buffer_size=1024M -rq .MYI
    echo "Done."
  else
    echo "$mysql_data_dir/$wiki_$wdate doesn't exist!"
  fi
}

# Check to see if the specified options are valid.
test_options ()
{
  if [ -d "$wiki_dir/$wiki/" ] && [ -f "$wiki_dir/tables.sql" ] && [ -f "$wiki_dir/convert2txt.pl" ] && [ -d "$wiki_dir/xml2sql" ] 
  then 
    echo "The options are okay, sir. Let's continue."
  else 
    echo -e "Sorry, this won't work.\\nYou do not have your options set correctly or are missing some files."
    echo -e "Check your options and make sure you have the following files present in $wiki_dir \\n\\ttables.sql \\n\\tconvert2txt.pl"
    echo -e "Is the xml2sql directory in $wiki_dir? It should be."
    exit
  fi
}

show_variables ()
{
  echo "wdate = $wdate"
  echo "mysql_pass = $mysql_pass "
  echo "wiki = $wiki"
  echo "wiki_dir = $wiki_dir"
  echo "mysql_data_dir = $mysql_data_dir"

}

# This will probably fail. Oh well. 
attempt_all ()
{
  test_options
  i=0
  while [[ "$i" < "$function_count" ]] 
    do 
      ${wm_functions[$i]}
    let "i = $i + 1"
  done
}


# READ COMMAND LINE OPTIONS
if [ $# -eq "$NO_ARGS" ]
then 
 usage
 print_help
 exit $E_OPTERROR
fi

while getopts ":d:p:w:W:m:ht0123456789X" Option
do
  case $Option in 
    d    ) wdate=$OPTARG;;
    p    ) mysql_pass=$OPTARG;;
    w    ) wiki=$OPTARG;;
    W    ) wiki_dir=$OPTARG;;
    m    ) mysql_data_dir=$OPTARG;;
    h    ) 
          usage
          print_help
          ;;
	t	 ) test_options;;
    1    ) setup_dirs;;
    2	 ) download_files;;
    3    ) extract_files;;
    4    ) xml2sql;;
    5    ) convert2txt;;
    6    ) create_db;;
    7    ) disable_index;;
    8    ) import_data;;
    9    ) rebuild_index;;
    0    ) attempt_all;;
	X    ) show_variables;;
  esac
done

shift $(($OPTIND - 1))

exit $?
