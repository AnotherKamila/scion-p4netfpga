set term svg size 400,200

# set xlabel "Load / Gbps"
set xrange [1:11:2]
set xtics ("8 Gbps" 2, "16 Gbps" 4, "24 Gbps" 6, "32 Gbps" 8, "40 Gbps" 10)
set ylabel "Max queue size"
set yrange [0:3.9]
set ytics 0,1,4

set boxwidth 0.7
set style fill solid
set key left

plot '$datafile' using 4:2 with boxes ls 1 title "115B frames",\
     '$datafile' using 5:3 with boxes ls 2 title "1500B frames"