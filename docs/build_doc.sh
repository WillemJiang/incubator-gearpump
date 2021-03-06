#!/bin/bash
CURDIR=`pwd`
CURDIRNAME=`basename $CURDIR`

if [ "$CURDIRNAME" != "docs" ]; then
  echo "This script MUST be run under 'docs' directory. "
  exit 1
fi

help() {
  echo -e "Usage: \n\t$0 scala_version[2.11] build_api_doc[0|1]"
  echo -e "\tE.g. $0 2.11 1"
}

copy_dir() {
  srcDir=$1
  destDir=$2

  echo "Making directory $destDir"
  mkdir -p $destDir
  echo "copy from $srcDir to $destDir..."
  cp -r $srcDir/* $destDir
}

render_files() {
  for file in $2; do
    if [ -d "$file" ];then
      for child in "$file"/*; do
        render_files $1 "$child"
      done
    elif [ -f "$file" ]; then
      mustache $1 $file > tmp.md
      mv tmp.md $file
    fi
  done
}

if [ $# -ne 2 ]; then
  help
  exit 1
fi

export SCALA_VERSION=$1
export BUILD_API=$2


# render file templates
echo "Rendering file templates using mustache..."
TEMP_DIR="tmp"
rm -rf $TEMP_DIR
copy_dir docs $TEMP_DIR
render_files version.yml "$TEMP_DIR/introduction $TEMP_DIR/dev $TEMP_DIR/deployment $TEMP_DIR/api $TEMP_DIR/index.md"

# generate site documents
mkdocs build --clean

# check html link validity
echo "Checking generated HTMLs using htmlproofer..."

htmlproofer site \
  --disable-external \
  --file-ignore site/base.html,site/breadcrumbs.html,site/versions.html,site/toc.html,site/footer.html

# generate API doc
if [ "$BUILD_API" = 1 ]; then
  # Build Scaladoc for Java/Scala
  echo "Moving to project root and building API docs."
  echo "Running 'sbt clean assembly unidoc'; this may take a few minutes..."
  cd $CURDIR/..
  sbt clean assembly unidoc
  echo "Moving back into docs dir."
  cd $CURDIR

  echo "Removing old docs"
  rm -rf site/api

  #copy unified ScalaDoc
  copy_dir "../target/scala-$SCALA_VERSION/unidoc"  "site/api/scala"

  #copy unified java doc
  copy_dir "../target/javaunidoc" "site/api/java"
fi
