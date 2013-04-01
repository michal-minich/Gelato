module main;


import std.stdio, std.algorithm, std.conv, std.path;
import common, settings, syntax.Formatter, program, interpret.ConsoleInterpreterContext,
    test.tester, test.FolderTester;


int main (string[] args)
{
    fv = new Formatter;

    sett = Settings.beforeLoad;
    //sett = Settings.load (new ConsoleInterpreterContext(new ConsolePrinter),
    //                      args[0].buildNormalizedPath().dirName());

    auto taskSpecs = parseCmdArgs (args);

    if (taskSpecs.action == TaskAction.none)
        return 1;

    if (taskSpecs.startFilePath.endsWith(".geltest"))
        return doTest(taskSpecs.startFilePath);

    if (taskSpecs.action == TaskAction.testFolder)
        return testFolder(taskSpecs.startFilePath);

    auto p = new Program(taskSpecs);
    auto r = p.runInConsole();

    //readln();

    return r;
}