module main;


import std.stdio, std.algorithm, std.conv, std.path;
import common, settings, formatter, cmdint;


int main (string[] args)
{
    fv = new FormatVisitor;
    sett = Settings.beforeLoad;
    sett = Settings.load (new ConsoleInterpreterContext, dirName(buildNormalizedPath(args[0])));

    auto task = InterpretTask.parse (args);

    auto ci = new ConsoleInterpreter;
    auto r = ci.process (task);
	readln();
	return r;
}