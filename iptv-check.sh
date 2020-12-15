#!/bin/bash

# Fork de https://github.com/amaczuga/iptvcheck
# Fork de https://gitlab.com/peterpt/IPTV-CHECK.git


VERSION="IPTV-Check Tool 1.1a"
LATENCY_SEC=1

path=$(pwd)
sname=$0
wfile="$path/${WFILE:-oklist.m3u}"

#setup colors
blue='\e[0;36m'
green='\033[92m'
red='\e[1;31m'
yellow='\e[0;33m'
orange='\e[38;5;166m'
normal='\e[0m'

# Check if temp directory exists
if [[ ! -d $path/temp ]]; then
  mkdir "$path/temp" >/dev/null 2>&1
fi

# Clean any files from previous run in temp folder
rm -rf "$path/temp/*" >/dev/null 2>&1

# Warning is a simple message that will display every 40 checks on streams to explain user how to quit
warn() {
  if [[ $i -gt $wrn ]]; then
    wrn=$((wrn+40))
  else
    if [[ $i == "$wrn" ]]; then
      echo
      echo -e "$red""Press CTRL+C To Stop or Abort IPTV list check"
      echo
    fi
  fi
}

finish() {
  #restore regular text color, then exit to shell prompt
  echo -e "$normal"
  exit "$1"
}

#Ctrl+C Interrupt to stop the script
trap ctrl_c INT
function ctrl_c() {
  if [[ -f "$path/temp/pid.tmp" ]]; then
    pid=$(sed -n 1p < "$path/temp/pid.tmp")
    rpid=$(ps -p "$pid" -o pid= |awk '{print $1}')
    if [[ "$rpid" == "$pid" ]]; then
      kill "$pid" >/dev/null 2>&1
    fi	
  fi
  rm -rf "$path/temp/*" >/dev/null 2>&1
  finish 1
}

print_speed_result() {
  echo
  echo -e "$green""Your internet Speed test was $yellow$1$green Mbit/s"
  echo -e "$green""IPTV tool automatically configured itself to wait $yellow$2$green Seconds for each stream"
}

logo() {
  echo -e "$green" "$VERSION"
  echo -e "$yellow" "-------------------------------------"
  echo -e "$blue" "http://gitlab.com/peterpt"
  echo -e "$yellow" "-------------------------------------"

  # checkig for wget if it is installed
  which wget >/dev/null 2>&1
  if [ "$?" -eq "1" ]; then
    echo -e "$red" "Wget Missing"
    echo
    echo -e "$yellow" "Try : apt-get install wget"
    finish 1
  fi 

  speedtest=$(which speedtest-cli) >/dev/null 2>&1
  if [ "$?" -eq "1" ]; then
    echo -e "$red" "speedtest-cli Missing"
    echo
    echo -e "$yellow" "Try : sudo pip install speedtest-cli"
    finish 1
  fi 

  echo
  echo -e "$green""Testing your Internet Download Speed"
  echo -e "$yellow""This test can take up to 1 minute"
  ${speedtest} --no-upload |tee "$path/temp/speed" >/dev/null 2>&1

  echo
  echo -e "$green""Checking Results"
  if [[ ! -f "$path/temp/speed" ]]; then
    echo
    echo -e "$red""Unable to find speedtest results"
    finish 1
  else
    nets=$(grep "Download:" < "$path/temp/speed" |awk '{print $2}')
    dec=$(echo "$nets" |grep ".")
    if [[ -z "$dec" ]]; then
      netspeed="$nets"
    else
      netspeed=${nets/\.*/}
    fi 
    if [[ -z "$netspeed" ]]; then
      echo -e "$red""No output results were generated by the test"
      echo -e "$yellow""Make sure you are connected to the web"
      finish 1
    fi
    bts="120"
    if [[ "$netspeed" -le "10" ]]; then # 10Mbit/s
      tout="4"
    elif [[ "$netspeed" -le "30" ]]; then # 30 Mbit/s
      tout="3"
    elif [[ "$netspeed" -le "60" ]]; then # 60 Mbit/s
      tout="2"
    elif [[ "$netspeed" -ge "100" ]]; then # 100 Mbit/s
      tout="1"
    fi
    tout=$((tout+LATENCY_SEC))
    print_speed_result "$netspeed" "$tout"
  fi
}

