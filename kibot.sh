#!/bin/bash

# run this script to generate stuff defined in ./project/.kibot.yaml file
# ./kibot.sh

set -e
uid=$(id -u)
gid=$(id -g)


function run_kibot() {
	time docker run --rm -it \
	--volume "$(pwd):/tmp/workdir" \
	--workdir "/tmp/workdir" \
	setsoft/kicad_auto:ki6.0.10_Debian \
	/bin/bash -c "groupadd -g$gid u; useradd -u$uid -g$gid -d/tmp u; su u -c 'cd project && kibot -c .kibot.yaml $*'"
}

if [ "$1" ]; then
	echo "executing kibot with params: $*"
	run_kibot $*
	exit 0
fi



# generate documentation stuff
run_kibot --out-dir ../gen/ --board top.kicad_pcb  print_sch pcb_print pcb_img_3d_main_tall full_bom
run_kibot --out-dir ../gen/ --board mag.kicad_pcb            pcb_print pcb_img_3d_main
run_kibot --out-dir ../gen/ --board bot.kicad_pcb            pcb_print pcb_img_3d_main


# generate single board fab stuff
run_kibot --skip-pre all --board top.kicad_pcb --out-dir ../gen/top_single ibom fab_gerbers fab_drill fab_netlist fab_position
run_kibot --skip-pre all --board mag.kicad_pcb --out-dir ../gen/mag_single      fab_gerbers fab_drill fab_netlist
run_kibot --skip-pre all --board bot.kicad_pcb --out-dir ../gen/bot_single      fab_gerbers fab_drill fab_netlist


# concat pcb pdfs
run_kibot --skip-pre all --out-dir ../gen/ merge_pcb_pdf
rm ./gen/pcb_*.pdf

# remove garbage changes from pdfs
sed -i '/[/]CreationDate.*$/d' ./gen/schematics.pdf
sed -i '/[/]CreationDate.*$/d' ./gen/pcb.pdf


# make gerber generation reproducible for git
sed -i \
	-e '/^.*TF.CreationDate.*$/d' \
	-e '/^.*G04 Created by KiCad.* date .*$/d' \
	-e '/^.*DRILL file .* date .*$/d' \
	./gen/*/*.{gbr,drl}


# move files around

cp -f ./gen/bom.csv ./gen/top_single/_bom.csv

# archive 

function archive() {
	dir="$(dirname "$1")"
	rm -f $1
	touch -cd 1970-01-01T00:00:00Z $dir/*
	zip -qjorX9 -n zip $1 $dir
}
archive ./gen/top_single/_prod_top.zip
archive ./gen/mag_single/_prod_mag.zip
archive ./gen/bot_single/_prod_bot.zip



