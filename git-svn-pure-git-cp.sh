#!/bin/bash

# Copyright 2010-2011 John Albin Wilkins and contributors.
# Adapted by Olav Cleemann, 2011
# Available under the GPL v2 license. See LICENSE.txt.

script=`basename $0`;
dir=`pwd`/`dirname $0`;
usage=$(cat <<EOF_USAGE
USAGE: $script <path-to-git-svn-repo> <name-of-copy>
\n
EOF_USAGE
);

# *TODO* verify parms

FROM=$1;
TO=$2.git;
TMP=$2.tmp;

if [ ! -e $FROM ]; then
echo '';
echo "The source dir: $FROM - does not exist!";
echo '';
exit 1;
fi

# Is source a git repo?
pushd $FROM;
git show > /dev/null 2>&1;
if [ "$?" != 0 ]; then
echo '';
echo "$FROM is not a git repo!";
echo '';
popd;
exit 1;
fi
popd;

mkdir $TO;
if [ "$?" != 0 ]; then
echo '';
echo "Could not create $TO! - Do you have writing permissions here? ($dir)";
echo '';
exit 1;
fi

# Were going on naive trust from here
echo "Creating target dir." >&2;
pushd $TO &&
git init --bare &&
git symbolic-ref HEAD refs/heads/trunk &&
popd;

if [ "$?" != 0 ]; then
echo "Err, Could not init target ($TO)!";
exit 1;
fi 

echo "Creating tmp git-svn repo." >&2;
cp -R $FROM $TMP;

# Create .gitignore file.
echo "- Converting svn:ignore properties into a .gitignore file..." >&2;
if [ -e $FROM/.gitignore ]; then
  cp $FROM/.gitignore $TMP/.gitignore;
fi

pushd $TMP &&
git svn show-ignore --id trunk >> .gitignore &&
git add .gitignore &&
git commit --author="git-svn-pure-cp <nobody@example.org>" -m 'Convert svn:ignore properties to .gitignore.'

if [ "$?" != 0 ]; then
echo "Could not add/commit ignore in $TMP!";
popd;
exit 1;
fi 

# Push to final bare repository and remove temp repository.
echo "- Pushing to new bare repository..." >&2;
git remote add bare ../$TO &&
git config remote.bare.push 'refs/remotes/*:refs/heads/*' &&
git push bare &&
# git push --tags &&
# Push the .gitignore commit that resides on master.
git push bare master:trunk;

if [ "$?" != 0 ]; then
echo "Could not push to $TO from $TMP!";
popd;
exit 1;
fi 

popd;
rm -rf $TMP;

pushd $TO;
git branch -m trunk master;

if [ "$?" != 0 ]; then
echo "Could branch rename trunk to master in $TO!";
popd;
exit 1;
fi 

echo " - Massaging  refs..";

# Remove bogus branches of the form "name@REV".
git for-each-ref --format='%(refname)' refs/heads | grep '@[0-9][0-9]*' | cut -d / -f 3- |
while read ref
do
  git branch -D "$ref";
done

# Convert git-svn tag branches to proper tags.
echo "- Converting svn tag directories to proper git tags..." >&2;
git for-each-ref --format='%(refname)' refs/heads/tags | cut -d / -f 4 |
while read ref
do
  git tag -a "$ref" -m "Convert \"$ref\" to a proper git tag." "refs/heads/tags/$ref";
  git branch -D "tags/$ref";
done

echo "- Conversion completed at $(date)." >&2;
echo '';
popd;
exit 1;
