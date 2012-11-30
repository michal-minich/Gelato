module main;


import std.stdio, std.algorithm, std.conv, std.path;
import common, settings, syntax.Formatter, program, interpret.ConsoleInterpreterContext;


int main (string[] args)
{
    fv = new Formatter;

    sett = Settings.beforeLoad;
    sett = Settings.load (new ConsoleInterpreterContext, args[0].buildNormalizedPath().dirName());

    auto p = parseCmdArgs (args);
    if (!p)
        return 1;
    auto r = p.runInConsole();
    readln();
    return r;
}