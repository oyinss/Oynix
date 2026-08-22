#!/usr/bin/env bash

#################################################
#                  LAUNCHER                     #
#################################################

dir="$HOME/.config/rofi/launchers"
theme='launcher'

## Run
rofi \
    -show drun \
    -theme ${dir}/${theme}.rasi