# The difference between writefile and writefile2 is that (writefile2) is to process the output from m3u files based in xml codes 
# while function (writefile) is to process in output file the conventional m3u files without xml codes in it
function writefile2() {
  gturlline=$(grep -n "\<$chkf\>"<"$path/temp/2" |tr ":" "\n" |sed -n 1p)
  stdata=$(sed -n "$gturlline p"< "$path/temp/2" |awk '{$1=""; print $0}')
  if [[ -f "$wfile" ]]; then
    echo -en "#EXTINF:-1 ,${stdata}\n${chkf}\n\n" >>"$wfile"
  else
    echo -en "#EXTM3U\n\n#EXTINF:-1 ,${stdata}\n${chkf}\n\n" >"$wfile"
  fi
}

function writefile() {
  # checks if tool already created previously an m3u file

  #searchs for that specific url in original file and get line number
  gturlline=$(grep -n "${chkf}"<"$path/temp/1" |tr ":" "\n" |sed -n 1p)
  # This variable will get the line number before the previous url (this is to get channel name)
  defline=$((gturlline-1))
  stdata=$(sed -n "${defline}p"< "$path/temp/1")
  if [[ -f "$wfile" ]]; then
    echo -en "${stdata}\n${chkf}\n\n" >>"$wfile"
  else
    echo -en "#EXTM3U\n\n${stdata}\n${chkf}\n\n" >"$wfile"
  fi
}

# Function for m3u files with xml content
function xmlproc() {
  # Find http links only and delete all the other xml codes in the file , this works with many tests i did , but it may need more filtering for m3u files with more xml funtions in it
  grep -F "http" <"$path/temp/1" |sed 's/<link>//g' |sed 's/^.*http/http/' |sed 's/&amp.*|//' |sed -e 's/\(.ts\).*\(=\)/\1\2/' |sed 's/=/ /g' |sed "s~</link>~ ~g" >"$path/temp/2"
  srvnmb=$(wc -l "$path/temp/2" |awk '{print $1}')
  rm -rf "$path/temp/stream" >/dev/null 2>&1
  rm -rf "$path/temp/pid.tmp" >/dev/null 2>&1
  echo
  echo -e "$red""Press CTRL+C To Stop or Abort IPTV list check"
  echo
  for i in $(seq "$srvnmb"); do
    chkf=$(sed -n "${i}p" < "$path/temp/2" |awk '{print $1}')
    chkurl=$(echo "$chkf" |head -c 4)
    case "$chkurl" in
      http|rtmp|HTTP)
	wget -q "$chkf" -O "$path/temp/stream" & echo $! >"$path/temp/pid.tmp" 
	pid=$(sed -n 1p < "$path/temp/pid.tmp")
	sleep 4 
	rpid=$(ps -p "$pid" -o pid= |awk '{print $1}')
	if [[ "$rpid" == "$pid" ]]; then
          kill "$pid"
	fi
	if [[ ! -f "$path/temp/stream" ]]; then
          echo -e "$yellow" "Error reading captured file"
	else
          stsz=$(wc -c "$path/temp/stream" |awk '{print $1}')
          if [[ "$stsz" -le "100" ]]; then
            echo -e "$green" "Link:$yellow $i$green of :$yellow$srvnmb$green is$red OFF"
          else
            echo -e "$green" "Link:$yellow $i$green of :$yellow$srvnmb$green is$green ON"
            writefile2
          fi
	fi
	;;
      *)
        ;;
    esac
    rm -rf "$path/temp/stream" >/dev/null 2>&1
    rm -rf "$path/temp/pid.tmp" >/dev/null 2>&1
    warn
  done

  if [[ "$exts" == "0" ]]; then
    if [[ -f "$wfile" ]]; then
      echo
      echo -e "$green" "Job Finished"
      echo
      echo -e "$yellow" "You can find your new iptv list in :"
      echo -e "$orange" "$wfile"
      finish 1
    fi
  else
    echo
    echo -e "$green" "Job Finished"
    echo
    echo -e "$yellow" "Your iptv list was update in :"
    echo -e "$orange" "$wfile"
    finish 1
  fi
}	

