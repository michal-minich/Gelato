module test.FolderTester;

import common, syntax.ast, program, interpret.ConsoleInterpreterContext, interpret.Interpreter;
import std.file, std.string, std.conv, std.utf, std.stdio, std.array, std.algorithm;


int testFolder(string rootFolerPath)
{
    return testAllFilesInFolder(rootFolerPath);
}


int testAllFilesInFolder(string folderPath)
{
    auto countTested = 0;
    auto countFailed = 0;

    foreach (string filePath; dirEntries(folderPath, SpanMode.depth))
    {
        if (!filePath.endsWith(".gel"))
            continue;

        auto isOk = testFile(filePath, folderPath.length);

        ++countTested;
        if (!isOk)
            ++countFailed;

        std.stdio.write(countTested, " Tested, ");

        if (countFailed)
            std.stdio.write(countFailed, " Failed");
        else
            std.stdio.write("All Ok");
    }

    return 0;
}


bool testFile (string filePath, int folerPathCountChars)
{
    auto txt = toUTF32(readText!string(filePath[0 .. $ - 3] ~ "txt"));
    auto lines = txt.splitLines();
    auto expectedReturn = lines[0];
    auto expectedLines = lines[1 .. $];

    TaskSpecs ts;
    ts.startFilePath = filePath;
    auto p = new Program(ts);
    auto sp = new StringPrinter;
    auto cp = new ConsolePrinter;

    auto c = new ConsoleInterpreterContext(sp);
    c.evaluator = new Interpreter(c);
    auto res = p.run(c);

    auto outFileName = filePath[0 .. $ - 3] ~ "out.txt";
    auto exFileName = filePath[0 .. $ - 3] ~ "exceptions.txt";

    if (exists(exFileName))
        remove(exFileName);

    bool isOk;

    string[] errText;

    auto actualLines = sp.str.splitLines();

    if (expectedLines.length == actualLines.length)
    {
        isOk = true;
        foreach (ix, el; expectedLines)
        {
            if (el != actualLines[ix])
            {
                isOk = false;
                break;
            }
        }
    }

    if (isOk)
    {
        if (exists(outFileName))
            remove(outFileName);
    }
    else
    {
        errText ~= "Invalid Output";
        std.file.write(outFileName, sp.str.to!string());
    }

    if (c.exceptions)
    {
        errText ~= "Exception";
        foreach (ex; c.exceptions)
        {
            std.file.append(exFileName, ex.to!string());
            std.file.append(exFileName, "\n\n");
        }
        isOk = false;
    }

    auto n = cast(ValueInt)res;
    if ((!n && expectedReturn != "0") || (n && n.value.to!dstring() != expectedReturn))
    {
        errText ~= "Invalid Return Value";
        isOk = false;
    }

    if (errText.length)
        std.stdio.writeln(filePath[folerPathCountChars .. $], " (", errText.join(", "), ")");

    return isOk;
}