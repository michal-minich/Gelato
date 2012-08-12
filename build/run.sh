DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # full path to current script file
$DIR/build.sh
if [ $? -ne 0 ]; then
    exit $?
fi
$DIR/../rel/gelato $DIR/../test.gel