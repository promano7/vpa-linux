#!/bin/bash
# Sample bash file to launch a game called GAME, playing with race 3, in
# fullscreen mode, and being ~/PLANETS the directory where is located VPA.
# Give execute permissions to the script with 'chmod +x game_launch.sh'

cd ~/PLANETS || exit 1

export VPA_SCALE=fullscreen

./VPA 3 GAME