# Function that will download for specific time the test stream
function teststream() {
  wrn="0"
  # Checks if tool already created a previous m3u file
  if [[ -f "$wfile" ]]; then
    exts="1"
  else
    exts="0"
  fi

  # dos2unix
  sed -i 's/\r//' "$path/temp/1"
  
  # checks if m3u file have xml content
  ckf=$(grep "<item>" <"$path/temp/1")
  if  [[ ! -z "$ckf" ]]; then
    xmlproc
  fi 

  #checks for empty urls like 0.0.0.0 and remove them
  chkempt=$(grep "0.0.0.0" <"$path/temp/1")
  if [[ ! -z "$chkempt" ]]; then
    grep -n "0.0.0.0" <"$path/temp/1" |sed 's/:.*//' >"$path/temp/lndel"
    lnempu=$(wc -l <"$path/temp/lndel")
    for ((i=1; i<="$lnempu"; i++)); do
      lnvar=$(sed -n "${i}p" "$path/temp/lndel")
      prevl=$((lnvar-1))
      sed -i -e "${prevl}d" "$path/temp/1"
      sed -i -e "${prevl}d" "$path/temp/1"
    done
  fi
  
  # 2nd check for null ips like 0.0.0.0
  chk2=$(grep "0.0.0.0" <"$path/temp/1")
  if [[ ! -z "$chk2" ]]; then
    sed -i '/0\.0\.0\.[[:digit:]]\{,3\}/d' "$path/temp/1"
    #cleaning up empty lines
    sed -i '/^\s*$/d' "$path/temp/1"
  fi
  
  #checks for the http links in m3u file
  glnk=$(grep -F "http" < "$path/temp/1" |sed '/EXTINF/d' |sed '/EXTM3U/d' |awk '!a[$0]++' |sed '/^$/d')
  
  #Write all the http links only to a new file so they can be checked ahead
  echo "$glnk" |tr " " "\n" >"$path/temp/2"
  
  # Counts how many lines exist in the file with links to be checked
  grep "^http" "$path/temp/2" >"$path/temp/3"
  rm -rf "$path/temp/2" >/dev/null 2>&1
  mv "$path/temp/3" "$path/temp/2" >/dev/null 2>&1
  
  # removes any previous temp pid files and stream captures from previous run
  rm -rf "$path/temp/stream" >/dev/null 2>&1
  rm -rf "$path/temp/pid.tmp" >/dev/null 2>&1
  echo
  echo -e "$red""Press CTRL+C To Stop or Abort IPTV list check"
  echo
  
  lnknmb=$(wc -l "$path/temp/2" |awk '{print $1}')
  # Starts the stream checks
  for i in $(seq "$lnknmb"); do
    chkf=$(sed -n "${i}p" <"$path/temp/2")
    # To avoid errors in previous filter , it checks if the link starts with http , rtmp or HTTP
    chkurl=$(echo "$chkf" |head -c 4)
    case "$chkurl" in
      http|rtmp|HTTP)
        # start the stream download with wget , creates a file with the pid from wget
        wget -q "$chkf" -O "$path/temp/stream" & echo $! >"$path/temp/pid.tmp" 
        
        # reads current wget pid
        pid=$(sed -n 1p < "$path/temp/pid.tmp")
        
        # 4 seconds is the time that wget will download the stream befores gets killed
	sleep "$tout"

        # checks if wget pid is still active
        rpid=$(ps -p "$pid" -o pid= |awk '{print $1}')
        if [[ "$rpid" == "$pid" ]]; then
          # kills wget pid
          kill "$pid"
        fi
        
        # checks if downloaded stream file it is in temp directory
        if [[ ! -f "$path/temp/stream" ]]; then
          echo -e "$yellow" "Error reading captured file"
        else
          # checks the size of the stream file
          stsz=$(wc -c "$path/temp/stream" |awk '{print $1}')
	  stype=$(file -b "$path/temp/stream")

          # In case stream file is less than value in bts (default is 100 bytes) then it is not valid
          if [[ "$stsz" -le "$bts" ]]; then
            echo -e "$green""Link:$yellow $i$green of :$yellow$lnknmb$green is$red OFF (${stype}, ${chkf})"
          else
            echo -e "$green""Link:$yellow $i$green of :$yellow$lnknmb$green is$green ON"
            #file have more than value in bts (default is 100 bytes) , then it is a valid stream , goto write file fuction
            writefile
          fi
        fi
        ;;
      *)
        ;;
    esac
    rm -rf "$path/temp/stream" >/dev/null 2>&1
    rm -rf "$path/temp/pid.tmp" >/dev/null 2>&1
    warn
  done

  if [[ "$exts" == "0" ]]; then
    if [[ -f "$wfile" ]]; then
      echo "Checking output file for errors"
      echo
      awk '!x[$0]++' <"$wfile" >"$path/outtemp"
      rm -rf "$wfile" >/dev/null 2>&1
      mv "$path/outtemp" "$wfile" >/dev/null 2>&1
      echo
      echo -e "$green" "Job Finished"
      echo
      echo -e "$yellow" "You can find your new iptv list in :"
      echo -e "$orange" "$wfile"
      finish 1
    fi
    else
    echo
    echo -e "$green" "Job Finished"
    echo
    echo -e "$yellow" "Your iptv list was update in :"
    echo -e "$orange" "$wfile"
    finish 1
  fi
}	

