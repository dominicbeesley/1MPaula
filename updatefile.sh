#!/bin/bash

# refresh Git repository from checked out SVN sources
GIT_DEST=/cygdrive/d/users/dominic/Documents/GitHub/1MPaula
BASE_VHDL=/cygdrive/d/users/dominic/Documents/fpga/blitter/6502-blit-vhdl
BASE_6502=/cygdrive/d/users/dominic/Documents/programming/6502/mysources/6502-general

read -r -d '' sourcelines <<-ENDXX
$BASE_VHDL/chipset_fb:vhdl/chipset_fb:dmac_int_sound.*\\.vhd:-S
$BASE_VHDL/doc:vhdl/doc:sound.md:-S
$BASE_VHDL/fishbone/:vhdl/fishbone:.*:-R -S
$BASE_VHDL/hoglet-1m-paula/:vhdl/hoglet-1m-paula:.*:-R -S
$BASE_VHDL/vhdl_lib:vhdl/vhdl_lib:.*\.vhd:-S
$BASE_VHDL/vhdl_lib/bbc:vhdl/vhdl_lib/bbc:.*\.vhd:-S
$BASE_VHDL/vhdl_lib/T6502:vhdl/vhdl_lib/T6502:.*\.vhd:-S
$BASE_6502/includes:6502/includes:.*:-S
$BASE_6502/Blitter/demos/modplay:/6502/Blitter/demos/modplay:.*:-S -R
$BASE_6502/Blitter/demos/modplay:/6502/Blitter/demos:MakefilePaula:-S
$BASE_VHDL/hoglet-1m-paula/working/:binaries:.*\.(bit|mcs):
$BASE_6502/Blitter/demos/modplay:/6502/Blitter/demos:paula.ssd:
ENDXX



function copyfiles {
  local recurs=
  local ls="ls -1"
  local upd=
  local flags=
  while [[ $# -gt 0 && $1 =~ ^\- ]]; do
    case "$1" in
      -S) ls="svn ls"; upd="svn update"; flags="-S $flags"; shift ;;
      -R) recurs=1; flags="-R $flags"; shift;;
      *) return 1 ;;
    esac
  done;


  local srcdir="$1"
  local destdir="$2"
  local pattern="$3"
  
#  if [[ ! -z $upd ]]; then
#    $upd;
#  fi

  files=$($ls $srcdir)

  echo "¬$pattern¬"

  local line
  while IFS= read -d $'\n' -r line; do
    if [[ $line != "" && ! $line =~ /$ && $line =~ ^$pattern$ ]]; then
      echo $line
      if [[ ! -d "$GIT_DEST/$destdir" ]]; then
        mkdir -p "$GIT_DEST/$destdir"
      fi;
      cp -u "$srcdir/$line" "$GIT_DEST/$destdir"
    fi

  done < <(printf '%s\n' "$files");

  if [[ -n $recurs ]]; then
    echo "recurse..."
    local line
    while IFS= read -d $'\n' -r line; do
      if [[ $line =~ /$ ]]; then
        copyfiles $flags "$srcdir/$line" "$destdir/$line" "$pattern"
      fi

    done < <(printf '%s\n' "$files");
  fi;


  return 0;
}



svn update $BASE_VHDL

while IFS=: read -d $'\n' -r srcdir destdir pattern flags; do
  echo "### $srcdir $pattern"
  copyfiles $flags "$srcdir" "$destdir" "$pattern"
done < <(printf '%s\n' "$sourcelines")


