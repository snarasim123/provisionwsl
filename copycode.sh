#!/usr/bin/env bash

export code_folder="/home/snarasim/code/setup"
copycode{
echo "#### code folder = $code_folder"
read -p "*** Press to continue.. " -n 1 -r
cd "$code_folder"
rm -rf ./*
read -p "*** Press to continue.. " -n 1 -r
rm -rf ./.*
read -p "*** Press to continue.. " -n 1 -r
cp -r /mnt/d/code/setup "$HOME/code"
read -p "*** Press to continue.. " -n 1 -r
echo "#### ."
}

# read -p "*** Press to continue.. " -n 1 -r
copycode
exit