# Case user m3u file is remote (http) then run this function
function remotef() {
  # will download the remote m3u file to temp folder and will check its size
  wget "${file}" -O "$path/temp/1" >/dev/null 2>&1
  flsz=$(wc -c "$path/temp/1" |awk '{print $1}')
  if [[ "$flsz" -le "10" ]]; then
    echo "filesize is $flsz"
    echo -e "$yellow" "The remote link is down or the file size of it"
    echo -e "$yellow" "     is too small to be an m3u iptv list file"
    echo
    finish 0
  fi
  teststream
}

# Local m3u file is loaded here
function localf(){
  if [[ ! -f "$file" ]]; then
    echo -e "$yellow" "The file you specified does not exist"
    echo -e "$yellow" "in :$green $file "
    echo
    echo -e "$yellow" "Make sure you wrote the right path of it"
    finish 1
  fi
  cp "$file" "$path/temp/1" >/dev/null 2>&1
  flsz=$(wc -c "$path/temp/1" |awk '{print $1}')
  if [[ "$flsz" -le "10" ]]; then
    echo -e "$yellow" "The file you specified is too small to be an m3u iptv file"
    finish 0
  fi
  teststream
}

if [[ -z $1 ]] ;then
  echo -e "$green" "$VERSION"
  echo -e "$yellow" "-------------------------------------"
  echo -e "$blue" "http://gitlab.com/peterpt"
  echo -e "$yellow" "-------------------------------------"
  echo
  echo -e "$orange" "Example for remote list to check :"
  echo -e "$green" "$0 http://someurl/somelist.m3u"
  echo
  echo -e "$orange" "Example for local list to check :"
  echo -e "$green" "$0 /root/mylist.m3u"
  echo
  echo -e "$yellow" "-------------------------------------"
  echo
  finish 1
fi

# If a null file name is not found then executes the script again deflecting wget errors to dev/null
if [[ ! -f $path/null ]]; then
  echo "0" >"$path/null"
  exec "$sname" "$1" 2>/dev/null
#  finish 1
fi

# here it means that script already was loaded and restarted , so delete the null file for the next start
rm -rf "$path/null" >/dev/null 2>&1
logo
file="$1"

#check if user input is a remote or local file by searching for http word in the user input variable
echo "$file" |grep "http" >/dev/null 2>&1
if [ "$?" -eq "0" ]; then
  remotef
else
  localf
fi

finish 0
