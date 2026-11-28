read l1 l5 l15 _ < /proc/loadavg
read up _ < /proc/uptime
echo "load $l1 $l5 $l15"
echo "up $up"
df -B1 --output=used,size / | tail -1 | awk '{print "disk "$1" "$2}'
awk '/SwapTotal/{t=$2}/SwapFree/{f=$2}END{print "swap "t" "f}' /proc/meminfo
awk -F'[: ]+' 'NR>2 && $2!="lo"{rx+=$3; tx+=$11}END{print "net "rx" "tx}' /proc/net/dev
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | awk '{s+=$1;n++}END{if(n)print "freq "s/n/1000" "n; else print "freq 0 0"}'
echo "cores $(nproc)"
grep -m1 'model name' /proc/cpuinfo | sed 's/.*: /model /'
top -bn2 -d0.6 -o %CPU -w 120 | awk '/^top -/{n++} n==2 && /^ *[0-9]+ /{print "proc "$1" "$12" "$9" "$10; if(++c==3) exit}'
