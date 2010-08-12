#!/bin/sh

CONCURRENCY=3 # set to the number of cores you want to pwn with the migration process
REPOSITORY=/cvs/drupal # replace with path to the root of the local repository
DESTINATION=/var/git/repositories
LOG_PATH=logs
DIFFLOG_PATH=difflog
PHP="/usr/bin/php"

# Remove empty repos. They're pointless in git, and the import barfs when we point at an empty directory.
find . -maxdepth 1 -type d -empty -exec rm -r {} \;

mkdir -p $DESTINATION/projects $DESTINATION/tmp
# migrate all the parent dirs for which each child receives a repo in the shared, top-level namespace (projects)
for TYPE in modules themes theme-engines profiles; do
    mkdir -p $LOG_PATH/$TYPE $DIFFLOG_PATH/$TYPE
    PREFIX="contributions/$TYPE"
    ls -d $REPOSITORY/$PREFIX/* | xargs -I% basename % | egrep -v "Attic" | xargs --max-proc $CONCURRENCY -I% sh -c "$PHP import-project.php ./cvs2git.options $REPOSITORY $PREFIX/% $DESTINATION/tmp/%.git | tee $LOG_PATH/$TYPE/%.log"
    # Run tests across all the projects we just imported
    ls -d $DESTINATION/tmp/* | sed 's/.git$//' | xargs -I% basename % | xargs --max-proc $CONCURRENCY -I% sh -c "$PHP test-project.php $REPOSITORY $PREFIX/% $DESTINATION/tmp/%.git | tee $DIFFLOG_PATH/$TYPE/%.log"
    # move the repos into the top-level namespace, but don't overwrite for now (safety check)
    mv -n $DESTINATION/tmp/* $DESTINATION/projects/
done

# Remove empty diff logs because they're just clutter.
find $DIFFLOG_PATH -size 0 -exec rm {} \;

