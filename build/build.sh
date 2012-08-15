DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # full path to current script file
pushd $DIR/../src/ > /dev/null
dmd -m64 -debug -gs -g -of../rel/gelato @../build/buildargs.txt
dmdError=$?
if [ $dmdError -ne 0 ]; then
    popd > /dev/null
    exit $dmdError
fi
rm ../rel/gelato.o
popd > /dev/null