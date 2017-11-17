#!/bin/sh

if [ -n "$2" ]
then
git clone ssh://lolipop/~/git/$1.git $2
cd ./$2/
rm -rf .git
git init
elif [ -n "$1" ]
then
git clone ssh://lolipop/~/git/$1.git
cd ./$1/
rm -rf .git
git init
else
  ssh lolipop command "cd git;ls"
fi

echo "git call done!!"
