module main;


import std.stdio, std.algorithm, std.conv, std.path;
import common, settings, formatter, cmdint;


int main (string[] args)
{
    fv = new FormatVisitor;
    sett = Settings.beforeLoad;
    sett = Settings.load (new ConsoleInterpreterContext, dirName(buildNormalizedPath(args[0])));

    version (unittest)
    {
        import tester;
        auto success = test("tests.txt");

        //if (!success)
        //    readln();

        return 0;
    }
    else
    {
        auto task = InterpretTask.parse (args);

        auto ci = new ConsoleInterpreter;
        auto r = ci.process (task);
        readln();
        return r;
    }
}