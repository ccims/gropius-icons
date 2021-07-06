#!/usr/bin/env bash

# Copyright (C) 2020, Tim Neumann <neumantm@fius.informatik.uni-stuttgart.de>
#
# SPDX-License-Identifier: MIT

ADDON_CORNERS=("UL" "LL" "UR" "LR")

declare -A TRANSFORM
TRANSFORM[UL]='transform="matrix(0.375,0,0,0.375,0,0)"'
TRANSFORM[LL]='transform="matrix(0.375,0,0,0.375,0,10)"'
TRANSFORM[UR]='transform="matrix(0.375,0,0,0.375,10,0)"'
TRANSFORM[LR]='transform="matrix(0.375,0,0,0.375,10,10)"'

PNG_BASE_SIZE=16
PNG_SIZE_FACTORS=(1 2 4 8)

BASE="$(dirname "$(realpath "$0")")"
TMP="$BASE/tmpGenerateCompositeIcons"

function makeCompositeImages {
  # Arguments: Base Image, addon image, addon corner(UL, LL, UR, LR), location to save to
  baseMetadataLine="$(grep -n "</metadata>" $1 | cut -f1 -d:)"
  baseAfterMetadataLine=$((baseMetadataLine+1))

#  echo "bM:$baseMetadataLine"
#  echo "bM+1:$baseAfterMetadataLine"

  cat "$1" | head -n "$baseMetadataLine" > "$4"
#  read -n 1
  echo "  <g" >> "$4"
#  read -n 1
  echo "     ${TRANSFORM[$3]}" >> "$4"

  addonMetadataLine="$(grep -n "</metadata>" $2 | cut -f1 -d:)"
  addonStartingLine=$((addonMetadataLine+2))

  addonSvgLine="$(grep -n "</svg>" $2 | cut -f1 -d:)"
  addonLength=$((addonSvgLine-addonStartingLine))

#  echo "aM:$addonMetadataLine"
#  echo "aS:$addonStartingLine"
#  echo "aSvg:$addonSvgLine"
#  echo "aL:$addonLength"
#  read -n 1

  cat "$2" | tail -n "+$addonStartingLine" | head -n "$addonLength" >> "$4"

#  read -n 1
  cat "$1" | tail -n "+$baseAfterMetadataLine" >> "$4"
}

function compositeAllCombinations {
  # Arguments: index of the addon corner in ADDON_CORNERS, imageInput
  arrInd="$1"
  input="$2"

  if [ $arrInd -ge ${#ADDON_CORNERS[@]} ] ;then return ;fi

  corner="${ADDON_CORNERS[$arrInd]}"

  inputFilename="${input##*/}"
  inputName="${inputFilename%.*}"
  while IFS='' read -r line; do
    new_file=""
    if [ "$line" != "NONE" ] ;then
      addonFilename="${line##*/}"
      addonName="${addonFilename%.*}"
      new_name="$inputName""_""$addonName"
      new_file="$TMP/svg/composite/$new_name.svg"
      makeCompositeImages "$input" "$line" "$corner" "$new_file"
    else
      new_file="$TMP/svg/composite/$inputName.svg"
      if ! [ "$new_file" == "$input" ] ;then
        # Copy base image without any addons into generated folder
        cp "$input" "$new_file"
      fi
    fi

    (compositeAllCombinations "$(($arrInd+1))" "$new_file")
  done < "$TMP/addons_$corner"
}

rm -rf "$TMP"
mkdir -p "$TMP/svg/base"
mkdir -p "$TMP/svg/addons"
mkdir -p "$TMP/svg/other"

echo "Generating plain svgs..."

for f in "$BASE/icon-parts/base/"* ;do
  filename="${f##*/}"
  inkscape -l "$TMP/svg/base/$filename" "$f"
done

for f in "$BASE/icon-parts/addons/"* ;do
  filename="${f##*/}"
  inkscape -l "$TMP/svg/addons/$filename" "$f"
done

for f in "$BASE/icon-parts/other/"* ;do
  filename="${f##*/}"
  inkscape -l "$TMP/svg/other/$filename" "$f"
done

echo "Compositing..."

echo "NONE" > "$TMP/addons_UL"
echo "NONE" > "$TMP/addons_LL"
echo "NONE" > "$TMP/addons_UR"
echo "NONE" > "$TMP/addons_LR"

for f in "$TMP/svg/addons/"* ;do
  filename="${f##*/}"
  addonCorner="${filename:0:2}"
  echo "$f" >> "$TMP/addons_$addonCorner"
done

mkdir -p "$TMP/svg/composite"

for base in "$TMP/svg/base/"* ;do
  compositeAllCombinations 0 "$base"
done

echo "Generating pngs..."

mkdir -p "$TMP/png/"

for f in "$TMP/svg/composite/"* "$TMP/svg/other/"*;do
  filename="${f##*/}"
  name="${filename%.*}"
  for size_factor in "${PNG_SIZE_FACTORS[@]}" ;do
    size=$((PNG_BASE_SIZE*size_factor))
    new_name="$name"
    if [ $size_factor -ne 1 ] ;then
      new_name="$new_name@""$size_factor""x"
    fi
    new_file="$TMP/png/$new_name.png"
    inkscape -h "$size" -e "$new_file" "$f" > "/dev/null"
  done
done



echo "Copying files to output"

mkdir -p "$BASE/generated/svg"

for f in "$TMP/svg/composite/"* ;do
  filename="${f##*/}"
  cp "$f" "$BASE/generated/svg/$filename"
done

mkdir -p "$BASE/generated/png"

for f in "$TMP/png/"* ;do
  filename="${f##*/}"
  cp "$f" "$BASE/generated/png/$filename"
done

echo "Cleaning up..."
rm -r "$TMP"
