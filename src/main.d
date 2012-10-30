module main;


import std.stdio, std.algorithm, std.conv, std.path;
import common, settings, formatter, program;


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
        auto p = parseCmdArgs (args);
        auto r = p.runInConsole();
        readln();
        return r;
    }
}