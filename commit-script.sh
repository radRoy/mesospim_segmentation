#!/bin/bash
printf "\n\n<git add command>\n"
git add -A

datum=$(date +%a" "%T" "%d.%m.%Y)  # Day, Time, Date

# conditional git commit message generation
printf "\n\n<git commit command>\n"  # letting the user know that in the stdout, here the git commit command was entered
if [ -z $1 ]
then
    git commit -m "generic commit message, $datum."
else
    git commit -m "$1; $datum"
fi

printf "\n\n<git push command>\n"
git push

printf "\n\n<git status command>\n"
git status